import React, { useState, useEffect } from 'react';
import { View, StyleSheet, FlatList } from 'react-native';
import {
  Text,
  Card,
  Button,
  Divider,
  List,
  Surface,
  Chip,
  IconButton,
} from 'react-native-paper';
import { Ionicons } from '@expo/vector-icons';
import { database } from '../services/DatabaseService';
import moment from 'moment';

export default function BudgetScreen({ navigation }: any) {
  const [budgets, setBudgets] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedMonth, setSelectedMonth] = useState(moment().format('YYYY-MM'));
  const [categories, setCategories] = useState<any[]>([]);

  useEffect(() => {
    loadData();
  }, [selectedMonth]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [budgetData, categoryData] = await Promise.all([
        database.getBudgets(selectedMonth),
        database.getCategories()
      ]);
      setBudgets(budgetData);
      setCategories(categoryData);
    } catch (error) {
      console.error('Error loading budget data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getCategoryName = (categoryId: number): string => {
    const category = categories.find(c => c.id === categoryId);
    return category ? category.name : 'Unknown Category';
  };

  const getCategoryColor = (categoryId: number): string => {
    const category = categories.find(c => c.id === categoryId);
    return category ? category.color : '#999999';
  };

  const getCategoryIcon = (categoryId: number): string => {
    const category = categories.find(c => c.id === categoryId);
    return category ? category.icon : '📦';
  };

  const getSpentAmount = async (categoryId: number): Promise<number> => {
    try {
      const startOfMonth = moment(selectedMonth, 'YYYY-MM').startOf('month').format('YYYY-MM-DD');
      const endOfMonth = moment(selectedMonth, 'YYYY-MM').endOf('month').format('YYYY-MM-DD');
      
      const transactions = await database.getTransactionsByCategoryAndDateRange(
        categoryId, 
        startOfMonth, 
        endOfMonth
      );
      
      return transactions.reduce((sum, t) => sum + (t.transaction_type === 'debit' ? t.amount : 0), 0);
    } catch (error) {
      console.error('Error calculating spent amount:', error);
      return 0;
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount);
  };

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <Text>Loading budgets...</Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: '#f5f5f5' }}>
      <View style={{ 
        padding: 20, 
        paddingTop: 40, 
        backgroundColor: '#6200ee',
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <Text style={{ color: 'white', fontWeight: 'bold', fontSize: 20 }}>
          Budget Planner
        </Text>
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <Ionicons
            name="chevron-back"
            size={24}
            color="white"
            onPress={() => {
              const prevMonth = moment(selectedMonth, 'YYYY-MM').subtract(1, 'month').format('YYYY-MM');
              setSelectedMonth(prevMonth);
            }}
          />
          <Text style={{ 
            color: 'white', 
            marginHorizontal: 12, 
            fontWeight: '500',
            fontSize: 16
          }}>
            {moment(selectedMonth, 'YYYY-MM').format('MMMM YYYY')}
          </Text>
          <Ionicons
            name="chevron-forward"
            size={24}
            color="white"
            onPress={() => {
              const nextMonth = moment(selectedMonth, 'YYYY-MM').add(1, 'month').format('YYYY-MM');
              setSelectedMonth(nextMonth);
            }}
          />
        </View>
      </View>

      <View style={{ padding: 16 }}>
        {budgets.length > 0 ? (
          <>
            <Text style={{ 
              fontSize: 18, 
              fontWeight: '600', 
              marginBottom: 12, 
              color: '#333' 
            }}>
              Budgets for {moment(selectedMonth, 'YYYY-MM').format('MMMM YYYY')}
            </Text>
            
            <FlatList
              data={budgets}
              keyExtractor={(item) => item.id.toString()}
              renderItem={({ item }) => {
                // We'll handle the async data in useEffect or use a different approach
                // For now, let's show loading state and update when data is ready
                return (
                  <View style={styles.budgetItem} key={item.id}>
                    <View style={styles.budgetInfo}>
                      <Text style={styles.categoryName}>
                        {getCategoryName(item.category_id)}
                      </Text>
                      <Text style={styles.month}>
                        {moment(item.month, 'YYYY-MM').format('MMMM YYYY')}
                      </Text>
                    </View>
                    
                    <View style={styles.budgetAmounts}>
                      <Text style={styles.spent}>
                        Spent: Loading...
                      </Text>
                      <Text style={styles.budget}>
                        Budget: {formatCurrency(item.amount)}
                      </Text>
                    </View>
                    
                    <View style={styles.progressContainer}>
                      <View 
                        style={[
                          styles.progressBar, 
                          styles.progressNormal,
                          { width: '50%' }
                        ]}
                      />
                    </View>
                    
                    <View style={styles.budgetActions}>
                      <IconButton
                        icon="pencil"
                        onPress={() => 
                          navigation.navigate('EditBudgetScreen', { 
                            budgetId: item.id 
                          })
                        }
                        size={24}
                        iconColor="#6200ee"
                      />
                      <IconButton
                        icon="delete"
                        onPress={() => {
                          alert('Delete budget functionality would go here');
                        }}
                        size={24}
                        iconColor="#dc3545"
                      />
                    </View>
                  </View>
                );
              }}
            />
          </>
        ) : (
          <View style={{ 
            padding: 40, 
            alignItems: 'center' 
          }}>
            <Text style={{ 
              color: '#999', 
              fontSize: 16 
            }}>
              No budgets set for this month
            </Text>
          </View>
        )}
        
        <Button
          mode="contained"
          style={{ margin: 16 }}
          onPress={() => 
            navigation.navigate('AddBudgetScreen')
          }
        >
          Add Budget
        </Button>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  budgetItem: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  budgetInfo: {
    flexDirection: 'column',
    marginBottom: 12,
  },
  categoryName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  month: {
    fontSize: 12,
    color: '#666',
  },
  budgetAmounts: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  spent: {
    fontSize: 14,
    color: '#c62828',
    fontWeight: '500',
  },
  budget: {
    fontSize: 14,
    color: '#2e7d32',
    fontWeight: '500',
  },
  progressContainer: {
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressBar: {
    height: '100%',
    backgroundColor: '#6200ee',
  },
  progressOver: {
    backgroundColor: '#c62828',
  },
  progressNormal: {
    backgroundColor: '#6200ee',
  },
  budgetActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 12,
  },
});