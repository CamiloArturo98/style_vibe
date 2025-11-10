import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:style_vibe/models/message_model.dart';
import 'package:style_vibe/services/supabase_service.dart';
import 'package:style_vibe/services/ai_service.dart';
import 'package:style_vibe/widgets/chat_bubble.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  String? _conversationId;
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    if (_conversationId == null) {
      final newId = await SupabaseService.createConversation();
      if (newId != null) {
        setState(() => _conversationId = newId);
        await _loadMessages();
      }
    } else {
      await _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;
    
    print('📥 Cargando mensajes de conversación: $_conversationId');
    
    final messages = await SupabaseService.getMessages(_conversationId!);
    
    print('📨 Mensajes cargados: ${messages.length}');
    
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
    
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esperando inicialización...')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isAnalyzing = true);

      final bytes = await image.readAsBytes();
      print('📤 Subiendo ${bytes.length} bytes...');

      // Sube la imagen a Supabase
      final imageUrl = await _uploadImageBytes(bytes, image.name);

      if (imageUrl == null) {
        throw Exception('Error al subir la imagen');
      }

      print('✅ Imagen subida: $imageUrl');

      // Guarda el mensaje del usuario
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '📸 He subido una foto de mi outfit',
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      );

      await SupabaseService.saveMessage(
        conversationId: _conversationId!,
        message: userMessage,
      );

      await _loadMessages();

      // ANÁLISIS REAL CON IA
      print('🤖 Iniciando análisis con IA...');
      final analysis = await AIService.analyzeOutfit(bytes);

      if (analysis == null) {
        throw Exception('No se pudo analizar el outfit');
      }

      print('✅ Análisis completado: $analysis');

      // Crea el mensaje de la IA con el análisis real
      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '¡Análisis completado! 🔥',
        isUser: false,
        timestamp: DateTime.now(),
        analysis: analysis,
      );

      await SupabaseService.saveMessage(
        conversationId: _conversationId!,
        message: aiMessage,
      );

      await _loadMessages();
      setState(() => _isAnalyzing = false);
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImageBytes(Uint8List bytes, String originalName) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalName.split('.').last.toLowerCase();
      final filePath = '$userId/$timestamp.$extension';

      print('📤 Subiendo a: $filePath');

      String contentType = 'image/jpeg';
      if (extension == 'png') contentType = 'image/png';

      await SupabaseService.client.storage.from('outfits').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl = SupabaseService.client.storage
          .from('outfits')
          .getPublicUrl(filePath);

      print('✅ URL generada: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error al subir: $e');
      return null;
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.black87),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black87),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null) {
      return;
    }

    final userText = _messageController.text.trim();
    _messageController.clear();

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await SupabaseService.saveMessage(
      conversationId: _conversationId!,
      message: userMessage,
    );

    await _loadMessages();

    // RESPUESTA REAL DE LA IA
    print('🤖 Analizando mensaje de texto...');
    final aiResponse = await AIService.analyzeText(userText);

    final aiMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );

    await SupabaseService.saveMessage(
      conversationId: _conversationId!,
      message: aiMessage,
    );

    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('StyleVibe AI'),
            Text(
              'Análisis de outfit',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black87),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('👕', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            Text(
                              '¡Hola! Soy tu asistente de estilo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sube una foto de tu outfit y te diré\nqué vibe transmite ✨',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isAnalyzing ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isAnalyzing && index == _messages.length) {
                            return ChatBubble(
                              message: Message(
                                id: 'loading',
                                text: 'Analizando tu outfit...',
                                isUser: false,
                                timestamp: DateTime.now(),
                              ),
                              isLoading: true,
                            );
                          }
                          return ChatBubble(message: _messages[index]);
                        },
                      ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      color: Colors.black87,
                      onPressed: _showImageSourceDialog,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w300,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.black87),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.black87,
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}