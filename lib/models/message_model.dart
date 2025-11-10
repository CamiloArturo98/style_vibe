// Modelo de datos para los mensajes del chat
class Message {
  final String id;
  final String text;
  final bool isUser; // true si lo envió el usuario, false si es de la IA
  final DateTime? timestamp; // ⬅️ Ahora es nullable
  final String? imageUrl; // URL de la imagen si el mensaje incluye una foto
  final Map<String, dynamic>? analysis; // Análisis de la IA (vibe, sugerencias)

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    this.timestamp, // ⬅️ Ya no es required
    this.imageUrl,
    this.analysis,
  });

  // Convierte el mensaje a JSON para guardarlo en Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser,
      'timestamp': timestamp?.toIso8601String(), // ⬅️ Manejo seguro de null
      'image_url': imageUrl,
      'analysis': analysis,
    };
  }

  // Crea un mensaje desde JSON (cuando lo recuperamos de Supabase)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['is_user'] as bool,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : null, // ⬅️ Manejo seguro de null
      imageUrl: json['image_url'] as String?,
      analysis: json['analysis'] as Map<String, dynamic>?,
    );
  }

  // Crea una copia del mensaje con algunos campos modificados
  Message copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? imageUrl,
    Map<String, dynamic>? analysis,
  }) {
    return Message(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      analysis: analysis ?? this.analysis,
    );
  }
}