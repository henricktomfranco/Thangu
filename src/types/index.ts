// Finance Tracker Types

export interface Transaction {
  id: number;
  amount: number;
  currency: string;
  category_id: number | null;
  merchant: string | null;
  description: string | null;
  sms_body: string | null;
  transaction_type: 'debit' | 'credit';
  transaction_date: string;
  created_at: string;
  category_name?: string;
  category_color?: string;
  category_icon?: string;
}

export interface Category {
  id: number;
  name: string;
  color: string;
  icon: string;
  is_default: boolean;
}

export interface AIConfig {
  base_url: string;
  api_key: string;
  model: string;
}

export interface ParsedTransaction {
  amount: number;
  currency: string;
  merchant: string;
  category: string;
  transaction_type: 'debit' | 'credit';
  confidence: number;
}

export interface NotificationMessage {
  title: string;
  body: string;
  data?: Record<string, any>;
}

export interface MonthlySummary {
  month: string;
  total_income: number;
  total_expense: number;
  balance: number;
}

export interface CategorySummary {
  category_id: number;
  category_name: string;
  category_color: string;
  total: number;
  percentage: number;
}

// Budget Types
export interface Budget {
  id: number;
  category_id: number;
  amount: number;
  month: string; // Format: YYYY-MM
  currency: string;
  created_at: string;
  updated_at: string;
  category_name?: string;
  category_color?: string;
}

// Savings Goal Types
export interface SavingsGoal {
  id: number;
  name: string;
  target_amount: number;
  current_amount: number;
  currency: string;
  target_date: string; // ISO date string
  monthly_contribution: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}
