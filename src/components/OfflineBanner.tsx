import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import * as Network from 'expo-network';
import { WifiOff } from 'lucide-react-native';
import { Colors } from '../constants/Colors';

export function OfflineBanner() {
  const [isConnected, setIsConnected] = useState<boolean>(true);
  const slideAnim = useState(new Animated.Value(-100))[0];

  useEffect(() => {
    // Check initial state
    Network.getNetworkStateAsync().then(state => {
      setIsConnected(state.isConnected ?? true);
    });

    // We could add an interval or rely on NetInfo if we had @react-native-community/netinfo
    // For expo-network, we can just poll every 5 seconds
    const interval = setInterval(() => {
      Network.getNetworkStateAsync().then(state => {
        setIsConnected(state.isConnected ?? true);
      });
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (!isConnected) {
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(slideAnim, {
        toValue: -100,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }
  }, [isConnected, slideAnim]);

  return (
    <Animated.View style={[styles.container, { transform: [{ translateY: slideAnim }] }]}>
      <WifiOff color="#FFF" size={20} />
      <Text style={styles.text}>İnternet bağlantısı yok, çevrimdışı modda çalışılıyor.</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 50, // Below status bar
    left: 16,
    right: 16,
    backgroundColor: '#FF5252',
    borderRadius: 12,
    padding: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  text: {
    color: '#FFF',
    marginLeft: 8,
    fontWeight: 'bold',
    fontSize: 14,
  }
});
