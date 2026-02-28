import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TubeMagicApp());
}

class TubeMagicApp extends StatelessWidget {
  const TubeMagicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'TubeMagic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Consumer<AuthService>(
          builder: (context, auth, _) {
            if (auth.isLoggedIn) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
