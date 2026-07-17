/**
 * Asis sisteminden gelen bozuk Türkçe karakterleri düzeltir.
 * "Ý" -> "İ", "Ð" -> "Ğ" gibi.
 */
export const fixTr = (text: string | null | undefined): string => {
  if (!text) return '';
  
  return text
    .replace(/Ý/g, 'İ')
    .replace(/Ð/g, 'Ğ')
    .replace(/Þ/g, 'Ş')
    .replace(/ý/g, 'ı')
    .replace(/ð/g, 'ğ')
    .replace(/þ/g, 'ş')
    // Bazen API boşluk veya gereksiz tirelerle gelebilir, trim edelim
    .trim();
};

export const parseHours = (hoursObj: Record<string, string[]> | null): Record<string, string[]> => {
  if (!hoursObj) return {};
  // Eğer özel bir format temizliği gerekiyorsa buraya eklenebilir.
  return hoursObj;
};
