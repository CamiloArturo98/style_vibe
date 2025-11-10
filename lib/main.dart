import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:style_vibe/auth/login_screen.dart';
import 'package:style_vibe/screens/home_screen.dart';
import 'package:style_vibe/services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ewarcfaaxwggnntgtkvc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3YXJjZmFheHdnZ25udGd0a3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExMjI2NzcsImV4cCI6MjA3NjY5ODY3N30.OluXsmnH3VyazYNS36lu5Vvsf3Thzai-BTwilEpPcZ0',
  );

  // Inicializa Claude AI
  AIService.initialize();

  runApp(
    const ProviderScope(
      child: StyleVibeApp(),
    ),
  );
}

class StyleVibeApp extends StatelessWidget {
  const StyleVibeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StyleVibe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.black87),
            ),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}