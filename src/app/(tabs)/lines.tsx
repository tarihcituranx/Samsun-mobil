import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator, Pressable, useColorScheme, TextInput, ScrollView } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Typography } from '../../constants/Typography';
import { Bus, ArrowRight, Search, Star, Train, Ship, CableCar, Plane } from 'lucide-react-native';
import { Link } from 'expo-router';
import { useLines } from '../../services/api/samsun';

const CATEGORIES = [
  { id: 'all', label: 'Tümü', icon: Bus },
  { id: 'bus', label: 'Otobüs', icon: Bus },
  { id: 'tram', label: 'Tramvay', icon: Train },
  { id: 'express', label: 'Ekspres', icon: Bus },
  { id: 'ring', label: 'Ring', icon: Bus },
  { id: 'boat', label: 'Tekne', icon: Ship },
  { id: 'cablecar', label: 'Teleferik', icon: CableCar },
  { id: 'airport', label: 'Havalimanı', icon: Plane },
  { id: 'tourist', label: 'Turistik (Odak)', icon: Bus },
];

export default function LinesScreen() {
  const colorScheme = useColorScheme();
  const theme = Colors[colorScheme === 'light' ? 'light' : 'dark'];
  const { data: lines, isLoading, isError } = useLines();
  
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [favorites, setFavorites] = useState<Record<string, boolean>>({});

  const toggleFavorite = (code: string) => {
    setFavorites(prev => ({ ...prev, [code]: !prev[code] }));
  };

  const filteredLines = React.useMemo(() => {
    if (!lines) return [];
    return lines.filter((line: any) => {
      const code = (line.kisa_isim || line.hat_kodu || line.lineCode || '').toLowerCase();
      const name = (line.uzun_isim || line.hat_adi || line.lineName || '').toLowerCase();
      const query = searchQuery.toLowerCase();
      const matchesSearch = code.includes(query) || name.includes(query);
      
      // Kategori mantığı (Basit bir eşleştirme örneği)
      let matchesCategory = true;
      if (selectedCategory !== 'all') {
        if (selectedCategory === 'tram') matchesCategory = name.includes('tramvay') || code.startsWith('t');
        else if (selectedCategory === 'express') matchesCategory = name.includes('ekspres') || code.startsWith('e');
        else if (selectedCategory === 'ring') matchesCategory = name.includes('ring') || code.startsWith('r');
        else if (selectedCategory === 'airport') matchesCategory = code.startsWith('h');
        else if (selectedCategory === 'tourist') matchesCategory = code.startsWith('o');
        else matchesCategory = !name.includes('tramvay') && !code.startsWith('e') && !code.startsWith('r') && !code.startsWith('h') && !code.startsWith('o');
      }
      
      return matchesSearch && matchesCategory;
    });
  }, [lines, searchQuery, selectedCategory]);

  const renderItem = ({ item }: { item: any }) => {
    const lineCode = item.kisa_isim || item.hat_kodu || item.lineCode;
    const isFav = favorites[lineCode];
    
    return (
      <Link href={`/line/${encodeURIComponent(lineCode)}`} asChild>
      <Pressable style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
        <View style={styles.cardHeader}>
          <View style={[styles.iconBox, { backgroundColor: theme.tint + '20' }]}>
            <Bus size={20} color={theme.tint} />
          </View>
          <View style={styles.cardInfo}>
            <Text style={[styles.lineCode, { color: theme.text, ...Typography.subheading }]}>
              {lineCode}
            </Text>
            <Text style={[styles.lineName, { color: theme.textSecondary, ...Typography.body }]} numberOfLines={1}>
              {item.uzun_isim || item.hat_adi || item.lineName}
            </Text>
          </View>
          <Pressable onPress={() => toggleFavorite(lineCode)} style={{ padding: 8, marginRight: 4 }}>
            <Star size={22} color={isFav ? theme.warning : theme.tabIconDefault} fill={isFav ? theme.warning : "transparent"} />
          </Pressable>
          <ArrowRight size={20} color={theme.tabIconDefault} />
        </View>
      </Pressable>
    </Link>
  );
};

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: theme.text, ...Typography.heading }]}>Hatlar</Text>
        <Text style={[styles.subtitle, { color: theme.textSecondary, ...Typography.body }]}>
          Samsun toplu taşıma rotaları
        </Text>
        
        <View style={[styles.searchContainer, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
          <Search color={theme.textSecondary} size={20} style={styles.searchIcon} />
          <TextInput
            style={[styles.searchInput, { color: theme.text }]}
            placeholder="Hat kodu veya adı ile ara..."
            placeholderTextColor={theme.textSecondary}
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
        </View>
      </View>

      <View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.categoryScroll}>
          {CATEGORIES.map(cat => (
            <Pressable
              key={cat.id}
              style={[
                styles.categoryChip,
                { backgroundColor: selectedCategory === cat.id ? theme.tint : theme.cardBackground, borderColor: theme.border }
              ]}
              onPress={() => setSelectedCategory(cat.id)}
            >
              <cat.icon size={16} color={selectedCategory === cat.id ? '#FFF' : theme.text} />
              <Text style={[styles.categoryText, { color: selectedCategory === cat.id ? '#FFF' : theme.text }]}>
                {cat.label}
              </Text>
            </Pressable>
          ))}
        </ScrollView>
      </View>

      {isLoading ? (
        <View style={styles.center}>
          <ActivityIndicator size="large" color={theme.tint} />
        </View>
      ) : isError ? (
        <View style={styles.center}>
          <Text style={[styles.errorText, { color: theme.error }]}>Hatlar yüklenemedi.</Text>
        </View>
      ) : (
        <FlatList
          data={filteredLines}
          keyExtractor={(item) => item.hat_kodu || item.kisa_isim || item.lineCode}
          renderItem={renderItem}
          contentContainerStyle={styles.list}
          showsVerticalScrollIndicator={false}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  title: { marginBottom: 4 },
  subtitle: { opacity: 0.8, marginBottom: 16 },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 12,
    paddingHorizontal: 12,
    height: 48,
    borderWidth: 1,
  },
  searchIcon: { marginRight: 8 },
  searchInput: { flex: 1, fontSize: 16, fontFamily: 'Inter-Regular' },
  categoryScroll: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    gap: 10,
  },
  categoryChip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
  },
  categoryText: {
    marginLeft: 6,
    fontFamily: 'Inter-Medium',
    fontSize: 14,
  },
  list: {
    paddingHorizontal: 16,
    paddingBottom: 100, // Tab bar padding
  },
  card: {
    padding: 16,
    borderRadius: 16,
    marginBottom: 12,
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconBox: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  cardInfo: {
    flex: 1,
  },
  lineCode: {
    fontWeight: 'bold',
  },
  lineName: {
    marginTop: 2,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorText: {
    fontSize: 16,
    fontWeight: '500',
  }
});
