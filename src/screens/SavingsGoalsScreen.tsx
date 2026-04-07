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

export default function SavingsGoalsScreen({ navigation }: any) {
  const [goals, setGoals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadGoals();
  }, []);

  const loadGoals = async () => {
    try {
      setLoading(true);
      const goalData = await database.getSavingsGoals();
      setGoals(goalData);
    } catch (error) {
      console.error('Error loading savings goals:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const getProgressPercentage = (goal: any): number => {
    return goal.target_amount > 0 
      ? Math.min((goal.current_amount / goal.target_amount) * 100, 100) 
      : 0;
  };

  const formatDate = (dateString: string) => {
    return moment(dateString).format('MMM D, YYYY');
  };

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <Text>Loading savings goals...</Text>
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
          Savings Goals
        </Text>
        <Ionicons
          name="add"
          size={24}
          color="white"
          onPress={() => 
            navigation.navigate('AddSavingsGoalScreen')
          }
        />
      </View>

      <View style={{ padding: 16 }}>
        {goals.length > 0 ? (
          <FlatList
            data={goals}
            keyExtractor={(item) => item.id.toString()}
            renderItem={({ item }) => {
              const progress = getProgressPercentage(item);
              
              return (
                <View style={styles.goalCard} key={item.id}>
                  <View style={styles.goalHeader}>
                    <Text style={styles.goalTitle}>
                      {item.name}
                    </Text>
                    <Text style={styles.goalDate}>
                      Target: {formatDate(item.target_date)}
                    </Text>
                  </View>
                  
                  <View style={styles.goalProgress}>
                    <Text style={styles.progressText}>
                      Saved: {formatCurrency(item.current_amount)} / 
                      {formatCurrency(item.target_amount)}
                    </Text>
                    <View style={styles.progressBarContainer}>
                      <View 
                        style={[
                          styles.progressBarFilled,
                          progress >= 100 ? styles.progressBarComplete : null,
                          { width: `${progress}%` }
                        ]}
                      />
                    </View>
                    <Text style={styles.progressPercent}>
                      {Math.round(progress)}%
                    </Text>
                  </View>
                  
                  <View style={styles.goalActions}>
                    <IconButton
                      icon="pencil"
                      onPress={() => 
                        navigation.navigate('EditSavingsGoalScreen', { 
                          goalId: item.id 
                        })
                      }
                      size={24}
                      iconColor="#6200ee"
                    />
                    <IconButton
                      icon="delete"
                      onPress={() => {
                        alert('Delete goal functionality would go here');
                      }}
                      size={24}
                      iconColor="#dc3545"
                    />
                  </View>
                </View>
              );
            }}
          />
        ) : (
          <View style={{ 
            padding: 40, 
            alignItems: 'center' 
          }}>
            <Text style={{ 
              color: '#999', 
              fontSize: 16 
            }}>
              No savings goals set yet
            </Text>
            <Button
              mode="outlined"
              onPress={() => 
                navigation.navigate('AddSavingsGoalScreen')
              }
            >
              Add First Goal
            </Button>
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  goalCard: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    elevation: 2,
  },
  goalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  goalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  goalDate: {
    fontSize: 12,
    color: '#666',
  },
  goalProgress: {
    marginBottom: 12,
  },
  progressText: {
    fontSize: 14,
    color: '#333',
    marginBottom: 8,
  },
  progressBarContainer: {
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    overflow: 'hidden',
    marginBottom: 4,
  },
  progressBarFilled: {
    height: '100%',
    backgroundColor: '#4CAF50',
  },
  progressBarComplete: {
    backgroundColor: '#2E7D32',
  },
  progressPercent: {
    fontSize: 12,
    color: '#666',
    alignSelf: 'flex-end',
  },
  goalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
});