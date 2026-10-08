import 'package:flutter/widgets.dart';
import 'package:gsmvoiceee/screens/account_screen.dart';
import 'package:gsmvoiceee/screens/auth_screen.dart';
import 'package:gsmvoiceee/screens/onboarding_screen.dart';
import 'package:gsmvoiceee/services/api_client.dart';
import 'package:gsmvoiceee/state/auth_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = HttpAuthApiClient();
  final authController = AuthController(apiClient: apiClient);
  runApp(XanhSMApp(controller: authController, apiClient: apiClient));
}

ShadThemeData createXanhSMTheme() {
  const primaryColor = Color(0xFF00B1A9);
  const primaryButtonBg = Color(0xFF008B83);

  return ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadGreenColorScheme.light().copyWith(
      primary: primaryColor,
      primaryForeground: Color(0xFFFFFFFF),
      background: const Color(0xFFF3F7F6),
      card: const Color(0xFFFFFFFF),
      border: const Color(0xFFD1DDD9),
      ring: primaryColor,
      destructive: const Color(0xFFDC2626),
    ),
    radius: const BorderRadius.all(Radius.circular(10)),
    textTheme: ShadTextTheme(family: 'PublicSans'),
    disableSecondaryBorder: true,
    inputTheme: _createInputTheme(),
    linkButtonTheme: const ShadButtonTheme(
      textDecoration: TextDecoration.none,
      hoverTextDecoration: TextDecoration.none,
      hoverForegroundColor: Color(0xFF00766F),
      pressedForegroundColor: Color(0xFF004D40),
    ),
    primaryButtonTheme: ShadButtonTheme(
      backgroundColor: primaryButtonBg,
      foregroundColor: Color(0xFFFFFFFF),
      height: 50,
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: const Color(0xFF0E938A),
          radius: BorderRadius.circular(10),
          width: 1.0,
        ),
        disableSecondaryBorder: true,
      ),
      textStyle: const TextStyle(
        fontFamily: 'PublicSans',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

ShadInputTheme _createInputTheme() {
  const radius = BorderRadius.all(Radius.circular(10));
  return ShadInputTheme(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    gap: 12,
    style: const TextStyle(
      fontFamily: 'PublicSans',
      fontSize: 16,
      height: 1.5,
      color: Color(0xFF1E3A37),
    ),
    placeholderStyle: const TextStyle(
      fontFamily: 'PublicSans',
      fontSize: 16,
      height: 1.5,
      color: Color(0xFF53716E),
    ),
    decoration: ShadDecoration(
      color: const Color(0xFFF7FBFA),
      border: ShadBorder.all(
        color: const Color(0xFFD1DDD9),
        radius: radius,
        width: 1,
        padding: EdgeInsets.zero,
      ),
      focusedBorder: ShadBorder.all(
        color: const Color(0xFF00A39C),
        radius: radius,
        width: 1,
        padding: EdgeInsets.zero,
      ),
      errorBorder: ShadBorder.all(
        color: const Color(0xFFEF4444),
        radius: radius,
        width: 1,
        padding: EdgeInsets.zero,
      ),
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
      errorStyle: const TextStyle(
        fontFamily: 'PublicSans',
        fontSize: 12,
        color: Color(0xFFEF4444),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'PublicSans',
        fontSize: 14,
        color: Color(0xFF3D5956),
        fontWeight: FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.only(bottom: 6),
      errorPadding: const EdgeInsets.only(top: 4),
    ),
  );
}

class XanhSMApp extends StatefulWidget {
  const XanhSMApp({super.key, required this.controller, this.apiClient});

  final AuthController controller;
  final AuthApiClient? apiClient;

  @override
  State<XanhSMApp> createState() => _XanhSMAppState();
}

class _XanhSMAppState extends State<XanhSMApp> {
  bool _hasFinishedOnboarding = false;

  @override
  void dispose() {
    widget.apiClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Xanh SM',
      debugShowCheckedModeBanner: false,
      theme: createXanhSMTheme(),
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      home: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (widget.controller.isAuthenticated) {
            return AccountScreen(controller: widget.controller);
          }
          if (!_hasFinishedOnboarding) {
            return OnboardingScreen(
              onFinish: () => setState(() => _hasFinishedOnboarding = true),
            );
          }
          return AuthScreen(
            key: const ValueKey('auth_screen'),
            controller: widget.controller,
          );
        },
      ),
    );
  }
}
