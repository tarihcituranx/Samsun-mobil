import React from 'react';
import { TouchableOpacity, StyleSheet, useColorScheme } from 'react-native';
import { Navigation } from 'lucide-react-native';
import { Colors } from '../../constants/Colors';

interface LocationFABProps {
  onPress: () => void;
}

export function LocationFAB({ onPress }: LocationFABProps) {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const colors = isDark ? Colors.dark : Colors.light;

  return (
    <TouchableOpacity
      style={[
        styles.fab,
        { backgroundColor: colors.cardBackground, shadowColor: colors.shadow }
      ]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <Navigation color={colors.accent} size={24} style={styles.icon} />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  fab: {
    position: 'absolute',
    bottom: 30, // Adjust depending on bottom sheet / tab bar
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 4,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    zIndex: 10,
  },
  icon: {
    marginLeft: -2, // Optical alignment for navigation icon
    marginBottom: -2,
  }
});
