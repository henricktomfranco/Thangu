import * as SQLite from 'expo-sqlite';
import { Transaction, Category, AIConfig } from '../types';

const DATABASE_NAME = 'finance_tracker.db';

// Default categories
const DEFAULT_CATEGORIES: Omit<Category, 'id'>[] = [
  { name: 'Food & Dining', color: '#FF6B6B', icon: '🍽️', is_default: true },
  { name: 'Transportation', color: '#4ECDC4', icon: '🚗', is_default: true },
  { name: 'Shopping', color: '#45B7D1', icon: '🛍️', is_default: true },
  { name: 'Bills & Utilities', color: '#96CEB4', icon: '💡', is_default: true },
  { name: 'Entertainment', color: '#FFEAA7', icon: '🎬', is_default: true },
  { name: 'Healthcare', color: '#DDA0DD', icon: '🏥', is_default: true },
  { name: 'Education', color: '#98D8C8', icon: '📚', is_default: true },
  { name: 'Salary & Income', color: '#85C1E2', icon: '💰', is_default: true },
  { name: 'Investment', color: '#F7DC6F', icon: '📈', is_default: true },
  { name: 'Other', color: '#AAB7B8', icon: '📦', is_default: true },
];

class DatabaseService {
  private db: SQLite.SQLiteDatabase | null = null;

  async init(): Promise<void> {
    this.db = await SQLite.openDatabaseAsync(DATABASE_NAME);
    await this.createTables();
    await this.seedCategories();
  }

  private async createTables(): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');

