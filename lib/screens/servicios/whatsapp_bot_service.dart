import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WhatsAppBotService {
  static const String _phone = "5215514236028";
  static const String _apiKey = "5259128";
  static const String _baseUrl = "https://api.callmebot.com/whatsapp.php";

  /// Envía un mensaje de texto a través del bot de CallMeBot
  static Future<bool> sendMessage(String text) async {
    try {
      final encodedText = Uri.encodeComponent(text);
      final url = Uri.parse('$_baseUrl?phone=$_phone&text=$encodedText&apikey=$_apiKey');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        debugPrint('Mensaje de WhatsApp enviado correctamente.');
        return true;
      } else {
        debugPrint('Error enviando mensaje WhatsApp. Status: ${response.statusCode}. Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Excepción enviando mensaje WhatsApp: $e');
      return false;
    }
  }
}
