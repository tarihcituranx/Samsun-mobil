import React from 'react';
import { View, Text, StyleSheet, ActivityIndicator, ScrollView, TouchableOpacity, useColorScheme } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Typography } from '../../constants/Typography';
import { useSmartStation } from '../../services/api/samsun';
import { SuperStop } from '../../types/transit';
import { X, Clock, Bus } from 'lucide-react-native';
import { MotiView } from 'moti';
import { BlurView } from 'expo-blur';

interface StopBottomSheetProps {
  stop: SuperStop | null;
  onClose: () => void;
}

export function StopBottomSheet({ stop, onClose }: StopBottomSheetProps) {
  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';
  const theme = Colors[isDark ? 'dark' : 'light'];

  const { data: etas, isLoading, isError } = useSmartStation(stop?.id || null);

  if (!stop) return null;

  return (
    <MotiView 
      from={{ translateY: 400, opacity: 0 }}
      animate={{ translateY: 0, opacity: 1 }}
      transition={{ type: 'spring', damping: 20, stiffness: 200 }}
      style={[styles.container, { borderTopColor: theme.border }]}
    >
      <BlurView intensity={isDark ? 40 : 80} tint={isDark ? 'dark' : 'light'} style={StyleSheet.absoluteFill} />
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerInfo}>
          <Text style={[styles.title, { color: theme.text, ...Typography.heading }]} numberOfLines={1}>
            {stop.isim}
          </Text>
          <Text style={[styles.subtitle, { color: theme.textSecondary, ...Typography.body }]}>
            Durak No: {stop.id}
          </Text>
        </View>
        <TouchableOpacity onPress={onClose} style={[styles.closeBtn, { backgroundColor: theme.background }]}>
          <X size={20} color={theme.text} />
        </TouchableOpacity>
      </View>

      {/* Content */}
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {isLoading ? (
          <View style={styles.center}>
            <ActivityIndicator size="small" color={theme.tint} />
            <Text style={{ color: theme.textSecondary, marginTop: 8 }}>Araçlar aranıyor...</Text>
          </View>
        ) : isError ? (
          <View style={styles.center}>
            <Text style={{ color: theme.error }}>Veri alınamadı.</Text>
          </View>
        ) : !etas || etas.length === 0 ? (
          <View style={styles.center}>
            <Clock size={32} color={theme.textSecondary} style={{ opacity: 0.5, marginBottom: 8 }} />
            <Text style={{ color: theme.textSecondary }}>Şu an durağa yaklaşan araç bulunmuyor.</Text>
          </View>
        ) : (
          etas.map((eta: any, index: number) => (
            <View key={index} style={[styles.etaRow, { borderBottomColor: theme.border }]}>
              <View style={styles.etaLeft}>
                <View style={[styles.iconBox, { backgroundColor: theme.tint + '20' }]}>
                  <Bus size={18} color={theme.tint} />
                </View>
                <View>
                  <Text style={[styles.lineName, { color: theme.text, ...Typography.subheading }]}>
                    {eta.hat || eta.hat_kodu || "Bilinmiyor"}
                  </Text>
                  <Text style={{ color: theme.textSecondary, fontSize: 12 }}>{eta.guzergah || "Güzergah"}</Text>
                </View>
              </View>
              <View style={styles.etaRight}>
                <Text style={[styles.timeText, { color: eta.sure === 0 ? '#10b981' : theme.tint }]}>
                  {eta.sure === 0 ? "Durakta" : `${eta.sure} dk`}
                </Text>
              </View>
            </View>
          ))
        )}
      </ScrollView>
    </MotiView>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    borderTopWidth: 1,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    overflow: 'hidden',
    padding: 20,
    paddingBottom: 40,
    maxHeight: '50%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.15,
    shadowRadius: 16,
    elevation: 24,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  headerInfo: {
    flex: 1,
    marginRight: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  subtitle: {
    marginTop: 2,
    opacity: 0.8,
  },
  closeBtn: {
    padding: 8,
    borderRadius: 20,
  },
  content: {
    minHeight: 100,
  },
  center: {
    padding: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  etaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 0.5,
  },
  etaLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconBox: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  lineName: {
    fontWeight: '600',
  },
  etaRight: {
    paddingLeft: 12,
  },
  timeText: {
    fontSize: 18,
    fontWeight: 'bold',
  }
});
