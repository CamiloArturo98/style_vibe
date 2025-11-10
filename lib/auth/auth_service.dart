import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider para acceder al servicio de autenticación desde cualquier parte
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Provider para saber si el usuario está autenticado
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Obtiene el usuario actual
  User? get currentUser => _supabase.auth.currentUser;

  // Verifica si hay sesión activa
  bool get isAuthenticated => currentUser != null;

  /// Registra un nuevo usuario
  /// Retorna null si todo salió bien, o un mensaje de error si falló
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName, // Metadata adicional del usuario
        },
      );

      if (response.user == null) {
        return 'Error al crear la cuenta';
      }

      return null; // Sin errores
    } on AuthException catch (e) {
      // Errores específicos de Supabase
      return _getAuthErrorMessage(e.message);
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  /// Inicia sesión con email y contraseña
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; // Sin errores
    } on AuthException catch (e) {
      return _getAuthErrorMessage(e.message);
    } catch (e) {
      return 'Error inesperado: ${e.toString()}';
    }
  }

  /// Cierra la sesión actual
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Convierte mensajes de error técnicos en mensajes amigables
  String _getAuthErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    } else if (error.contains('User already registered')) {
      return 'Este email ya está registrado';
    } else if (error.contains('Email not confirmed')) {
      return 'Por favor confirma tu email';
    }
    return error;
  }
}