import React, { useState, useEffect, useCallback } from 'react';
import { View, StyleSheet, FlatList, Alert, RefreshControl } from 'react-native';
import {
  Text,
  Card,
  FAB,
  Portal,
  Dialog,
  Button,
  TextInput,
  List,
  ActivityIndicator,
  IconButton,
  Chip,
} from 'react-native-paper';
import { database } from '../services/DatabaseService';
import { Category } from '../types';

const CATEGORY_ICONS = ['🍽️', '🚗', '🛍️', '💡', '🎬', '🏥', '📚', '💰', '📈', '📦', '🏠', '👕', '🎮', '✈️', '🎁', '💼', '🔧', '📱', '🐕', '💇'];
const CATEGORY_COLORS = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
  '#DDA0DD', '#98D8C8', '#85C1E2', '#F7DC6F', '#AAB7B8',
  '#E74C3C', '#3498DB', '#9B59B6', '#1ABC9C', '#F39C12',
  '#E91E63', '#00BCD4', '#FF5722', '#8BC34A', '#607D8B',
];

export default function CategoriesScreen() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [dialogVisible, setDialogVisible] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [name, setName] = useState('');
  const [selectedIcon, setSelectedIcon] = useState('📦');
  const [selectedColor, setSelectedColor] = useState('#AAB7B8');

  const loadCategories = useCallback(async () => {
    try {
      const cats = await database.getCategories();
      setCategories(cats);
    } catch (error) {
      console.error('Error loading categories:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadCategories();
    setRefreshing(false);
  };

  const openAddDialog = () => {
    setEditingCategory(null);
    setName('');
    setSelectedIcon('📦');
    setSelectedColor('#AAB7B8');
    setDialogVisible(true);
  };

  const openEditDialog = (category: Category) => {
    if (category.is_default) {
      // Allow editing default categories
    }
    setEditingCategory(category);
    setName(category.name);
    setSelectedIcon(category.icon);
    setSelectedColor(category.color);
    setDialogVisible(true);
  };

  const saveCategory = async () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter a category name');
      return;
    }

    try {
      if (editingCategory) {
        await database.updateCategory(editingCategory.id, name.trim(), selectedColor, selectedIcon);
      } else {
        await database.addCategory(name.trim(), selectedColor, selectedIcon);
      }
      setDialogVisible(false);
      await loadCategories();
    } catch (error: any) {
      if (error.message?.includes('UNIQUE')) {
        Alert.alert('Error', 'A category with this name already exists');
      } else {
        Alert.alert('Error', 'Failed to save category');
      }
    }
  };

  const deleteCategory = (category: Category) => {
    if (category.is_default) {
      Alert.alert('Cannot Delete', 'Default categories cannot be deleted');
      return;
    }

    Alert.alert(
      'Delete Category',
      `Delete "${category.name}"? Transactions in this category will become uncategorized.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await database.deleteCategory(category.id);
              await loadCategories();
            } catch (error) {
              Alert.alert('Error', 'Failed to delete category');
            }
          },
        },
      ]
    );
  };

  const renderCategory = ({ item }: { item: Category }) => (
    <Card style={styles.categoryCard}>
      <Card.Content>
        <View style={styles.categoryRow}>
          <View style={[styles.iconCircle, { backgroundColor: item.color + '33' }]}>
            <Text style={styles.iconText}>{item.icon}</Text>
          </View>
          <View style={styles.categoryInfo}>
            <Text variant="titleMedium">{item.name}</Text>
            {item.is_default && (
              <Chip mode="outlined" compact style={styles.defaultChip}>
                Default
              </Chip>
            )}
          </View>
          <View style={styles.categoryActions}>
            <IconButton
              icon="pencil"
              size={20}
              onPress={() => openEditDialog(item)}
            />
            {!item.is_default && (
              <IconButton
                icon="delete"
                size={20}
                iconColor="#c62828"
                onPress={() => deleteCategory(item)}
              />
            )}
          </View>
        </View>
      </Card.Content>
    </Card>
  );

  if (loading) {
    return (
      <View style={[styles.container, styles.center]}>
        <ActivityIndicator size="large" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={categories}
        keyExtractor={(item) => item.id.toString()}
        renderItem={renderCategory}
        contentContainerStyle={styles.listContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text variant="bodyLarge" style={styles.emptyText}>
              No categories yet
            </Text>
          </View>
        }
      />

      <FAB
        icon="plus"
        style={styles.fab}
        onPress={openAddDialog}
      />

      {/* Add/Edit Dialog */}
      <Portal>
        <Dialog visible={dialogVisible} onDismiss={() => setDialogVisible(false)}>
          <Dialog.Title>
            {editingCategory ? 'Edit Category in Thangu' : 'Add Category to Thangu'}
          </Dialog.Title>
          <Dialog.Content>
            <TextInput
              label="Category Name"
              value={name}
              onChangeText={setName}
              mode="outlined"
              style={styles.input}
            />

            <Text variant="bodyMedium" style={styles.sectionLabel}>Icon</Text>
            <View style={styles.iconGrid}>
              {CATEGORY_ICONS.map((icon) => (
                <Chip
                  key={icon}
                  selected={selectedIcon === icon}
                  onPress={() => setSelectedIcon(icon)}
                  style={styles.iconChip}
                >
                  {icon}
                </Chip>
              ))}
            </View>

            <Text variant="bodyMedium" style={styles.sectionLabel}>Color</Text>
            <View style={styles.colorGrid}>
              {CATEGORY_COLORS.map((color) => (
                <View
                  key={color}
                  style={[
                    styles.colorCircle,
                    { backgroundColor: color },
                    selectedColor === color && styles.selectedColor,
                  ]}
                  onTouchEnd={() => setSelectedColor(color)}
                />
              ))}
            </View>

            {/* Preview */}
            <View style={styles.preview}>
              <Text variant="bodyMedium">Preview:</Text>
              <View style={[styles.previewBadge, { backgroundColor: selectedColor }]}>
                <Text style={styles.previewIcon}>{selectedIcon}</Text>
                <Text style={styles.previewName}>{name || 'Category Name'}</Text>
              </View>
            </View>
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={() => setDialogVisible(false)}>Cancel</Button>
            <Button onPress={saveCategory}>
              {editingCategory ? 'Update' : 'Add'}
            </Button>
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
  listContent: {
    padding: 10,
    paddingBottom: 100,
  },
  categoryCard: {
    marginBottom: 8,
  },
  categoryRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconCircle: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  iconText: {
    fontSize: 24,
  },
  categoryInfo: {
    flex: 1,
  },
  defaultChip: {
    marginTop: 4,
    height: 24,
  },
  categoryActions: {
    flexDirection: 'row',
  },
  fab: {
    position: 'absolute',
    margin: 16,
    right: 0,
    bottom: 0,
    backgroundColor: '#6200ee',
  },
  input: {
    marginBottom: 16,
  },
  sectionLabel: {
    marginBottom: 8,
    fontWeight: '500',
  },
  iconGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 16,
  },
  iconChip: {
    margin: 4,
    height: 40,
  },
  colorGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 16,
  },
  colorCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    margin: 4,
  },
  selectedColor: {
    borderWidth: 3,
    borderColor: '#333',
  },
  preview: {
    marginTop: 8,
    padding: 12,
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
  },
  previewBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 8,
    borderRadius: 8,
    marginTop: 8,
  },
  previewIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  previewName: {
    fontWeight: '500',
  },
  emptyContainer: {
    alignItems: 'center',
    padding: 40,
  },
  emptyText: {
    color: '#666',
  },
});
