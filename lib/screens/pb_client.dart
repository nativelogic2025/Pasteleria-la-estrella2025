import 'dart:io';
import 'package:pocketbase/pocketbase.dart';

String getBaseUrl() {
  if (Platform.isAndroid) return 'http://10.0.2.2:8090'; // Emulador Android
  return 'http://127.0.0.1:8090';                         // Windows/iOS/desktop/web
}

final pb = PocketBase(getBaseUrl());
