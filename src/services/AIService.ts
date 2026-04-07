import axios from 'axios';
import { AIConfig, ParsedTransaction } from '../types';

// Thangu AI Service for Finance Manager
// Handles communication with OpenAI-compatible APIs (Ollama, NVIDIA NIM, etc.)
// Thangu is the AI that powers transaction categorization

const DEFAULT_SYSTEM_PROMPT = `You are Thangu, an AI financial transaction analyzer. Extract information from the SMS message and categorize it.

Available categories: {categories}

Extract and return JSON in this exact format:
{
  "amount": number (required, the transaction amount),
  "currency": string (3-letter code like INR, USD, EUR),
  "merchant": string (merchant name or source, be concise),
  "category": string (must match one of the available categories),
  "transaction_type": "debit" | "credit",
  "confidence": number (0.0 to 1.0)
}

Rules:
- debit = money spent/withdrawn/charged
- credit = money received/deposited/refunded
- Look for keywords like "debited", "credited", "withdrawn", "received", "payment", "refund"
- Extract amount from patterns like "Rs. 500", "INR 1000", "$50.00"
- If confidence is low (< 0.7), still provide best guess but indicate with confidence score

Respond ONLY with valid JSON. No explanation.`;

export class AIService {
  private config: AIConfig = {
    base_url: '',
    api_key: '',
    model: '',
  };

  private availableCategories: string[] = [];

  setConfig(config: AIConfig): void {
    this.config = config;
  }

  setCategories(categories: string[]): void {
    this.availableCategories = categories;
  }

  isConfigured(): boolean {
    return !!(this.config.base_url && this.config.api_key && this.config.model);
  }

  getConfig(): AIConfig {
    return { ...this.config };
  }

  async analyzeSMS(smsText: string, merchant?: string, amount?: number): Promise<ParsedTransaction | null> {
    if (!this.isConfigured()) {
      console.log('AI not configured, skipping analysis');
      return null;
    }

    try {
      const systemPrompt = DEFAULT_SYSTEM_PROMPT.replace(
        '{categories}',
        this.availableCategories.join(', ') || 'Food, Transport, Shopping, Bills, Entertainment, Healthcare, Salary, Other'
      );

      const userPrompt = `SMS: "${smsText}"
${merchant ? `Merchant hint: ${merchant}` : ''}
${amount ? `Amount hint: ${amount}` : ''}`;

      const response = await axios.post(
        `${this.config.base_url}/chat/completions`,
        {
          model: this.config.model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
          temperature: 0.3,
          max_tokens: 200,
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.config.api_key}`,
          },
          timeout: 10000,
        }
      );

      const content = response.data.choices?.[0]?.message?.content;
      if (!content) {
        console.log('Empty response from AI');
        return null;
      }

      // Try to parse JSON from the response
      let parsed: ParsedTransaction;
      try {
        // Remove markdown code blocks if present
        const cleanContent = content.replace(/```json\n?|\n?```/g, '').trim();
        parsed = JSON.parse(cleanContent);
      } catch (parseError) {
        console.log('Failed to parse AI response as JSON:', content);
        // Try to extract JSON from the text
        const jsonMatch = content.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          parsed = JSON.parse(jsonMatch[0]);
        } else {
          throw parseError;
        }
      }

      // Validate required fields
      if (!parsed.amount || !parsed.transaction_type) {
        console.log('AI response missing required fields');
        return null;
      }

      // Ensure transaction_type is valid
      if (parsed.transaction_type !== 'debit' && parsed.transaction_type !== 'credit') {
        parsed.transaction_type = parsed.transaction_type.toLowerCase().includes('credit') ? 'credit' : 'debit';
      }

      return parsed;
    } catch (error) {
      console.error('AI analysis failed:', error);
      return null;
    }
  }

  // Simple pattern-based fallback when AI is unavailable
  extractBasicInfo(smsText: string): Partial<ParsedTransaction> {
    const text = smsText.toLowerCase();
    
    // Amount patterns
    const amountPatterns = [
      /(?:rs\.?|inr|\u20b9)\s*([\d,]+(?:\.\d{1,2})?)/i,
      /\$\s*([\d,]+(?:\.\d{1,2})?)/,
      /(?:amount|amt)[:\s]+(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{1,2})?)/i,
      /(?:debited|credited|spent|paid)[:\s]+(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{1,2})?)/i,
    ];

    let amount = 0;
    for (const pattern of amountPatterns) {
      const match = smsText.match(pattern);
      if (match) {
        amount = parseFloat(match[1].replace(/,/g, ''));
        break;
      }
    }

    // Transaction type
    const isCredit = /credited|received|refund|deposit|added|cashback/i.test(text);
    const isDebit = /debited|deducted|withdrawn|spent|paid|charged|purchase/i.test(text);
    
    let transaction_type: 'debit' | 'credit' = 'debit';
    if (isCredit && !isDebit) {
      transaction_type = 'credit';
    }

    // Currency
    let currency = 'INR';
    if (/\$|usd/i.test(text)) currency = 'USD';
    else if (/\u20ac|eur/i.test(text)) currency = 'EUR';
    else if (/\u00a3|gbp/i.test(text)) currency = 'GBP';

    // Merchant extraction (basic)
    let merchant = '';
    const merchantPatterns = [
      /(?:at|to|from|via)\s+([A-Za-z][A-Za-z\s&]+)/i,
      /(?:merchant|payee)[:\s]+([A-Za-z][A-Za-z\s&]+)/i,
    ];
    for (const pattern of merchantPatterns) {
      const match = smsText.match(pattern);
      if (match) {
        merchant = match[1].trim().split(/\s{2,}/)[0];
        break;
      }
    }

    // Category guess
    let category = 'Other';
    if (/food|restaurant|swiggy|zomato|uber eats|dominos|pizza|grocery/i.test(text)) category = 'Food & Dining';
    else if (/uber|ola|rapido|auto|taxi|cab|petrol|diesel|fuel|irctc|train|bus|metro/i.test(text)) category = 'Transportation';
    else if (/amazon|flipkart|myntra|shopping|mart|store|purchase/i.test(text)) category = 'Shopping';
    else if (/electricity|water|gas|bill|recharge|broadband|wifi|phone/i.test(text)) category = 'Bills & Utilities';
    else if (/movie|netflix|prime|spotify|entertainment|game/i.test(text)) category = 'Entertainment';
    else if (/hospital|doctor|medical|pharmacy|medicine|health/i.test(text)) category = 'Healthcare';
    else if (/salary|credit|income|deposit|refund/i.test(text)) category = 'Salary & Income';

    return {
      amount,
      currency,
      merchant: merchant || 'Unknown',
      category,
      transaction_type,
      confidence: 0.5,
    };
  }
}

export const aiService = new AIService();
