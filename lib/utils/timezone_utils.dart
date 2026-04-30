// lib/utils/timezone_utils.dart
//
// Helper para parsear timestamps de Supabase correctamente a hora local.
//
// Supabase a veces devuelve timestamps sin indicador de zona horaria
// (ej: "2026-04-08T04:02:00") en columnas de tipo `timestamp` (sin tz).
// Dart los trataría como hora local, pero en realidad son UTC.
//
// Esta función fuerza la interpretación UTC y luego convierte a hora local
// del dispositivo (México, UTC-6).

DateTime parseSupabaseTs(String? raw) {
  if (raw == null || raw.isEmpty) return DateTime.now();

  // Si ya tiene info de zona (Z ó +hh:mm), DateTime.parse + toLocal es suficiente
  if (raw.contains('Z') || raw.contains('+')) {
    return DateTime.parse(raw).toLocal();
  }

  // Sin indicador de zona → asumir UTC agregando 'Z' y luego convertir a local
  return DateTime.parse('${raw}Z').toLocal();
}

/// Versión nullable — retorna null si el campo es null
DateTime? parseSupabaseTsOrNull(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return parseSupabaseTs(raw);
}
