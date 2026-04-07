import React, { useState, useEffect, useCallback } from 'react';
import { View, StyleSheet, FlatList, RefreshControl } from 'react-native';
import {
  Text,
  Card,
  Chip,
  Searchbar,
  FAB,
  Portal,
  Dialog,
  Button,
  TextInput,
  List,
  ActivityIndicator,
  SegmentedButtons,
} from 'react-native-paper';
import { database } from '../services/DatabaseService';
import { Transaction, Category } from '../types';

export default function TransactionsScreen({ route, navigation }: any) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [refreshing, setRefreshing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [filterType, setFilterType] = useState<'all' | 'debit' | 'credit'>('all');
  const [selectedCategory, setSelectedCategory] = useState<number | null>(null);
  const [editDialog, setEditDialog] = useState(false);
  const [editingTransaction, setEditingTransaction] = useState<Transaction | null>(null);
  const [editAmount, setEditAmount] = useState('');
  const [editMerchant, setEditMerchant] = useState('');

  const highlightId = route?.params?.highlightId;

  const loadData = useCallback(async () => {
    try {
      const [txns, cats] = await Promise.all([
        database.getTransactions(500),
        database.getCategories(),
      ]);
      setTransactions(txns);
      setCategories(cats);
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const getFilteredTransactions = () => {
    let filtered = [...transactions];

    // Filter by type
    if (filterType !== 'all') {
      filtered = filtered.filter(t => t.transaction_type === filterType);
    }

    // Filter by category
    if (selectedCategory !== null) {
      filtered = filtered.filter(t => t.category_id === selectedCategory);
    }

    // Filter by search
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(
        t =>
          t.merchant?.toLowerCase().includes(query) ||
          t.description?.toLowerCase().includes(query) ||
          t.sms_body?.toLowerCase().includes(query) ||
          t.category_name?.toLowerCase().includes(query)
      );
    }

    return filtered;
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  };

  const openEditDialog = (transaction: Transaction) => {
    setEditingTransaction(transaction);
    setEditAmount(transaction.amount.toString());
    setEditMerchant(transaction.merchant || '');
    setEditDialog(true);
  };

  const saveEdit = async () => {
    if (!editingTransaction) return;

    try {
      await database.updateTransaction(editingTransaction.id, {
        amount: parseFloat(editAmount) || 0,
        merchant: editMerchant,
      });
      setEditDialog(false);
      setEditingTransaction(null);
      await loadData();
    } catch (error) {
      console.error('Error updating transaction:', error);
    }
  };

  const deleteTransaction = async (id: number) => {
    try {
      await database.deleteTransaction(id);
      await loadData();
    } catch (error) {
      console.error('Error deleting transaction:', error);
    }
  };

  const renderTransaction = ({ item }: { item: Transaction }) => {
    const isHighlighted = item.id === highlightId;

    return (
      <Card
        style={[
          styles.transactionCard,
          isHighlighted && styles.highlightedCard,
        ]}
        onPress={() => openEditDialog(item)}
      >
        <Card.Content>
          <View style={styles.transactionHeader}>
            <View style={styles.transactionLeft}>
              <View style={[styles.categoryBadge, { backgroundColor: item.category_color || '#999' }]}>
                <Text style={styles.categoryIcon}>{item.category_icon || '📦'}</Text>
              </View>
              <View style={styles.transactionInfo}>
                <Text variant="bodyLarge" style={styles.merchantName}>
                  {item.merchant || 'Unknown'}
                </Text>
                <Text variant="bodySmall" style={styles.categoryText}>
                  {item.category_name || 'Uncategorized'}
                </Text>
              </View>
            </View>
            <Text
              variant="titleMedium"
              style={[
                styles.amount,
                item.transaction_type === 'credit' ? styles.incomeText : styles.expenseText,
              ]}
            >
              {item.transaction_type === 'credit' ? '+' : '-'}
              {formatCurrency(item.amount)}
            </Text>
          </View>

          <View style={styles.transactionFooter}>
            <Text variant="bodySmall" style={styles.date}>
              {formatDate(item.transaction_date)}
            </Text>
            <View style={styles.actions}>
              <Button
                mode="text"
                compact
                onPress={() => openEditDialog(item)}
              >
                Edit
              </Button>
              <Button
                mode="text"
                compact
                textColor="#c62828"
                onPress={() => deleteTransaction(item.id)}
              >
                Delete
              </Button>
            </View>
          </View>

          {item.sms_body && (
            <Text variant="bodySmall" style={styles.smsPreview} numberOfLines={2}>
              {item.sms_body}
            </Text>
          )}
        </Card.Content>
      </Card>
    );
  };

  const filteredTransactions = getFilteredTransactions();

  if (loading) {
    return (
      <View style={[styles.container, styles.center]}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Search Bar */}
      <Searchbar
        placeholder="Search transactions..."
        onChangeText={setSearchQuery}
        value={searchQuery}
        style={styles.searchbar}
      />

      {/* Title above filters */}
      <View style={styles.filterContainer}>
        <Text variant="titleMedium" style={styles.titleText}>
          Thangu Transactions
        </Text>
      </View>

      {/* Filter Chips */}
      <View style={styles.filterContainer}>
        <SegmentedButtons
          value={filterType}
          onValueChange={(value) => setFilterType(value as any)}
          buttons={[
            { value: 'all', label: 'All' },
            { value: 'debit', label: 'Expense' },
            { value: 'credit', label: 'Income' },
          ]}
          style={styles.segmentedButton}
        />
      </View>

      {/* Category Filter */}
      <View style={styles.categoryFilter}>
        <Chip
          selected={selectedCategory === null}
          onPress={() => setSelectedCategory(null)}
          style={styles.categoryChip}
        >
          All
        </Chip>
        <FlatList
          horizontal
          data={categories}
          keyExtractor={(item) => item.id.toString()}
          showsHorizontalScrollIndicator={false}
          renderItem={({ item }) => (
            <Chip
              selected={selectedCategory === item.id}
              onPress={() => setSelectedCategory(item.id === selectedCategory ? null : item.id)}
              style={[
                styles.categoryChip,
                selectedCategory === item.id && { backgroundColor: item.color + '33' },
              ]}
            >
              {item.icon} {item.name}
            </Chip>
          )}
        />
      </View>

      {/* Transaction List */}
      <FlatList
        data={filteredTransactions}
        keyExtractor={(item) => item.id.toString()}
        renderItem={renderTransaction}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text variant="bodyLarge" style={styles.emptyText}>
              {searchQuery || filterType !== 'all' || selectedCategory !== null
                ? 'No matching transactions'
                : 'No transactions yet'}
            </Text>
            <Text variant="bodySmall" style={styles.emptySubtext}>
              Transactions will appear here when Thangu detects them from SMS
            </Text>
          </View>
        }
      />

      {/* Edit Dialog */}
      <Portal>
        <Dialog visible={editDialog} onDismiss={() => setEditDialog(false)}>
          <Dialog.Title>Edit Thangu Transaction</Dialog.Title>
          <Dialog.Content>
            <TextInput
              label="Amount"
              value={editAmount}
              onChangeText={setEditAmount}
              keyboardType="decimal-pad"
              mode="outlined"
              style={styles.dialogInput}
            />
            <TextInput
              label="Merchant"
              value={editMerchant}
              onChangeText={setEditMerchant}
              mode="outlined"
              style={styles.dialogInput}
            />
            {editingTransaction && (
              <List.Item
                title="Category"
                description={editingTransaction.category_name || 'Uncategorized'}
                left={(props) => <List.Icon {...props} icon="tag" />}
                onPress={() => {
                  // Could add category picker here
                }}
              />
            )}
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setEditDialog(false)}>Cancel</Button>
            <Button onPress={saveEdit}>Save</Button>
          </Dialog.Actions>
        </Dialog>
      </Portal>
    </View>
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
  searchbar: {
    margin: 10,
    elevation: 2,
  },
  filterContainer: {
    paddingHorizontal: 10,
    marginBottom: 8,
  },
  segmentedButton: {
    height: 36,
  },
  categoryFilter: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    marginBottom: 8,
  },
  categoryChip: {
    marginRight: 6,
  },
  listContent: {
    padding: 10,
  },
  transactionCard: {
    marginBottom: 8,
    elevation: 1,
  },
  highlightedCard: {
    borderColor: '#6200ee',
    borderWidth: 2,
  },
  transactionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  transactionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  categoryBadge: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  categoryIcon: {
    fontSize: 20,
  },
  transactionInfo: {
    flex: 1,
  },
  merchantName: {
    fontWeight: '500',
  },
  categoryText: {
    color: '#666',
  },
  amount: {
    fontWeight: 'bold',
  },
  incomeText: {
    color: '#2e7d32',
  },
  expenseText: {
    color: '#c62828',
  },
  transactionFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  date: {
    color: '#999',
  },
  actions: {
    flexDirection: 'row',
  },
  smsPreview: {
    color: '#666',
    marginTop: 8,
    fontStyle: 'italic',
  },
  emptyContainer: {
    alignItems: 'center',
    padding: 40,
  },
  emptyText: {
    color: '#666',
    marginBottom: 8,
  },
  emptySubtext: {
    color: '#999',
  },
  dialogInput: {
    marginBottom: 12,
  },
});
