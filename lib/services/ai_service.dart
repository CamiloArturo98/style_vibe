import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  // ⚠️ REEMPLAZA CON TU API KEY DE OPENROUTER
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static void initialize() {
    print('🤖 AI Service inicializado con OpenRouter (Acceso a todas las IAs)');
  }

  /// Analiza outfit con IA REAL (usa GPT-4o Mini)
  static Future<Map<String, dynamic>?> analyzeOutfit(Uint8List imageBytes) async {
    try {
      print('🔍 Analizando outfit con IA real (GPT-4o)...');

      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://stylevibe.app',
        },
        body: jsonEncode({
          'model': 'openai/gpt-4o-mini', // Modelo económico con visión
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Eres un experto estilista. Analiza este outfit y responde SOLO con este JSON (sin markdown):

{
  "vibe": "Estilo en 2-3 palabras",
  "description": "Descripción específica del outfit en 2-3 oraciones (menciona colores, prendas visibles, y vibra que transmite)",
  "suggestion": "Una sugerencia práctica y específica para mejorar el look"
}

IMPORTANTE: Responde en español y sé ESPECÍFICO sobre lo que VES en la imagen.'''
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
        }),
      );

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('❌ API Key inválida');
        return _getFallbackAnalysis();
      }

      if (response.statusCode != 200) {
        print('❌ Error: ${response.body}');
        return _getFallbackAnalysis();
      }

      final data = jsonDecode(response.body);
      final text = data['choices'][0]['message']['content'] as String;

      print('✅ Respuesta IA: $text');

      // Limpia y parsea JSON
      String clean = text.trim()
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}') + 1;
      
      if (start >= 0 && end > start) {
        clean = clean.substring(start, end);
      }

      try {
        final parsed = jsonDecode(clean);
        return {
          'vibe': parsed['vibe'].toString(),
          'description': parsed['description'].toString(),
          'suggestion': parsed['suggestion'].toString(),
        };
      } catch (e) {
        // Extrae con regex
        final vibe = RegExp(r'"vibe"\s*:\s*"([^"]+)"').firstMatch(clean)?.group(1);
        final desc = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(clean)?.group(1);
        final sugg = RegExp(r'"suggestion"\s*:\s*"([^"]+)"').firstMatch(clean)?.group(1);

        if (vibe != null && desc != null && sugg != null) {
          return {'vibe': vibe, 'description': desc, 'suggestion': sugg};
        }
      }

      return _getFallbackAnalysis();
      
    } catch (e) {
      print('❌ Error: $e');
      return _getFallbackAnalysis();
    }
  }

  static Map<String, dynamic> _getFallbackAnalysis() {
    return {
      'vibe': 'Estilo Personal',
      'description': 'Tu outfit refleja tu personalidad única. Las prendas seleccionadas muestran tu sentido del estilo.',
      'suggestion': 'Sigue confiando en tu estilo personal y experimenta con accesorios.',
    };
  }

  /// Responde preguntas con IA REAL
  static Future<String> analyzeText(String userMessage) async {
    try {
      print('🤖 Respondiendo con IA...');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://stylevibe.app',
        },
        body: jsonEncode({
          'model': 'openai/gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres StyleVibe AI, un asistente de moda amigable. Respondes en español, máximo 2-3 oraciones. Si piden analizar outfit, pídeles subir foto.'
            },
            {
              'role': 'user',
              'content': userMessage
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      }

      return '¡Hola! Sube una foto de tu outfit para analizarlo 📸';
      
    } catch (e) {
      return '¡Hola! Cuéntame sobre tu estilo o sube una foto 👕✨';
    }
  }
}