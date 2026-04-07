import * as Notifications from 'expo-notifications';
import { database } from './DatabaseService';
import { aiService } from './AIService';
import { Transaction, ParsedTransaction } from '../types';

// Keywords to identify financial SMS for Thangu AI
const FINANCIAL_KEYWORDS = [
  'debited',
  'credited',
  'withdrawn',
  'transferred',
  'payment',
  'purchase',
  'spent',
  'received',
  'refund',
  'charged',
  'transaction',
  'upi',
  'imps',
  'neft',
  'rtgs',
  'atm',
  'pos',
  'online',
  'bank',
];

// Bank/UPI sender patterns
const BANK_SENDER_PATTERNS = [
  /^[A-Z]{2,4}-\w+$/i,  // AD-XXXXX, HDFC-XXXXX
  /^[A-Z]{2,4}\d+$/i,   // HDFC12345
  /bank/i,
  /paytm/i,
  /googlepay/i,
  /phonepe/i,
  /amazonpay/i,
];

interface SMSNotification {
  title: string;
  body: string;
  data?: Record<string, any>;
}

export class NotificationService {
  private isListening: boolean = false;
  private notificationSubscription: Notifications.Subscription | null = null;
  private onTransactionDetected?: (transaction: Transaction, needsReview: boolean) => void;

  constructor() {
    // Configure notification handler
    Notifications.setNotificationHandler({
      handleNotification: async () => ({
        shouldShowAlert: false,
        shouldPlaySound: false,
        shouldSetBadge: false,
      }),
    });
  }

  setTransactionCallback(callback: (transaction: Transaction, needsReview: boolean) => void): void {
    this.onTransactionDetected = callback;
  }

  async requestPermissions(): Promise<boolean> {
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }

