import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:style_vibe/models/message_model.dart';
import 'dart:io';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  
  static bool get isAuthenticated => client.auth.currentUser != null;
  static User? get currentUser => client.auth.currentUser;

  // ==================== STORAGE ====================
  
  /// Sube una imagen al Storage de Supabase
  /// Retorna la URL pública de la imagen o null si falla
  /// Sube una imagen al Storage de Supabase
/// Retorna la URL pública de la imagen o null si falla
/// Sube una imagen al Storage de Supabase
/// Retorna la URL pública de la imagen o null si falla
static Future<String?> uploadOutfitImage(File imageFile) async {
  try {
    final userId = currentUser?.id;
    if (userId == null) {
      print('❌ Usuario no autenticado');
      return null;
    }

    // Genera un nombre único para la imagen
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$timestamp.jpg';
    
    // Ruta completa
    final filePath = '$userId/$fileName';

    print('📤 Subiendo imagen a: outfits/$filePath');
    print('📁 Archivo local: ${imageFile.path}');

    // Lee los bytes del archivo
    final bytes = await imageFile.readAsBytes();
    print('📊 Tamaño del archivo: ${bytes.length} bytes');

    // Determina el content type
    String contentType = 'image/jpeg';
    if (imageFile.path.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    }

    print('📝 Content-Type: $contentType');

    // Usa el método upload con bytes y opciones
    final String fullPath = await client.storage.from('outfits').upload(
      filePath,
      imageFile,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    print('✅ Imagen subida exitosamente: $fullPath');

    // Obtiene la URL pública
    final publicUrl = client.storage.from('outfits').getPublicUrl(filePath);
    
    print('🔗 URL pública generada: $publicUrl');
    
    return publicUrl;
  } catch (e, stackTrace) {
    print('❌ Error detallado al subir imagen:');
    print('Error: $e');
    print('StackTrace: $stackTrace');
    return null;
  }
}

  // ==================== CONVERSACIONES ====================

  /// Crea una nueva conversación
  static Future<String?> createConversation({String? title}) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final response = await client.from('conversations').insert({
        'user_id': userId,
        'title': title ?? 'Nueva conversación',
      }).select('id').single();

      return response['id'] as String;
    } catch (e) {
      print('Error al crear conversación: $e');
      return null;
    }
  }

  /// Obtiene todas las conversaciones del usuario
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return [];

      final response = await client
          .from('conversations')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener conversaciones: $e');
      return [];
    }
  }

  /// Actualiza el título de una conversación
  static Future<bool> updateConversationTitle(
    String conversationId,
    String title,
  ) async {
    try {
      await client.from('conversations').update({
        'title': title,
      }).eq('id', conversationId);

      return true;
    } catch (e) {
      print('Error al actualizar conversación: $e');
      return false;
    }
  }

  /// Elimina una conversación (y todos sus mensajes por CASCADE)
  static Future<bool> deleteConversation(String conversationId) async {
    try {
      await client.from('conversations').delete().eq('id', conversationId);
      return true;
    } catch (e) {
      print('Error al eliminar conversación: $e');
      return false;
    }
  }

  // ==================== MENSAJES ====================

  /// Guarda un mensaje en la base de datos
  static Future<String?> saveMessage({
    required String conversationId,
    required Message message,
  }) async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final response = await client.from('messages').insert({
        'conversation_id': conversationId,
        'user_id': userId,
        'text': message.text,
        'is_user': message.isUser,
        'image_url': message.imageUrl,
        'analysis': message.analysis,
      }).select('id').single();

      return response['id'] as String;
    } catch (e) {
      print('Error al guardar mensaje: $e');
      return null;
    }
  }

  /// Obtiene todos los mensajes de una conversación
  static Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await client
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List).map((json) {
        return Message(
          id: json['id'] as String,
          text: json['text'] as String,
          isUser: json['is_user'] as bool,
          timestamp: DateTime.parse(json['created_at'] as String),
          imageUrl: json['image_url'] as String?,
          analysis: json['analysis'] as Map<String, dynamic>?,
        );
      }).toList();
    } catch (e) {
      print('Error al obtener mensajes: $e');
      return [];
    }
  }

  /// Stream de mensajes en tiempo real (para ver actualizaciones en vivo)
  static Stream<List<Message>> watchMessages(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) => data.map((json) {
              return Message(
                id: json['id'] as String,
                text: json['text'] as String,
                isUser: json['is_user'] as bool,
                timestamp: DateTime.parse(json['created_at'] as String),
                imageUrl: json['image_url'] as String?,
                analysis: json['analysis'] as Map<String, dynamic>?,
              );
            }).toList());
  }
}