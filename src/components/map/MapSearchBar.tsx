import React from 'react';
import { View, TextInput, StyleSheet, TouchableOpacity, useColorScheme } from 'react-native';
import { Search } from 'lucide-react-native';
import { Colors } from '../../constants/Colors';
import { BlurView } from 'expo-blur';

interface MapSearchBarProps {
  onSearch: (text: string) => void;
}

export function MapSearchBar({ onSearch }: MapSearchBarProps) {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const colors = isDark ? Colors.dark : Colors.light;

  return (
    <View style={styles.container}>
      <BlurView
        intensity={isDark ? 30 : 60}
        tint={isDark ? 'dark' : 'light'}
        style={[styles.blurView, { borderColor: colors.border }]}
      >
        <Search color={colors.textSecondary} size={20} style={styles.icon} />
        <TextInput
          style={[styles.input, { color: colors.text }]}
          placeholder="Durak veya hat ara..."
          placeholderTextColor={colors.textSecondary}
          onChangeText={onSearch}
        />
      </BlurView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    zIndex: 10,
  },
  blurView: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 16,
    paddingHorizontal: 16,
    height: 52,
    borderWidth: 1,
    overflow: 'hidden',
  },
  icon: {
    marginRight: 12,
  },
  input: {
    flex: 1,
    fontSize: 16,
    fontFamily: 'Inter-Regular',
  },
});