    return finalStatus === 'granted';
  }

  async startListening(): Promise<boolean> {
    if (this.isListening) return true;

    const hasPermission = await this.requestPermissions();
    if (!hasPermission) {
      console.log('Notification permission not granted');
      return false;
    }

    // Listen for notifications (this captures SMS app notifications on Android)
    this.notificationSubscription = Notifications.addNotificationReceivedListener(
      this.handleNotification.bind(this)
    );

    this.isListening = true;
    console.log('Notification service started');
    return true;
  }

  stopListening(): void {
    if (this.notificationSubscription) {
      Notifications.removeNotificationSubscription(this.notificationSubscription);
      this.notificationSubscription = null;
    }
    this.isListening = false;
    console.log('Notification service stopped');
  }

  private async handleNotification(notification: Notifications.Notification): Promise<void> {
    try {
      const { title, body, data } = notification.request.content;
      
      if (!body) return;

      // Check if this looks like a financial SMS
      if (!this.isFinancialSMS(title || '', body)) {
        return;
      }

      console.log('Financial SMS detected:', title, body.substring(0, 100));

      // Process the SMS
      await this.processFinancialSMS({
        title: title || 'Unknown',
        body,
        data,
      });
    } catch (error) {
      console.error('Error handling notification:', error);
    }
  }

  private isFinancialSMS(title: string, body: string): boolean {
    const text = `${title} ${body}`.toLowerCase();
    
    // Check for financial keywords
    const hasKeywords = FINANCIAL_KEYWORDS.some(keyword => text.includes(keyword.toLowerCase()));
    
    // Check if sender is from a bank/UPI service
    const isFromFinancialSource = BANK_SENDER_PATTERNS.some(pattern => pattern.test(title));
    
    // Check for amount patterns
    const hasAmount = /(?:rs\.?|inr|\u20b9|\$)\s*[\d,]+(?:\.\d{1,2})?/i.test(text) ||
                      /\d{1,3}(,\d{3})*(\.\d{1,2})?\s*(?:rs|inr|rupees)/i.test(text);

    return (hasKeywords || isFromFinancialSource) && hasAmount;
  }

  private async processFinancialSMS(sms: SMSNotification): Promise<void> {
    try {
      // Extract basic info first
      const basicInfo = aiService.extractBasicInfo(sms.body);
      
      if (!basicInfo.amount || basicInfo.amount <= 0) {
        console.log('No amount found in SMS');
        return;
      }

      // Check if AI is configured
      const isAIConfigured = aiService.isConfigured();
      let parsed: ParsedTransaction | null = null;
      let needsReview = false;

      if (isAIConfigured) {
        // Try AI analysis
        parsed = await aiService.analyzeSMS(sms.body, basicInfo.merchant, basicInfo.amount);
        
        if (!parsed || (parsed.confidence && parsed.confidence < 0.7)) {
          needsReview = true;
          // Use basic extraction as fallback
          parsed = {
            ...basicInfo,
            amount: parsed?.amount || basicInfo.amount || 0,
            currency: parsed?.currency || basicInfo.currency || 'INR',
            merchant: parsed?.merchant || basicInfo.merchant || 'Unknown',
            category: parsed?.category || basicInfo.category || 'Other',
            transaction_type: parsed?.transaction_type || basicInfo.transaction_type || 'debit',
            confidence: parsed?.confidence || 0.5,
          } as ParsedTransaction;
        }
      } else {
        // No AI configured, use basic extraction and mark for review
        needsReview = true;
        parsed = {
          amount: basicInfo.amount || 0,
          currency: basicInfo.currency || 'INR',
          merchant: basicInfo.merchant || 'Unknown',
          category: basicInfo.category || 'Other',
          transaction_type: basicInfo.transaction_type || 'debit',
          confidence: 0.5,
        } as ParsedTransaction;
      }

      // Find category ID
      const categories = await database.getCategories();
      const category = categories.find(c => 
        c.name.toLowerCase() === (parsed?.category || '').toLowerCase()
      ) || categories.find(c => c.name === 'Other') || categories[0];

      // Create transaction object
      const transaction: Omit<Transaction, 'id' | 'created_at'> = {
        amount: parsed?.amount || 0,
        currency: parsed?.currency || 'INR',
        category_id: category?.id || null,
        merchant: parsed?.merchant || 'Unknown',
        description: `Auto-categorized: ${parsed?.category || 'Other'}`,
        sms_body: sms.body,
        transaction_type: parsed?.transaction_type || 'debit',
        transaction_date: new Date().toISOString(),
      };

      // Save to database
      const transactionId = await database.addTransaction(transaction);
      
      // Get full transaction with category info
      const transactions = await database.getTransactions(1);
      const savedTransaction = transactions.find(t => t.id === transactionId);

      if (savedTransaction && this.onTransactionDetected) {
        this.onTransactionDetected(savedTransaction, needsReview);
      }

      // Show a local notification if review needed
      if (needsReview) {
        await this.showReviewNotification(savedTransaction || transaction);
      }
    } catch (error) {
      console.error('Error processing financial SMS:', error);
    }
  }

  private async showReviewNotification(transaction: Partial<Transaction>): Promise<void> {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Transaction Needs Review',
        body: `₹${transaction.amount} - ${transaction.merchant || 'Unknown'}. Tap to verify category.`,
        data: { transactionId: transaction.id },
      },
      trigger: null,
    });
  }

  // Manual SMS processing (for importing existing SMS)
  async processManualSMS(smsBody: string, date?: string): Promise<Transaction | null> {
    if (!this.isFinancialSMS('', smsBody)) {
      throw new Error('This does not appear to be a financial SMS');
    }

    const basicInfo = aiService.extractBasicInfo(smsBody);
    
    if (!basicInfo.amount || basicInfo.amount <= 0) {
      throw new Error('Could not extract amount from SMS');
    }

    const categories = await database.getCategories();
    const category = categories.find(c => 
      c.name.toLowerCase() === (basicInfo.category || '').toLowerCase()
    ) || categories.find(c => c.name === 'Other') || categories[0];

    const transaction: Omit<Transaction, 'id' | 'created_at'> = {
      amount: basicInfo.amount || 0,
      currency: basicInfo.currency || 'INR',
      category_id: category?.id || null,
      merchant: basicInfo.merchant || 'Unknown',
      description: 'Manual import',
      sms_body: smsBody,
      transaction_type: basicInfo.transaction_type || 'debit',
      transaction_date: date || new Date().toISOString(),
    };

    const transactionId = await database.addTransaction(transaction);
    const transactions = await database.getTransactions(1);
    return transactions.find(t => t.id === transactionId) || null;
  }
}

export const notificationService = new NotificationService();
