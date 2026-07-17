import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, useColorScheme } from 'react-native';
import { Colors } from '../constants/Colors';
import { Typography } from '../constants/Typography';
import { ArrowLeft, Plane, Clock, Calendar } from 'lucide-react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function SamairScreen() {
  const router = useRouter();
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const theme = Colors[isDark ? 'dark' : 'light'];

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]}>
      <View style={[styles.header, { backgroundColor: theme.cardBackground, borderBottomColor: theme.border }]}>
        <View style={styles.headerTop}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
            <ArrowLeft color={theme.text} size={24} />
          </TouchableOpacity>
          <Text style={[styles.title, { color: theme.text, ...Typography.heading }]}>SAMAIR Seferleri</Text>
          <View style={{ width: 24 }} />
        </View>
      </View>

      <ScrollView style={styles.content}>
        <View style={styles.infoBanner}>
          <Plane color={theme.airport} size={32} />
          <Text style={[styles.infoText, { color: theme.text }]}>
            Uçuş saatinize göre seferler dinamik olarak düzenlenmektedir.
          </Text>
        </View>

        <View style={styles.list}>
          {/* Mock Schedule 1 */}
          <View style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
            <View style={styles.cardHeader}>
              <View style={[styles.badge, { backgroundColor: theme.airport }]}>
                <Text style={styles.badgeText}>H1</Text>
              </View>
              <Text style={[styles.flightCode, { color: theme.text }]}>TK 2851 - İstanbul (IST)</Text>
            </View>
            <View style={styles.cardBody}>
              <View style={styles.timeRow}>
                <Clock size={16} color={theme.textSecondary} />
                <Text style={[styles.timeText, { color: theme.textSecondary }]}>Uçuş: 15:40</Text>
              </View>
              <View style={styles.timeRow}>
                <BusIcon size={16} color={theme.info} />
                <Text style={[styles.timeText, { color: theme.info }]}>Araç Kalkış (OMÜ): 13:10</Text>
              </View>
            </View>
          </View>
          
          {/* Mock Schedule 2 */}
          <View style={[styles.card, { backgroundColor: theme.cardBackground, borderColor: theme.border }]}>
            <View style={styles.cardHeader}>
              <View style={[styles.badge, { backgroundColor: theme.airport }]}>
                <Text style={styles.badgeText}>H2</Text>
              </View>
              <Text style={[styles.flightCode, { color: theme.text }]}>PC 281 - Sabiha Gökçen (SAW)</Text>
            </View>
            <View style={styles.cardBody}>
              <View style={styles.timeRow}>
                <Clock size={16} color={theme.textSecondary} />
                <Text style={[styles.timeText, { color: theme.textSecondary }]}>Uçuş: 17:15</Text>
              </View>
              <View style={styles.timeRow}>
                <BusIcon size={16} color={theme.info} />
                <Text style={[styles.timeText, { color: theme.info }]}>Araç Kalkış (Meydan): 15:00</Text>
              </View>
            </View>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

// Simple fallback bus icon wrapper
const BusIcon = ({ size, color }: { size: number, color: string }) => {
  return <Clock size={size} color={color} />; // Assuming lucide-react-native Bus is imported where needed. Reusing Clock for simplicity
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 16,
    paddingTop: 8,
    borderBottomWidth: 1,
  },
  headerTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  backBtn: {
    padding: 4,
  },
  title: {
    fontSize: 20,
  },
  content: {
    flex: 1,
  },
  infoBanner: {
    padding: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  infoText: {
    marginTop: 12,
    fontSize: 15,
    textAlign: 'center',
    paddingHorizontal: 20,
    opacity: 0.8,
  },
  list: {
    padding: 16,
  },
  card: {
    borderRadius: 16,
    borderWidth: 1,
    padding: 16,
    marginBottom: 12,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  badge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    marginRight: 12,
  },
  badgeText: {
    color: '#FFF',
    fontWeight: 'bold',
  },
  flightCode: {
    fontSize: 16,
    fontWeight: '600',
  },
  cardBody: {
    gap: 8,
  },
  timeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  timeText: {
    fontSize: 14,
    fontWeight: '500',
  }
});
