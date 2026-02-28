import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/translations.dart';
import '../widgets/gradient_button.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.t;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<AuthService>(
          builder: (context, auth, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo with gradient
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    t('app_name'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    t('app_tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.isLoading
                          ? null
                          : () => _handleSignIn(context, auth),
                      icon: Image.network(
                        'https://developers.google.com/identity/images/g-logo.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.g_mobiledata,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                      label: Text(
                        t('sign_in_google'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFF5F5F5),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          t('or'),
                          style: const TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // YouTube Connect Button
                  GradientButton(
                    text: t('connect_youtube'),
                    icon: Icons.play_arrow_rounded,
                    isLoading: auth.isLoading,
                    onPressed: auth.isLoading
                        ? null
                        : () => _handleSignIn(context, auth),
                  ),

                  const Spacer(flex: 2),

                  // Footer
                  Text(
                    t('privacy_policy'),
                    style: const TextStyle(
                      color: AppTheme.textHint,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleSignIn(BuildContext context, AuthService auth) async {
    final success = await auth.signIn();
    if (success && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (context.mounted) {
      final errorMsg = auth.lastError ?? Translations.t('sign_in_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Translations.t('sign_in_failed')}: $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
