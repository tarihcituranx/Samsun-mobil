import 'react-native-gesture-handler';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useState } from 'react';
import { useColorScheme, Appearance, Platform, View, ActivityIndicator } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Colors } from '../constants/Colors';
import * as SplashScreen from 'expo-splash-screen';
import { useFonts } from 'expo-font';
import * as Notifications from 'expo-notifications';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { OfflineBanner } from '../components/OfflineBanner';

// Prevent the splash screen from auto-hiding before asset loading is complete.
SplashScreen.preventAutoHideAsync().catch(() => {});

// Global fetch timeout override (20 seconds) to prevent infinite pending
if (!(globalThis as any).__fetchOverridden) {
  const originalFetch = globalThis.fetch;
  (globalThis as any).fetch = async (url: any, options: any = {}) => {
    if (!options.signal) {
      try {
        options.signal = AbortSignal.timeout(20000);
      } catch(e) {}
    }
    return originalFetch(url, options);
  };
  (globalThis as any).__fetchOverridden = true;
}

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 1000 * 15, // 15 seconds stale time for GTFS RT
    },
  },
});

import { GlobalErrorBoundary } from '../components/ErrorBoundary';

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const safeScheme = colorScheme === 'light' ? 'light' : 'dark';
  const theme = Colors[safeScheme];
  const [isReady, setIsReady] = useState(false);

  const [fontsLoaded, fontError] = useFonts({
    'Inter-Regular': require('../../assets/fonts/Inter-Regular.ttf'),
    'Inter-Medium': require('../../assets/fonts/Inter-Medium.ttf'),
    'Inter-SemiBold': require('../../assets/fonts/Inter-SemiBold.ttf'),
    'Inter-Bold': require('../../assets/fonts/Inter-Bold.ttf'),
    'Inter-Black': require('../../assets/fonts/Inter-Black.ttf'),
  });

  useEffect(() => {
    if (fontError) {
      console.error('fontError loading failure:', fontError);
    }
  }, [fontError]);

  useEffect(() => {
    if ((fontsLoaded || fontError) && isReady) {
      SplashScreen.hideAsync().catch(() => {});
    }
  }, [fontsLoaded, fontError, isReady]);

  const initApp = async () => {
    try {
      // Theme
      const storedTheme = await AsyncStorage.getItem('@app_theme');
      if (storedTheme === 'light' || storedTheme === 'dark') {
        if (typeof Appearance.setColorScheme === 'function') {
          Appearance.setColorScheme(storedTheme);
        }
      }
      setIsReady(true);
    } catch (error) {
      console.log('Init error:', error);
      setIsReady(true); // Proceed anyway
    }
  };

  useEffect(() => {
    initApp();
  }, []);

  // Bildirim İzni Gecikmeli İsteme
  useEffect(() => {
    if (!isReady || Platform.OS === 'web') return;
    
    const timer = setTimeout(() => {
      Notifications.requestPermissionsAsync().catch((e) => {
        console.warn('Bildirim izni alınamadı:', e);
      });
    }, 1500);
    
    return () => clearTimeout(timer);
  }, [isReady]);

  if (!fontsLoaded && !fontError) {
    return null;
  }

  if (!isReady) {
    return (
      <View style={{ flex: 1, backgroundColor: theme.background, justifyContent: 'center', alignItems: 'center' }}>
        <ActivityIndicator size="large" color={theme.tint} />
      </View>
    );
  }

  return (
    <GlobalErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
        <OfflineBanner />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: theme.background } }}>
          <Stack.Screen name="index" options={{ animation: 'fade' }} />
          <Stack.Screen name="(tabs)" />
        </Stack>
      </QueryClientProvider>
    </GlobalErrorBoundary>
  );
}
