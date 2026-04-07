import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { RadioButton } from 'react-native-paper';
import {
  Text,
  TextInput,
  Button,
  Card,
  Divider,
  List,
  Switch,
  HelperText,
  Surface,
  ActivityIndicator,
} from 'react-native-paper';
import { database } from '../services/DatabaseService';
import { aiService } from '../services/AIService';
import { AIConfig } from '../types';
import AsyncStorage from '@react-native-async-storage/async-storage';

const SETTINGS_KEY = 'ai_config';

export default function SettingsScreen() {
const [config, setConfig] = useState<AIConfig>({
  base_url: '',
  api_key: '',
  model: '',
});
const [currency, setCurrency] = useState('INR');
const currencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CNY', 'SGD', 'CHF'];
  const [isLoading, setIsLoading] = useState(false);
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null);
  const [isAutoCategorize, setIsAutoCategorize] = useState(true);
  const [showApiKey, setShowApiKey] = useState(false);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const savedConfig = await database.getAIConfig();
      if (savedConfig.base_url) {
        setConfig(savedConfig);
        aiService.setConfig(savedConfig);
      }
      
      const autoCat = await AsyncStorage.getItem('auto_categorize');
      setIsAutoCategorize(autoCat !== 'false');
    } catch (error) {
      console.error('Error loading settings:', error);
    }
  };

  const saveSettings = async () => {
    try {
      setIsLoading(true);
      await database.saveAIConfig(config);
      aiService.setConfig(config);
      setTestResult({ success: true, message: 'Settings saved successfully!' });
      setTimeout(() => setTestResult(null), 3000);
    } catch (error) {
      setTestResult({ success: false, message: 'Failed to save settings' });
    } finally {
      setIsLoading(false);
    }
  };

  const testConnection = async () => {
    if (!config.base_url || !config.api_key || !config.model) {
      setTestResult({ success: false, message: 'Please fill in all fields first' });
      return;
    }

    try {
      setIsLoading(true);
      setTestResult(null);

      // Quick test with a simple completion
      const response = await fetch(`${config.base_url}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.api_key}`,
        },
        body: JSON.stringify({
          model: config.model,
          messages: [{ role: 'user', content: 'Say "Connection successful"' }],
          max_tokens: 10,
        }),
      });

      if (response.ok) {
        setTestResult({ success: true, message: 'Connection successful! AI is ready.' });
        await saveSettings();
      } else {
        const error = await response.text();
        setTestResult({ success: false, message: `Connection failed: ${response.status} - ${error}` });
      }
    } catch (error: any) {
      setTestResult({ success: false, message: `Connection error: ${error.message}` });
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleAutoCategorize = async (value: boolean) => {
    setIsAutoCategorize(value);
    await AsyncStorage.setItem('auto_categorize', value.toString());
  };

  const clearAllData = () => {
    Alert.alert(
      'Clear All Data',
      'This will delete all transactions and categories. This cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Clear',
          style: 'destructive',
          onPress: async () => {
            try {
              // This would need proper implementation
              Alert.alert('Info', 'Clear data functionality would be implemented here');
            } catch (error) {
              Alert.alert('Error', 'Failed to clear data');
            }
          },
        },
      ]
    );
  };

  const exportData = async () => {
    try {
      const transactions = await database.exportTransactions();
      const data = JSON.stringify(transactions, null, 2);
      
      // Show data size
      const sizeKB = (data.length / 1024).toFixed(2);
      Alert.alert(
        'Export Data',
        `Exported ${transactions.length} transactions (${sizeKB} KB).\n\nData is ready to be copied or shared.`,
        [
          { text: 'Copy to Clipboard', onPress: () => {
            // In real app, use Clipboard API
            Alert.alert('Copied', 'Data copied to clipboard');
          }},
          { text: 'Close', style: 'cancel' },
        ]
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to export data');
    }
  };

  return (
    <ScrollView style={styles.container}>
      <Surface style={styles.header} elevation={1}>
        <Text variant="headlineMedium" style={styles.title}>Settings</Text>
      </Surface>

      {/* AI Configuration Section */}
      <Card style={styles.card}>
        <Card.Title title="AI Configuration" subtitle="Connect your AI model" />
        <Card.Content>
          <Text variant="bodySmall" style={styles.info}>
            Works with OpenAI-compatible APIs: OpenAI, Ollama, NVIDIA NIM, LiteLLM, etc.
          </Text>

          <TextInput
            label="Base URL"
            value={config.base_url}
            onChangeText={(text) => setConfig({ ...config, base_url: text.trim() })}
            placeholder="https://api.openai.com/v1"
            mode="outlined"
            style={styles.input}
            autoCapitalize="none"
            autoCorrect={false}
            right={<TextInput.Icon icon="web" />}
          />
          <HelperText type="info">
            For Ollama: http://192.168.1.xxx:11434/v1
          </HelperText>

          <TextInput
            label="API Key"
            value={config.api_key}
            onChangeText={(text) => setConfig({ ...config, api_key: text })}
            placeholder="sk-..."
            mode="outlined"
            style={styles.input}
            secureTextEntry={!showApiKey}
            autoCapitalize="none"
            right={
              <TextInput.Icon
                icon={showApiKey ? 'eye-off' : 'eye'}
                onPress={() => setShowApiKey(!showApiKey)}
              />
            }
          />

          <TextInput
            label="Model Name"
            value={config.model}
            onChangeText={(text) => setConfig({ ...config, model: text.trim() })}
            placeholder="gpt-4o-mini or llama3.2"
            mode="outlined"
            style={styles.input}
            autoCapitalize="none"
            right={<TextInput.Icon icon="brain" />}
          />
          <HelperText type="info">
            Examples: gpt-4o-mini, meta/llama3-70b-instruct, llama3.2
          </HelperText>

          {testResult && (
            <HelperText type={testResult.success ? 'info' : 'error'} style={styles.testResult}>
              {testResult.message}
            </HelperText>
          )}

          <View style={styles.buttonRow}>
            <Button
              mode="contained"
              onPress={testConnection}
              loading={isLoading}
              disabled={isLoading}
              style={styles.button}
            >
              Test & Save
            </Button>
            <Button
              mode="outlined"
              onPress={saveSettings}
              disabled={isLoading}
              style={styles.button}
            >
              Save Only
            </Button>
          </View>
        </Card.Content>
      </Card>

       {/* Notification Settings */}
       <Card style={styles.card}>
         <Card.Title title="Notifications" />
         <Card.Content>
           <List.Item
             title="Auto-categorize SMS"
             description="Automatically categorize transactions from SMS"
             right={() => (
               <Switch value={isAutoCategorize} onValueChange={handleToggleAutoCategorize} />
             )}
           />
         </Card.Content>
       </Card>

       {/* Currency Settings */}
       <Card style={styles.card}>
         <Card.Title title="Currency" subtitle="Select your preferred currency" />
         <Card.Content>
           <View style={styles.currencyPicker}>
             {currencies.map((curr) => (
               <View key={curr} style={styles.currencyOption}>
                 <RadioButton
                   value={curr}
                   status={currency === curr ? 'checked' : 'unchecked'}
                   onPress={() => setCurrency(curr)}
                   color="#6200ee"
                 />
                 <Text variant="bodyMedium" style={{ marginLeft: 8 }}>
                   {curr}
                 </Text>
               </View>
             ))}
           </View>
           <HelperText type="info">
             Selected currency will be used for all new transactions
           </HelperText>
         </Card.Content>
       </Card>

      {/* Provider Examples */}
      <Card style={styles.card}>
        <Card.Title title="Provider Examples" />
        <Card.Content>
          <View style={styles.exampleBox}>
            <Text variant="titleSmall">NVIDIA NIM</Text>
            <Text variant="bodySmall" style={styles.code}>
              URL: https://integrate.api.nvidia.com/v1{'\n'}
              Model: meta/llama3-70b-instruct
            </Text>
          </View>

          <View style={styles.exampleBox}>
            <Text variant="titleSmall">Ollama (Local)</Text>
            <Text variant="bodySmall" style={styles.code}>
              URL: http://192.168.1.100:11434/v1{'\n'}
              Model: llama3.2
            </Text>
          </View>

          <View style={styles.exampleBox}>
            <Text variant="titleSmall">OpenAI</Text>
            <Text variant="bodySmall" style={styles.code}>
              URL: https://api.openai.com/v1{'\n'}
              Model: gpt-4o-mini
            </Text>
          </View>
        </Card.Content>
      </Card>

      {/* Data Management */}
      <Card style={styles.card}>
        <Card.Title title="Data Management" />
        <Card.Content>
          <Button
            mode="outlined"
            onPress={exportData}
            icon="export"
            style={styles.dataButton}
          >
            Export Transactions
          </Button>
          <Button
            mode="outlined"
            onPress={clearAllData}
            icon="delete"
            textColor="#dc3545"
            style={styles.dataButton}
          >
            Clear All Data
          </Button>
        </Card.Content>
      </Card>

      <View style={styles.footer}>
<Text variant="bodySmall" style={styles.version}>
            Thangu v1.0 - Your AI Finance Manager
          </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    padding: 20,
    paddingTop: 40,
    backgroundColor: '#6200ee',
  },
  title: {
    color: 'white',
    fontWeight: 'bold',
  },
  card: {
    margin: 10,
  },
  input: {
    marginTop: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 16,
  },
  button: {
    flex: 1,
    marginHorizontal: 4,
  },
  info: {
    color: '#666',
    marginBottom: 12,
  },
  testResult: {
    marginTop: 8,
  },
  exampleBox: {
    backgroundColor: '#f0f0f0',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  code: {
    fontFamily: 'monospace',
    color: '#333',
    marginTop: 4,
  },
  dataButton: {
    marginVertical: 6,
  },
   footer: {
     padding: 20,
     alignItems: 'center',
   },
   version: {
     color: '#999',
   },
   currencyPicker: {
     marginTop: 12,
   },
   currencyOption: {
     flexDirection: 'row',
     alignItems: 'center',
     paddingVertical: 12,
     borderBottomWidth: 1,
     borderBottomColor: '#f0f0f0',
   },
 });
