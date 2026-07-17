import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, useColorScheme, Switch } from 'react-native';
import { Colors } from '../../constants/Colors';
import { Typography } from '../../constants/Typography';
import { useSettingsStore, CITIES } from '../../store/useSettingsStore';
import { Moon, Sun, Globe, MapPin, Trash2, Info, ChevronRight } from 'lucide-react-native';

export default function SettingsScreen() {
  const systemColorScheme = useColorScheme();
  const { theme, setTheme, language, setLanguage, currentCityId, setCity } = useSettingsStore();
  
  const currentScheme = theme === 'system' ? systemColorScheme : theme;
  const isDark = currentScheme === 'dark';
  const colors = isDark ? Colors.dark : Colors.light;

  const currentCity = CITIES[currentCityId];

  return (
    <ScrollView style={[styles.container, { backgroundColor: colors.background }]}>
      <View style={styles.header}>
        <Text style={[styles.title, { color: colors.text, ...Typography.heading }]}>Ayarlar</Text>
        <Text style={[styles.subtitle, { color: colors.textSecondary, ...Typography.body }]}>
          Uygulama tercihleri ve yönetimi
        </Text>
      </View>

      {/* Görünüm */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.accent }]}>GÖRÜNÜM</Text>
        <View style={[styles.card, { backgroundColor: colors.cardBackground, borderColor: colors.border }]}>
          
          <View style={styles.settingItem}>
            <View style={styles.settingLeft}>
              <View style={[styles.iconBox, { backgroundColor: colors.tint + '15' }]}>
                {isDark ? <Moon size={20} color={colors.tint} /> : <Sun size={20} color={colors.tint} />}
              </View>
              <Text style={[styles.settingLabel, { color: colors.text }]}>Karanlık Mod</Text>
            </View>
            <Switch
              value={theme === 'dark' || (theme === 'system' && isDark)}
              onValueChange={(val) => setTheme(val ? 'dark' : 'light')}
              trackColor={{ false: colors.border, true: colors.tint }}
            />
          </View>
          
        </View>
      </View>

      {/* Tercihler */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.accent }]}>TERCİHLER</Text>
        <View style={[styles.card, { backgroundColor: colors.cardBackground, borderColor: colors.border }]}>
          
          <TouchableOpacity style={[styles.settingItem, styles.borderBottom, { borderBottomColor: colors.border }]}>
            <View style={styles.settingLeft}>
              <View style={[styles.iconBox, { backgroundColor: colors.tint + '15' }]}>
                <MapPin size={20} color={colors.tint} />
              </View>
              <Text style={[styles.settingLabel, { color: colors.text }]}>Şehir</Text>
            </View>
            <View style={styles.settingRight}>
              <Text style={[styles.settingValue, { color: colors.textSecondary }]}>{currentCity.name}</Text>
              <ChevronRight size={20} color={colors.textSecondary} />
            </View>
          </TouchableOpacity>

          <TouchableOpacity style={styles.settingItem} onPress={() => setLanguage(language === 'tr' ? 'en' : 'tr')}>
            <View style={styles.settingLeft}>
              <View style={[styles.iconBox, { backgroundColor: colors.tint + '15' }]}>
                <Globe size={20} color={colors.tint} />
              </View>
              <Text style={[styles.settingLabel, { color: colors.text }]}>Dil</Text>
            </View>
            <View style={styles.settingRight}>
              <Text style={[styles.settingValue, { color: colors.textSecondary }]}>{language.toUpperCase()}</Text>
              <ChevronRight size={20} color={colors.textSecondary} />
            </View>
          </TouchableOpacity>
          
        </View>
      </View>

      {/* Veri Yönetimi */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.accent }]}>VERİ YÖNETİMİ</Text>
        <View style={[styles.card, { backgroundColor: colors.cardBackground, borderColor: colors.border }]}>
          
          <TouchableOpacity style={styles.settingItem}>
            <View style={styles.settingLeft}>
              <View style={[styles.iconBox, { backgroundColor: colors.error + '15' }]}>
                <Trash2 size={20} color={colors.error} />
              </View>
              <Text style={[styles.settingLabel, { color: colors.error }]}>Önbelleği Temizle</Text>
            </View>
          </TouchableOpacity>
          
        </View>
      </View>

      {/* Hakkında */}
      <View style={styles.section}>
        <Text style={[styles.sectionTitle, { color: colors.accent }]}>HAKKINDA</Text>
        <View style={[styles.card, { backgroundColor: colors.cardBackground, borderColor: colors.border }]}>
          
          <TouchableOpacity style={styles.settingItem}>
            <View style={styles.settingLeft}>
              <View style={[styles.iconBox, { backgroundColor: colors.tint + '15' }]}>
                <Info size={20} color={colors.tint} />
              </View>
              <Text style={[styles.settingLabel, { color: colors.text }]}>Sürüm</Text>
            </View>
            <View style={styles.settingRight}>
              <Text style={[styles.settingValue, { color: colors.textSecondary }]}>1.0.0 (MVP)</Text>
            </View>
          </TouchableOpacity>
          
        </View>
      </View>
      
      <View style={{ height: 100 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  title: { marginBottom: 4 },
  subtitle: { opacity: 0.8 },
  section: {
    marginBottom: 24,
    paddingHorizontal: 16,
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: 'bold',
    marginBottom: 8,
    marginLeft: 4,
    letterSpacing: 1,
  },
  card: {
    borderRadius: 16,
    borderWidth: 1,
    overflow: 'hidden',
  },
  settingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
  },
  borderBottom: {
    borderBottomWidth: 1,
  },
  settingLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconBox: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  settingLabel: {
    fontSize: 16,
    fontWeight: '500',
  },
  settingRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  settingValue: {
    fontSize: 15,
    marginRight: 8,
  }
});
