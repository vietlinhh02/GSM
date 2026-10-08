import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show SnackBar;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmvoiceee/main.dart';
import 'package:gsmvoiceee/models/auth_models.dart';
import 'package:gsmvoiceee/screens/auth_screen.dart';
import 'package:gsmvoiceee/screens/info_screen.dart';
import 'package:gsmvoiceee/screens/onboarding_screen.dart';
import 'package:gsmvoiceee/services/api_client.dart';
import 'package:gsmvoiceee/state/auth_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MockAuthApiClient implements AuthApiClient {
  bool failLogin = false;
  bool failRegister = false;
  String errorMessage = 'Lỗi thử nghiệm';
  int loginCalls = 0;
  int registerCalls = 0;
  int logoutCalls = 0;
  int meCalls = 0;
  Completer<AuthResult>? pendingLoginCompleter;

  UserProfile mockUser = UserProfile(
    id: 'user-001',
    name: 'Nguyen Van A',
    email: 'user.a@xanhsm.vn',
    createdAt: DateTime.utc(2026, 10, 7, 8, 30),
  );

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (pendingLoginCompleter != null) {
      return pendingLoginCompleter!.future;
    }
    if (failLogin) {
      throw ApiException(errorMessage, statusCode: 401);
    }
    return AuthResult(token: 'mock-token-login', user: mockUser);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    if (failRegister) {
      throw ApiException(errorMessage, statusCode: 409);
    }
    return AuthResult(
      token: 'mock-token-reg',
      user: UserProfile(
        id: 'user-002',
        name: name,
        email: email,
        createdAt: DateTime.utc(2026, 10, 7, 8, 30),
      ),
    );
  }

  @override
  Future<UserProfile> getMe(String token) async {
    meCalls++;
    return mockUser;
  }

  @override
  Future<void> logout(String token) async {
    logoutCalls++;
  }

  @override
  void dispose() {}
}

Widget createTestApp(AuthController controller, MockAuthApiClient api) {
  return ShadApp(
    theme: createXanhSMTheme(),
    home: AuthScreen(controller: controller),
  );
}