    await this.db.execAsync(`
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        is_default INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        currency TEXT DEFAULT 'INR',
        category_id INTEGER,
        merchant TEXT,
        description TEXT,
        sms_body TEXT,
        transaction_type TEXT CHECK(transaction_type IN ('debit', 'credit')),
        transaction_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      );

      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
      CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
    `);
  }

  private async seedCategories(): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');

    const existing = await this.db.getFirstAsync<{ count: number }>(
      'SELECT COUNT(*) as count FROM categories'
    );

    if (existing && existing.count === 0) {
      for (const category of DEFAULT_CATEGORIES) {
        await this.db.runAsync(
          `INSERT INTO categories (name, color, icon, is_default) VALUES (?, ?, ?, ?)`,
          [category.name, category.color, category.icon, category.is_default ? 1 : 0]
        );
      }
    }
  }

  // Categories
  async getCategories(): Promise<Category[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<Category>('SELECT * FROM categories ORDER BY name');
  }

  async addCategory(name: string, color: string, icon: string): Promise<number> {
    if (!this.db) throw new Error('Database not initialized');
    const result = await this.db.runAsync(
      `INSERT INTO categories (name, color, icon, is_default) VALUES (?, ?, ?, ?)`,
      [name, color, icon, 0]
    );
    return result.lastInsertRowId;
  }

  async updateCategory(id: number, name: string, color: string, icon: string): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    await this.db.runAsync(
      `UPDATE categories SET name = ?, color = ?, icon = ? WHERE id = ?`,
      [name, color, icon, id]
    );
  }

  async deleteCategory(id: number): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    await this.db.runAsync(`DELETE FROM categories WHERE id = ? AND is_default = 0`, [id]);
  }

  // Transactions
  async addTransaction(transaction: Omit<Transaction, 'id' | 'created_at'>): Promise<number> {
    if (!this.db) throw new Error('Database not initialized');
    const result = await this.db.runAsync(
      `INSERT INTO transactions (amount, currency, category_id, merchant, description, sms_body, transaction_type, transaction_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        transaction.amount,
        transaction.currency || 'INR',
        transaction.category_id,
        transaction.merchant,
        transaction.description,
        transaction.sms_body,
        transaction.transaction_type,
        transaction.transaction_date,
      ]
    );
    return result.lastInsertRowId;
  }

  async updateTransaction(id: number, updates: Partial<Transaction>): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    const fields: string[] = [];
    const values: any[] = [];

    if (updates.amount !== undefined) { fields.push('amount = ?'); values.push(updates.amount); }
    if (updates.category_id !== undefined) { fields.push('category_id = ?'); values.push(updates.category_id); }
    if (updates.merchant !== undefined) { fields.push('merchant = ?'); values.push(updates.merchant); }
    if (updates.description !== undefined) { fields.push('description = ?'); values.push(updates.description); }
    if (updates.transaction_type !== undefined) { fields.push('transaction_type = ?'); values.push(updates.transaction_type); }

    if (fields.length > 0) {
      values.push(id);
      await this.db.runAsync(
        `UPDATE transactions SET ${fields.join(', ')} WHERE id = ?`,
        values
      );
    }
  }

  async deleteTransaction(id: number): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    await this.db.runAsync(`DELETE FROM transactions WHERE id = ?`, [id]);
  }

  async getTransactions(limit: number = 100): Promise<Transaction[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<Transaction>(
      `SELECT t.*, c.name as category_name, c.color as category_color, c.icon as category_icon
       FROM transactions t
       LEFT JOIN categories c ON t.category_id = c.id
       ORDER BY t.transaction_date DESC
       LIMIT ?`,
      [limit]
    );
  }

  async getTransactionsByCategory(categoryId: number): Promise<Transaction[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<Transaction>(
      `SELECT t.*, c.name as category_name, c.color as category_color, c.icon as category_icon
       FROM transactions t
       LEFT JOIN categories c ON t.category_id = c.id
       WHERE t.category_id = ?
       ORDER BY t.transaction_date DESC`,
      [categoryId]
    );
  }

  async getTransactionsByDateRange(startDate: string, endDate: string): Promise<Transaction[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<Transaction>(
      `SELECT t.*, c.name as category_name, c.color as category_color, c.icon as category_icon
       FROM transactions t
       LEFT JOIN categories c ON t.category_id = c.id
       WHERE t.transaction_date BETWEEN ? AND ?
       ORDER BY t.transaction_date DESC`,
      [startDate, endDate]
    );
  }

  // Dashboard data
  async getBalance(): Promise<{ income: number; expense: number; balance: number }> {
    if (!this.db) throw new Error('Database not initialized');
    const result = await this.db.getFirstAsync<{
      income: number;
      expense: number;
    }>(
      `SELECT
        COALESCE(SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END), 0) as income,
        COALESCE(SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END), 0) as expense
       FROM transactions`
    );
    
    const income = result?.income || 0;
    const expense = result?.expense || 0;
    return { income, expense, balance: income - expense };
  }

  async getMonthlySummary(year: number): Promise<{ month: number; income: number; expense: number }[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<{ month: number; income: number; expense: number }>(
      `SELECT
        CAST(strftime('%m', transaction_date) AS INTEGER) as month,
        COALESCE(SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END), 0) as income,
        COALESCE(SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END), 0) as expense
       FROM transactions
       WHERE strftime('%Y', transaction_date) = ?
       GROUP BY month
       ORDER BY month`,
      [year.toString()]
    );
  }

  async getCategorySummary(startDate: string, endDate: string): Promise<{ category_id: number; category_name: string; category_color: string; total: number; percentage: number }[]> {
    if (!this.db) throw new Error('Database not initialized');
    const results = await this.db.getAllAsync<{
      category_id: number;
      category_name: string;
      category_color: string;
      total: number;
    }>(
      `SELECT
        t.category_id,
        COALESCE(c.name, 'Uncategorized') as category_name,
        COALESCE(c.color, '#999999') as category_color,
        SUM(t.amount) as total
       FROM transactions t
       LEFT JOIN categories c ON t.category_id = c.id
       WHERE t.transaction_type = 'debit'
         AND t.transaction_date BETWEEN ? AND ?
       GROUP BY t.category_id
       ORDER BY total DESC`,
      [startDate, endDate]
    );

    const totalExpense = results.reduce((sum, r) => sum + r.total, 0);
    return results.map(r => ({
      ...r,
      percentage: totalExpense > 0 ? Math.round((r.total / totalExpense) * 100) : 0,
    }));
  }

  // Settings
  async setSetting(key: string, value: string): Promise<void> {
    if (!this.db) throw new Error('Database not initialized');
    await this.db.runAsync(
      `INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)`,
      [key, value]
    );
  }

   async getSetting(key: string): Promise<string | null> {
     if (!this.db) throw new Error('Database not initialized');
     const result = await this.db.getFirstAsync<{ value: string }>(
       `SELECT value FROM settings WHERE key = ?`,
       [key]
     );
     return result?.value || null;
   }

   async getCurrency(): Promise<string> {
     const currency = await this.getSetting('currency') || 'INR';
     return currency;
   }

   async setCurrency(currency: string): Promise<void> {
     await this.setSetting('currency', currency);
   }

  async getAIConfig(): Promise<AIConfig> {
    const base_url = await this.getSetting('ai_base_url') || '';
    const api_key = await this.getSetting('ai_api_key') || '';
    const model = await this.getSetting('ai_model') || '';
    return { base_url, api_key, model };
  }

  async saveAIConfig(config: AIConfig): Promise<void> {
    await this.setSetting('ai_base_url', config.base_url);
    await this.setSetting('ai_api_key', config.api_key);
    await this.setSetting('ai_model', config.model);
  }

  // Export data
  async exportTransactions(): Promise<Transaction[]> {
    if (!this.db) throw new Error('Database not initialized');
    return await this.db.getAllAsync<Transaction>(
      `SELECT t.*, c.name as category_name
       FROM transactions t
       LEFT JOIN categories c ON t.category_id = c.id
       ORDER BY t.transaction_date DESC`
    );
  }

  async close(): Promise<void> {
    if (this.db) {
      await this.db.closeAsync();
      this.db = null;
    }
  }
}

export const database = new DatabaseService();
