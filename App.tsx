import React, { useEffect, useState } from 'react';
import { View, ActivityIndicator, StyleSheet } from 'react-native';
import { database } from './src/services/DatabaseService';
import { aiService } from './src/services/AIService';
import AppNavigator from './src/navigation/AppNavigator';

export default function App() {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      await database.init();

      const aiConfig = await database.getAIConfig();
      if (aiConfig.base_url) {
        aiService.setConfig(aiConfig);
      }

      const categories = await database.getCategories();
      aiService.setCategories(categories.map(c => c.name));
    } catch (error) {
      console.error('Error initializing app:', error);
    } finally {
      setIsReady(true);
    }
  };

  if (!isReady) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color="#6200ee" />
      </View>
    );
  }

  return <AppNavigator />;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
});