void main() {
  late MockAuthApiClient mockApi;
  late AuthController controller;

  setUp(() {
    mockApi = MockAuthApiClient();
    controller = AuthController(apiClient: mockApi);
  });

  testWidgets('Auth controls have matching size and consistent gaps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    Rect inputRect(String key) => tester.getRect(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(ShadInput),
      ),
    );
    final email = inputRect('auth_email_field');
    final password = inputRect('auth_password_field');
    final submit = tester.getRect(find.byKey(const Key('auth_submit_button')));
    expect(email.height, 56);
    expect(email.height, password.height);
    expect(email.size, submit.size);
    expect(password.top - email.bottom, 12);
    expect(submit.top - password.bottom, 12);

    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();
    final fields = [
      'auth_name_field',
      'auth_email_field',
      'auth_password_field',
      'auth_confirm_password_field',
    ];
    for (final key in fields) {
      expect(inputRect(key).size, email.size, reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding has three pages and opens auth from its final CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: createXanhSMTheme(),
        home: OnboardingScreen(onFinish: () {}),
      ),
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byKey(const Key('onboarding_pages')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_continue_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_continue_button')));
    await tester.pumpAndSettle();
    expect(find.text('Vào trang đăng nhập'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_continue_button')));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu cùng GSM Voice'), findsOneWidget);
  });

  testWidgets(
    'Submit button animates a press and restores after cancellation',
    (tester) async {
      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('auth_submit_button'));
      final motion = find.byKey(const Key('auth_submit_motion'));
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 60));
      final scale = tester
          .widget<TweenAnimationBuilder<double>>(motion)
          .tween
          .end;
      expect(scale, lessThan(1));
      expect(scale, greaterThanOrEqualTo(0.95));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<TweenAnimationBuilder<double>>(motion).tween.end, 1);
      expect(mockApi.loginCalls, 0);
    },
  );

  testWidgets('Auth links have no underline, including mouse hover', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    for (final key in ['auth_mode_switch_link']) {
      final link = find.byKey(Key(key));
      final text = find.descendant(of: link, matching: find.byType(RichText));
      expect(
        tester.widget<RichText>(text).text.style?.decoration,
        TextDecoration.none,
      );
      await mouse.moveTo(tester.getCenter(link));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RichText>(text).text.style?.decoration,
        TextDecoration.none,
      );
    }
  });

  testWidgets(
    'Info header icons align with titles and leave a consistent gap',
    (tester) async {
      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_privacy_link')));
      await tester.pumpAndSettle();
      for (final section in InfoSection.values) {
        await tester.ensureVisible(find.byKey(Key('info_tab_${section.name}')));
        await tester.tap(find.byKey(Key('info_tab_${section.name}')));
        await tester.pumpAndSettle();
        final icon = tester.getRect(
          find.byIcon(
            section == InfoSection.privacy
                ? LucideIcons.info
                : LucideIcons.circleHelp,
          ),
        );
        final title = tester.getRect(
          find.text(
            section == InfoSection.privacy
                ? 'Thông tin sử dụng dữ liệu'
                : 'Câu hỏi thường gặp (FAQ)',
          ),
        );
        expect(icon.center.dy, closeTo(title.center.dy, 0.1));
        expect(title.left - icon.right, 12);
      }
    },
  );

  testWidgets(
    'Screen progress does not appear for navigation or local tab changes',
    (tester) async {
      await tester.pumpWidget(createTestApp(controller, mockApi));
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('auth_legal_notice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth_privacy_link')));
      await tester.pump();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info_tab_faq')));
      await tester.pump();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      expect(find.text('Câu hỏi thường gặp (FAQ)'), findsOneWidget);
    },
  );

  testWidgets(
    'Screen progress stays while authentication waits then clears on account entry',
    (tester) async {
      final pending = Completer<AuthResult>();
      mockApi.pendingLoginCompleter = pending;
      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth_email_field')),
        'user@xanhsm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('auth_password_field')),
        'Password123',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Đang đăng nhập…'), findsNothing);
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      expect(mockApi.loginCalls, 1);
      pending.complete(AuthResult(token: 'mock-token', user: mockApi.mockUser));
      await tester.pump();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screen_loading')), findsNothing);
      expect(find.text('Tài khoản Xanh SM'), findsOneWidget);
    },
  );

  for (final scale in [1.8, 3.0]) {
    testWidgets(
      'Info icons align with the first title line at ${scale}x text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ShadApp(theme: createXanhSMTheme(), home: const InfoScreen()),
        );
        await tester.pumpAndSettle();
        for (final section in InfoSection.values) {
          await tester.tap(find.byKey(Key('info_tab_${section.name}')));
          await tester.pumpAndSettle();
          final privacy = section == InfoSection.privacy;
          final icon = tester.getRect(
            find.byIcon(privacy ? LucideIcons.info : LucideIcons.circleHelp),
          );
          final title = tester.getRect(
            find.text(
              privacy
                  ? 'Thông tin sử dụng dữ liệu'
                  : 'Câu hỏi thường gặp (FAQ)',
            ),
          );
          final subtitle = tester.getRect(
            find.textContaining(
              privacy
                  ? 'Cách ứng dụng GSM Voice'
                  : 'Giải đáp các câu hỏi phổ biến',
            ),
          );
          expect(icon.center.dy, closeTo(title.top + 12 * scale, 0.1));
          expect(title.left - icon.right, 12);
          expect(subtitle.left, title.left);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('Form validation displays error on empty fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    // Tap submit on empty login form
    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập địa chỉ email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(mockApi.loginCalls, 0);
  });

  testWidgets('Password confirmation validation and mismatch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    // Switch to Sign up tab
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    // Fill mismatching passwords
    await tester.enterText(
      find.byKey(const Key('auth_name_field')),
      'Test User',
    );
    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'test@xanhsm.vn',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'Password123',
    );
    await tester.enterText(
      find.byKey(const Key('auth_confirm_password_field')),
      'Different456',
    );

    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu xác nhận không trùng khớp'), findsOneWidget);
    expect(mockApi.registerCalls, 0);
  });

  testWidgets('Signup success flows to AccountScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth_name_field')),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'user.a@xanhsm.vn',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'SecurePassword123',
    );
    await tester.enterText(
      find.byKey(const Key('auth_confirm_password_field')),
      'SecurePassword123',
    );

    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản Xanh SM'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('user.a@xanhsm.vn'), findsOneWidget);
    expect(find.byKey(const Key('account_logout_button')), findsOneWidget);
  });

  testWidgets('Login success and Logout flow', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'user.a@xanhsm.vn',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'SecurePassword123',
    );

    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    // Verify account screen shown
    expect(find.text('Tài khoản Xanh SM'), findsOneWidget);
    expect(mockApi.loginCalls, 1);
    expect(mockApi.meCalls, 1);

    // Tap logout
    await tester.tap(find.byKey(const Key('account_logout_button')));
    await tester.pumpAndSettle();

    // Back to auth screen
    expect(find.byKey(const Key('auth_submit_button')), findsOneWidget);
    expect(mockApi.logoutCalls, 1);
  });

  testWidgets('Server error shows banner message', (WidgetTester tester) async {
    mockApi.failLogin = true;
    mockApi.errorMessage = 'Email hoặc mật khẩu không chính xác.';

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'wrong@xanhsm.vn',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'wrongpass',
    );

    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Email hoặc mật khẩu không chính xác.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.isAuthenticated, false);
  });

  testWidgets('Small viewport scrolls cleanly without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    // Switch to Sign up (has more fields)
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth_mode_switch_link')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Scroll down to submit button
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_submit_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keyboard inset on small viewport scrolls cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Scroll until submit button is visible
    await tester.scrollUntilVisible(
      find.byKey(const Key('auth_submit_button')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('auth_submit_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text scale adapts without layout overflow', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('auth_brand_logo')), findsOneWidget);

    // Switch to Sign up with large text
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('auth_name_field')), findsOneWidget);
    expect(
      find.byKey(const Key('auth_confirm_password_field')),
      findsOneWidget,
    );
  });

  testWidgets('Landscape and tablet screens constrain form width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final formRenderBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('auth_submit_button')),
    );
    // Submit button width is constrained (<= 460) rather than stretching full screen width
    expect(formRenderBox.size.width, lessThanOrEqualTo(460.0));
  });

  testWidgets('Reduced motion bypasses decorative animation smoothly', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
    );

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AuthScreen), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('auth_submit_button'))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final motion = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const Key('auth_submit_motion')),
    );
    expect(motion.tween.end, 1);
    expect(motion.duration, Duration.zero);
    await gesture.cancel();
    await tester.pumpAndSettle();

    // Switch tabs with zero-duration animation
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_name_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rapid tab switching preserves form field state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    // Fill email and password in login tab
    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'customer@xanhsm.vn',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'SecretPassword123',
    );

    // Rapidly toggle modes back and forth
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();

    // Verify signup is active and email/password are preserved
    expect(find.byKey(const Key('auth_name_field')), findsOneWidget);
    final emailField = tester.widget<ShadInputFormField>(
      find.byKey(const Key('auth_email_field')),
    );
    final passwordField = tester.widget<ShadInputFormField>(
      find.byKey(const Key('auth_password_field')),
    );
    expect(emailField.controller?.text, 'customer@xanhsm.vn');
    expect(passwordField.controller?.text, 'SecretPassword123');

    // Switch back to login and check preservation
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_name_field')), findsNothing);
    final loginEmailField = tester.widget<ShadInputFormField>(
      find.byKey(const Key('auth_email_field')),
    );
    expect(loginEmailField.controller?.text, 'customer@xanhsm.vn');
  });

  testWidgets(
    'Pending submission disables duplicate submit and tab switching',
    (WidgetTester tester) async {
      final loginCompleter = Completer<AuthResult>();
      mockApi.pendingLoginCompleter = loginCompleter;

      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_email_field')),
        'user.a@xanhsm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('auth_password_field')),
        'SecurePassword123',
      );

      final submitPosition = tester.getCenter(
        find.byKey(const Key('auth_submit_button')),
      );
      final modePosition = tester.getCenter(find.text('Đăng ký'));
      // Submit once -> request becomes pending
      await tester.tapAt(submitPosition);
      await tester.pump();
      expect(controller.isLoading, isTrue);
      expect(mockApi.loginCalls, 1);

      // Attempt duplicate submit while busy
      await tester.tapAt(submitPosition);
      await tester.pump();
      expect(mockApi.loginCalls, 1); // No additional call

      // Attempt tab switch while busy
      await tester.tapAt(modePosition);
      await tester.pump();
      // Form should remain in login mode (auth_name_field not present)
      expect(find.byKey(const Key('auth_name_field')), findsNothing);

      // Complete the pending request
      loginCompleter.complete(
        AuthResult(token: 'mock-token-login', user: mockApi.mockUser),
      );
      await tester.pumpAndSettle();

      // Successfully transitions to AccountScreen
      expect(find.text('Tài khoản Xanh SM'), findsOneWidget);
      expect(controller.isLoading, isFalse);
    },
  );

  testWidgets('3x text scaling adapts without layout breakage', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(
      () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
    );

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('High contrast mode renders opaque surfaces', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(highContrast: true);
    addTearDown(
      () => tester.platformDispatcher.clearAccessibilityFeaturesTestValue(),
    );

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('Mode-switch text link switches auth mode and preserves inputs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'toggle@xanhsm.vn',
    );

    // Tap link beneath form to switch to Sign Up
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_name_field')), findsOneWidget);

    // Enter name in sign up
    await tester.enterText(
      find.byKey(const Key('auth_name_field')),
      'Toggle User',
    );

    // Tap link beneath form to switch back to Login
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_name_field')), findsNothing);

    // Tap link again to switch to Sign Up and check preservation
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth_name_field')), findsOneWidget);
    final nameField = tester.widget<ShadInputFormField>(
      find.byKey(const Key('auth_name_field')),
    );
    expect(nameField.controller?.text, 'Toggle User');
  });

  testWidgets(
    'Single coherent inline feedback displays for validation and API error with no toasts',
    (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();

      // 1. Validation error: inline field feedback, no toast
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập địa chỉ email'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // 2. API error: inline banner feedback, no toast
      mockApi.failLogin = true;
      mockApi.errorMessage = 'Tài khoản không tồn tại.';
      await tester.enterText(
        find.byKey(const Key('auth_email_field')),
        'wrong@xanhsm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('auth_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản không tồn tại.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // 3. Success: navigation to AccountScreen with no duplicate toast
      mockApi.failLogin = false;
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pump();
      expect(find.text('Tài khoản Xanh SM'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('Small viewport with keyboard keeps signup fields reachable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('auth_mode_switch_link')),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();

    for (final key in [
      'auth_name_field',
      'auth_email_field',
      'auth_password_field',
      'auth_confirm_password_field',
      'auth_submit_button',
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(Key(key)),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Intro text and header elements match reference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_brand_logo')), findsOneWidget);
    expect(find.text('Chào mừng đến với GSM Voice'), findsOneWidget);
    expect(
      find.text(
        'Đăng nhập để tiếp tục sử dụng GSM Voice, hoặc tạo tài khoản '
        'mới để bắt đầu quản lý thông tin cá nhân của bạn.',
      ),
      findsOneWidget,
    );

    // Switch to Sign Up and check updated centered intro
    await tester.tap(find.byKey(const Key('auth_mode_switch_link')));
    await tester.pumpAndSettle();
    expect(find.text('Tạo tài khoản GSM Voice'), findsOneWidget);
    expect(
      find.text(
        'Tạo tài khoản mới để bắt đầu trải nghiệm dịch vụ di chuyển thông minh và quản lý thông tin của bạn.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Footer privacy and FAQ links open dedicated InfoScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createTestApp(controller, mockApi));
    await tester.pumpAndSettle();

    // Type some text in email field to verify state preservation
    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'preserved@xanhsm.vn',
    );

    // Verify the legal notice routes to privacy information.
    expect(find.byKey(const Key('auth_legal_notice')), findsOneWidget);
    expect(
      find.textContaining('Bằng việc đăng nhập hoặc tạo tài khoản'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('auth_legal_notice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_privacy_link')));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('info_back_button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('auth_privacy_link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_privacy_link')));
    await tester.pumpAndSettle();

    // Switch to FAQ tab inside InfoScreen
    await tester.tap(find.byKey(const Key('info_tab_faq')));
    await tester.pumpAndSettle();
    expect(find.text('Câu hỏi thường gặp (FAQ)'), findsOneWidget);

    // Pop back to AuthScreen via info_back_button
    expect(find.byKey(const Key('info_back_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('info_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);

    // Verify input text is preserved
    final emailField = tester.widget<ShadInputFormField>(
      find.byKey(const Key('auth_email_field')),
    );
    expect(emailField.controller?.text, 'preserved@xanhsm.vn');

    expect(find.byType(InfoScreen), findsNothing);
  });

  testWidgets(
    'InfoScreen adapts cleanly to narrow viewport and accessibility text scaling',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        ShadApp(
          theme: createXanhSMTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const InfoScreen(initialSection: InfoSection.privacy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InfoScreen), findsOneWidget);
      expect(find.text('Thông tin sử dụng dữ liệu'), findsOneWidget);
      expect(find.byKey(const Key('info_tab_privacy')), findsOneWidget);
      expect(find.byKey(const Key('info_tab_faq')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch tab under high text scaling
      await tester.tap(find.byKey(const Key('info_tab_faq')));
      await tester.pumpAndSettle();
      expect(find.text('Câu hỏi thường gặp (FAQ)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Form fields and submit button use rectangular bordered styling',
    (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(controller, mockApi));
      await tester.pumpAndSettle();

      // Check submit button rectangular shape and border
      final submitButton = tester.widget<ShadButton>(
        find.byKey(const Key('auth_submit_button')),
      );
      final buttonBorder = submitButton.decoration?.border;
      expect(buttonBorder, isNotNull);
      expect(buttonBorder!.radius, BorderRadius.circular(10));
      expect(buttonBorder.top?.color, const Color(0xFF0E938A));

      // Check email field rectangular border
      final shadInput = tester.widget<ShadInput>(
        find.descendant(
          of: find.byKey(const Key('auth_email_field')),
          matching: find.byType(ShadInput),
        ),
      );
      final decoration = ShadTheme.of(
        tester.element(find.byType(ShadInput).first),
      ).inputTheme.decoration?.merge(shadInput.decoration);
      expect(decoration, isNotNull);
      final border = decoration!.border;
      expect(border, isNotNull);
      expect(border!.radius, BorderRadius.circular(10));
      expect(border.top?.color, const Color(0xFFD1DDD9));

      final focusedBorder = decoration.focusedBorder;
      expect(focusedBorder, isNotNull);
      expect(focusedBorder!.radius, BorderRadius.circular(10));
      expect(focusedBorder.top?.color, const Color(0xFF00A39C));

      final errorBorder = decoration.errorBorder;
      expect(errorBorder, isNotNull);
      expect(errorBorder!.radius, BorderRadius.circular(10));
      expect(errorBorder.top?.color, const Color(0xFFEF4444));
    },
  );
}
