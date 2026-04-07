import React, { useState, useEffect, useCallback } from 'react';
import { View, StyleSheet, ScrollView, RefreshControl, Dimensions } from 'react-native';
import {
  Text,
  Card,
  Surface,
  ActivityIndicator,
  Chip,
  Button,
  FAB,
} from 'react-native-paper';
import { LineChart, PieChart } from 'react-native-chart-kit';
import { database } from '../services/DatabaseService';
import { notificationService } from '../services/NotificationService';
import { aiService } from '../services/AIService';
import { Transaction, CategorySummary } from '../types';

const screenWidth = Dimensions.get('window').width;

export default function DashboardScreen({ navigation }: any) {
  const [balance, setBalance] = useState({ income: 0, expense: 0, balance: 0 });
  const [recentTransactions, setRecentTransactions] = useState<Transaction[]>([]);
  const [categorySummary, setCategorySummary] = useState<CategorySummary[]>([]);
  const [monthlyData, setMonthlyData] = useState<number[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [loading, setLoading] = useState(true);
  const [currency, setCurrency] = useState('INR');

  const loadDashboardData = useCallback(async () => {
    try {
      // Get balance
      const bal = await database.getBalance();
      setBalance(bal);

      // Get recent transactions
      const transactions = await database.getTransactions(5);
      setRecentTransactions(transactions);

      // Get category summary for current month
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
      const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString();
      const categoryData = await database.getCategorySummary(startOfMonth, endOfMonth);
      setCategorySummary(categoryData);

      // Get monthly data for chart
      const year = now.getFullYear();
      const monthlySummary = await database.getMonthlySummary(year);
      const expenseData = monthlySummary.map(m => m.expense);
      // Fill missing months with 0
      const filledData = Array(12).fill(0);
      monthlySummary.forEach(m => {
        filledData[m.month - 1] = m.expense;
      });
      setMonthlyData(filledData);

      // Load AI config
      const aiConfig = await database.getAIConfig();
      if (aiConfig.base_url) {
        aiService.setConfig(aiConfig);
      }
    } catch (error) {
      console.error('Error loading dashboard:', error);
    } finally {
      setLoading(false);
    }
  }, []);

   useEffect(() => {
     loadDashboardData();
     loadCurrency();
   }, [loadDashboardData]);

   const loadCurrency = async () => {
     const currency = await database.getCurrency();
     setCurrency(currency);
   };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadDashboardData();
    setRefreshing(false);
  };

  const startNotificationListener = async () => {
    const started = await notificationService.startListening();
    setIsListening(started);
    
    notificationService.setTransactionCallback((transaction, needsReview) => {
      // Refresh data when new transaction detected
      loadDashboardData();
      
      if (needsReview) {
        navigation.navigate('Transactions', { highlightId: transaction.id });
      }
    });
  };

  const stopNotificationListener = () => {
    notificationService.stopListening();
    setIsListening(false);
  };

  useEffect(() => {
    // Start listening on mount
    startNotificationListener();
    return () => {
      stopNotificationListener();
    };
  }, []);

   const formatCurrency = (amount: number) => {
     // Map currency codes to Intl.NumberFormat compatible codes
     const currencyMap: Record<string, string> = {
       'INR': 'INR',
       'USD': 'USD',
       'EUR': 'EUR',
       'GBP': 'GBP',
       'JPY': 'JPY',
       'CAD': 'CAD',
       'AUD': 'AUD',
       'CNY': 'CNY',
       'SGD': 'SGD',
       'CHF': 'CHF'
     };
     const formatCurrencyCode = currencyMap[currency] || 'INR';
     
     return new Intl.NumberFormat('en-IN', {
       style: 'currency',
       currency: formatCurrencyCode,
       maximumFractionDigits: formatCurrencyCode === 'JPY' ? 0 : 2,
     }).format(amount);
   };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  };

  const getPieChartData = () => {
    if (categorySummary.length === 0) {
      return [
        {
          name: 'No Data',
          amount: 1,
          color: '#e0e0e0',
          legendFontColor: '#7F7F7F',
          legendFontSize: 12,
        },
      ];
    }
    return categorySummary.map((cat) => ({
      name: cat.category_name,
      amount: cat.total,
      color: cat.category_color,
      legendFontColor: '#333',
      legendFontSize: 12,
    }));
  };

  if (loading) {
    return (
      <View style={[styles.container, styles.center]}>
        <ActivityIndicator size="large" />
        <Text style={styles.loadingText}>Loading your finances...</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Surface style={styles.header} elevation={1}>
        <Text variant="headlineMedium" style={styles.title}>Thangu - Finance</Text>
        <Chip
          icon={isListening ? 'bell-ring' : 'bell-off'}
          style={styles.statusChip}
          textStyle={{ color: isListening ? '#4CAF50' : '#999' }}
        >
          {isListening ? 'Listening' : 'Not Listening'}
        </Chip>
      </Surface>

      {/* Balance Cards */}
      <View style={styles.balanceContainer}>
        <Card style={[styles.balanceCard, styles.incomeCard]}>
          <Card.Content>
            <Text variant="titleSmall" style={styles.balanceLabel}>Income</Text>
             <Text variant="headlineSmall" style={[styles.balanceAmount, styles.incomeText]}>
               {formatCurrency(balance.income)}
             </Text>
          </Card.Content>
        </Card>

        <Card style={[styles.balanceCard, styles.expenseCard]}>
          <Card.Content>
            <Text variant="titleSmall" style={styles.balanceLabel}>Expense</Text>
            <Text variant="headlineSmall" style={[styles.balanceAmount, styles.expenseText]}>
              {formatCurrency(balance.expense)}
            </Text>
          </Card.Content>
        </Card>
      </View>

      <Card style={styles.totalCard}>
        <Card.Content>
          <Text variant="titleSmall" style={styles.balanceLabel}>Net Balance</Text>
          <Text variant="displaySmall" style={[styles.totalAmount, balance.balance >= 0 ? styles.incomeText : styles.expenseText]}>
            {formatCurrency(balance.balance)}
          </Text>
        </Card.Content>
      </Card>

      {/* Monthly Spending Chart */}
      <Card style={styles.chartCard}>
        <Card.Title title="Monthly Spending" />
        <Card.Content>
          <LineChart
            data={{
              labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
              datasets: [{
                data: monthlyData.length > 0 ? monthlyData : [0],
              }],
            }}
            width={screenWidth - 60}
            height={200}
            chartConfig={{
              backgroundColor: '#fff',
              backgroundGradientFrom: '#fff',
              backgroundGradientTo: '#fff',
              decimalPlaces: 0,
              color: (opacity = 1) => `rgba(98, 0, 238, ${opacity})`,
              labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
              style: {
                borderRadius: 16,
              },
              propsForDots: {
                r: '4',
                strokeWidth: '2',
                stroke: '#6200ee',
              },
            }}
            bezier
            style={styles.chart}
          />
        </Card.Content>
      </Card>

      {/* Category Breakdown */}
      <Card style={styles.chartCard}>
        <Card.Title title="Spending by Category" subtitle="This Month" />
        <Card.Content>
          {categorySummary.length > 0 ? (
            <PieChart
              data={getPieChartData()}
              width={screenWidth - 60}
              height={220}
              chartConfig={{
                color: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
              }}
              accessor="amount"
              backgroundColor="transparent"
              paddingLeft="15"
              absolute
            />
          ) : (
            <Text style={styles.noDataText}>No expenses this month</Text>
          )}
        </Card.Content>
      </Card>

      {/* Recent Transactions */}
      <Card style={styles.transactionsCard}>
        <Card.Title
          title="Recent Transactions"
          right={() => (
            <Button onPress={() => navigation.navigate('Transactions')}>
              View All
            </Button>
          )}
        />
        <Card.Content>
          {recentTransactions.length === 0 ? (
            <Text style={styles.noDataText}>No transactions yet</Text>
          ) : (
            recentTransactions.map((t) => (
              <View key={t.id} style={styles.transactionItem}>
                <View style={styles.transactionLeft}>
                  <Text style={styles.transactionIcon}>{t.category_icon || '📦'}</Text>
                  <View>
                    <Text variant="bodyMedium" style={styles.transactionName}>
                      {t.merchant || 'Unknown'}
                    </Text>
                    <Text variant="bodySmall" style={styles.transactionCategory}>
                      {t.category_name} • {formatDate(t.transaction_date)}
                    </Text>
                  </View>
                </View>
                <Text
                  variant="titleMedium"
                  style={[
                    styles.transactionAmount,
                    t.transaction_type === 'credit' ? styles.incomeText : styles.expenseText,
                  ]}
                >
                  {t.transaction_type === 'credit' ? '+' : '-'}
                  {formatCurrency(t.amount)}
                </Text>
              </View>
            ))
          )}
        </Card.Content>
      </Card>

      <View style={styles.bottomPadding} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  center: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    color: '#666',
  },
  header: {
    padding: 20,
    paddingTop: 40,
    backgroundColor: '#6200ee',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: {
    color: 'white',
    fontWeight: 'bold',
  },
  statusChip: {
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  balanceContainer: {
    flexDirection: 'row',
    padding: 10,
  },
  balanceCard: {
    flex: 1,
    margin: 5,
  },
  incomeCard: {
    backgroundColor: '#e8f5e9',
  },
  expenseCard: {
    backgroundColor: '#ffebee',
  },
  balanceLabel: {
    color: '#666',
    marginBottom: 4,
  },
  balanceAmount: {
    fontWeight: 'bold',
  },
  incomeText: {
    color: '#2e7d32',
  },
  expenseText: {
    color: '#c62828',
  },
  totalCard: {
    margin: 15,
    marginTop: 0,
    alignItems: 'center',
  },
  totalAmount: {
    fontWeight: 'bold',
  },
  chartCard: {
    margin: 10,
  },
  chart: {
    marginVertical: 8,
    borderRadius: 16,
  },
  noDataText: {
    textAlign: 'center',
    color: '#999',
    padding: 20,
  },
  transactionsCard: {
    margin: 10,
    marginBottom: 20,
  },
  transactionItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  transactionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  transactionIcon: {
    fontSize: 24,
    marginRight: 12,
  },
  transactionName: {
    fontWeight: '500',
  },
  transactionCategory: {
    color: '#666',
  },
  transactionAmount: {
    fontWeight: 'bold',
  },
  bottomPadding: {
    height: 80,
  },
});
