// lib/presentation/screens/auth/login_screen.dart
// ----------------------------------------
// Dual Login & Register screen with Egyptian Gold Duelist aesthetic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPassController = TextEditingController();

  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _regEmailController.dispose();
    _regUsernameController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo / Symbol
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGold.withOpacity(0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.style, color: AppTheme.primaryGold, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Yu-Gi-Oh! Collector',
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tu álbum digital con escaneo OCR inteligente',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 28),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryGold,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.primaryGold,
                    unselectedLabelColor: AppTheme.textSecondary,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Iniciar Sesión'),
                      Tab(text: 'Registrarse'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (authState.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.error.withOpacity(0.5)),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 12),
                    ),
                  ),

                // Form Container
                SizedBox(
                  height: 280,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Login Tab
                      Column(
                        children: [
                          TextField(
                            controller: _loginEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGold),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _loginPassController,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGold),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authState.status == AuthStatus.loading
                                  ? null
                                  : () async {
                                      final ok = await authNotifier.login(
                                        _loginEmailController.text.trim(),
                                        _loginPassController.text,
                                      );
                                      if (ok && mounted) context.go('/');
                                    },
                              child: authState.status == AuthStatus.loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                        ],
                      ),

                      // Register Tab
                      Column(
                        children: [
                          TextField(
                            controller: _regUsernameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de Duelista',
                              prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _regEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _regPassController,
                            obscureText: _obscurePass,
                            decoration: const InputDecoration(
                              labelText: 'Contraseña (mínimo 6 caracteres)',
                              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryGold),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authState.status == AuthStatus.loading
                                  ? null
                                  : () async {
                                      final ok = await authNotifier.register(
                                        _regEmailController.text.trim(),
                                        _regUsernameController.text.trim(),
                                        _regPassController.text,
                                      );
                                      if (ok && mounted) context.go('/');
                                    },
                              child: const Text('Crear Cuenta'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
