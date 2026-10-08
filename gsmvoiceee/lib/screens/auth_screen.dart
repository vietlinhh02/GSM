import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gsmvoiceee/widgets/screen_transition.dart';
import 'package:gsmvoiceee/screens/info_screen.dart';
import 'package:gsmvoiceee/state/auth_controller.dart';
import 'package:lottie/lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<ShadFormState>();
  final _scrollController = ScrollController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitPressed = false;
  bool _isSignUp = false;
  bool _keyboardOpen = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberAccount = false;
  final _preferences = SharedPreferencesAsync();
  static const _savedEmailKey = 'saved_login_email';
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => _openInfoScreen(context, InfoSection.privacy);
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => _openInfoScreen(context, InfoSection.privacy);

  @override
  void initState() {
    super.initState();
    _restoreSavedAccount();
    for (final node in [
      _nameFocusNode,
      _emailFocusNode,
      _passwordFocusNode,
      _confirmPasswordFocusNode,
    ]) {
      node.addListener(() {
        if (mounted) setState(() {});
        if (node.hasFocus) _scheduleFocusedFieldReveal(node);
      });
    }
  }

  Future<void> _restoreSavedAccount() async {
    final savedEmail = await _preferences.getString(_savedEmailKey);
    if (!mounted || savedEmail == null || savedEmail.isEmpty) return;
    setState(() {
      _emailController.text = savedEmail;
      _rememberAccount = true;
    });
  }

  Future<void> _setRememberAccount(bool value) async {
    setState(() => _rememberAccount = value);
    if (!value) {
      await _preferences.remove(_savedEmailKey);
      return;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      await _preferences.setString(_savedEmailKey, email);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen && !_keyboardOpen) {
      for (final node in [
        _nameFocusNode,
        _emailFocusNode,
        _passwordFocusNode,
        _confirmPasswordFocusNode,
      ]) {
        if (node.hasFocus) _scheduleFocusedFieldReveal(node);
      }
    }
    _keyboardOpen = keyboardOpen;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _scheduleFocusedFieldReveal(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !node.hasFocus ||
          !_keyboardOpen ||
          !_scrollController.hasClients) {
        return;
      }
      final fieldContext = node.context;
      if (fieldContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.12,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _switchMode(bool signUp) {
    if (_isSignUp == signUp || widget.controller.isLoading) return;
    final savedName = _nameController.text;
    final savedEmail = _emailController.text;
    final savedPassword = _passwordController.text;
    final savedConfirm = _confirmPasswordController.text;

    setState(() {
      _isSignUp = signUp;
      widget.controller.clearError();
    });

    _formKey.currentState?.reset();
    _nameController.text = savedName;
    _emailController.text = savedEmail;
    _passwordController.text = savedPassword;
    _confirmPasswordController.text = savedConfirm;
  }

  void _clearCredentials() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _submit() async {
    if (widget.controller.isLoading) return;
    widget.controller.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_isSignUp) {
      if (_rememberAccount) {
        await _preferences.setString(_savedEmailKey, email);
      } else {
        await _preferences.remove(_savedEmailKey);
      }
    }

    bool success = false;
    if (_isSignUp) {
      final name = _nameController.text.trim();
      success = await widget.controller.register(
        name: name,
        email: email,
        password: password,
      );
    } else {
      success = await widget.controller.login(email, password);
    }

    if (success) {
      _clearCredentials();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final isBusy = widget.controller.isLoading;
    final errorMessage = widget.controller.errorMessage;
    final isHighContrast = mq?.highContrast ?? false;

    return ScreenTransition(
      isLoading: isBusy,
      loadingLabel: isBusy
          ? (_isSignUp ? 'Đang tạo tài khoản…' : 'Đang đăng nhập…')
          : 'Đang mở màn hình…',
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/background_home_page.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.34, 0.52, 1],
                  colors: [
                    Color(0x00000000),
                    Color(0x00FFFFFF),
                    Color(0xE6FFFFFF),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: _buildBrandLogo(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: LayoutBuilder(
                          builder: (context, contentConstraints) =>
                              _buildScrollContent(
                                contentConstraints,
                                isBusy,
                                errorMessage,
                                isHighContrast,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollContent(
    BoxConstraints constraints,
    bool isBusy,
    String? errorMessage,
    bool isHighContrast,
  ) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          24,
          keyboardOpen ? 12 : (constraints.maxHeight * 0.24).clamp(88.0, 210.0),
          24,
          16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_isSignUp),
                tween: Tween<double>(begin: _isSignUp ? 0 : 1, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, progress, child) => Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, (1 - progress) * 16),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopIntro(isHighContrast),
                    const SizedBox(height: 10),
                    _buildForm(isBusy, errorMessage, isHighContrast),
                    const SizedBox(height: 8),
                    _buildModeSwitchLink(isBusy, isHighContrast),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: _buildFooterLinks(isHighContrast),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopIntro(bool isHighContrast) {
    final titleColor = isHighContrast
        ? const Color(0xFF003835)
        : const Color(0xFF0B2926);
    final descColor = isHighContrast
        ? const Color(0xFF1E3A37)
        : const Color(0xFF53716E);

    final titleText = _isSignUp
        ? 'Tạo tài khoản GSM Voice'
        : 'Chào mừng đến với GSM Voice';
    final descText = _isSignUp
        ? 'Tạo tài khoản để bắt đầu.'
        : 'Đăng nhập để tiếp tục với GSM Voice.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: descColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandLogo() {
    return Image.asset(
      'assets/images/brand_logo_xanhsm.png',
      key: const Key('auth_brand_logo'),
      width: 148,
      height: 42,
      alignment: Alignment.centerLeft,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'Xanh SM',
        style: TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF00A39C),
        ),
      ),
    );
  }

  Widget _buildForm(bool isBusy, String? errorMessage, bool isHighContrast) {
    return ShadForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorMessage != null) ...[
            _buildErrorBanner(errorMessage),
            const SizedBox(height: 12),
          ],
          if (_isSignUp) ...[
            _buildAnimatedInput(_nameFocusNode, _buildNameField(isBusy)),
            const SizedBox(height: 12),
          ],
          _buildAnimatedInput(_emailFocusNode, _buildEmailField(isBusy)),
          const SizedBox(height: 12),
          _buildAnimatedInput(_passwordFocusNode, _buildPasswordField(isBusy)),
          if (!_isSignUp) ...[
            const SizedBox(height: 8),
            _buildRememberAccount(isBusy),
          ],
          if (_isSignUp) ...[
            const SizedBox(height: 12),
            _buildAnimatedInput(
              _confirmPasswordFocusNode,
              _buildConfirmPasswordField(isBusy),
            ),
            const SizedBox(height: 8),
            _buildPasswordHelper(),
          ],
          const SizedBox(height: 12),
          _buildSubmitButton(isBusy, isHighContrast),
        ],
      ),
    );
  }

  Widget _buildAnimatedInput(FocusNode focusNode, Widget child) {
    final isFocused = focusNode.hasFocus;
    return AnimatedScale(
      scale: isFocused ? 1.008 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: isFocused
              ? const [
                  BoxShadow(
                    color: Color(0x2600A39C),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
    );
  }

  Widget _buildRememberAccount(bool isBusy) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadCheckbox(
        key: const Key('auth_remember_account'),
        value: _rememberAccount,
        enabled: !isBusy,
        onChanged: _setRememberAccount,
        label: const Text(
          'Lưu tài khoản',
          style: TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 14,
            color: Color(0xFF3D5956),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitchLink(bool isBusy, bool isHighContrast) {
    final textColor = isHighContrast
        ? const Color(0xFF1E3A37)
        : const Color(0xFF53716E);
    final linkColor = isHighContrast
        ? const Color(0xFF004D40)
        : const Color(0xFF00A39C);

    final promptText = _isSignUp ? 'Đã có tài khoản? ' : 'Chưa có tài khoản? ';
    final actionText = _isSignUp ? 'Đăng nhập' : 'Đăng ký';

    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          Text(
            promptText,
            style: TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
          Semantics(
            button: true,
            label: _isSignUp
                ? 'Chuyển sang chế độ đăng nhập'
                : 'Chuyển sang chế độ đăng ký',
            child: ShadButton.link(
              key: const Key('auth_mode_switch_link'),
              height: 0,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              onPressed: isBusy ? null : () => _switchMode(!_isSignUp),
              child: Text(
                actionText,
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: linkColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks(bool isHighContrast) {
    final bodyColor = isHighContrast
        ? const Color(0xFF003835)
        : const Color(0xFF53716E);
    final linkColor = isHighContrast
        ? const Color(0xFF004D40)
        : const Color(0xFF008B83);
    final bodyStyle = TextStyle(
      fontFamily: 'PublicSans',
      fontSize: 12,
      height: 1.6,
      color: bodyColor,
    );
    final linkStyle = bodyStyle.copyWith(
      color: linkColor,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      key: const Key('auth_legal_notice'),
      container: true,
      label:
          'Bằng việc đăng nhập, bạn đồng ý với Điều khoản sử dụng và '
          'Chính sách quyền riêng tư của GSM Voice.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Bằng việc đăng nhập, bạn đồng ý với',
              style: bodyStyle,
              textAlign: TextAlign.center,
            ),
            _buildLegalLink(
              key: const Key('auth_terms_link'),
              label: 'Điều khoản sử dụng',
              style: linkStyle,
              recognizer: _termsRecognizer,
            ),
            Text('và', style: bodyStyle),
            _buildLegalLink(
              key: const Key('auth_privacy_link'),
              label: 'Chính sách quyền riêng tư',
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
            Text('của GSM Voice.', style: bodyStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalLink({
    required Key key,
    required String label,
    required TextStyle style,
    required TapGestureRecognizer recognizer,
  }) {
    return GestureDetector(
      key: key,
      onTap: recognizer.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(label, style: style),
      ),
    );
  }

  void _openInfoScreen(BuildContext context, InfoSection section) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            InfoScreen(initialSection: section),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildPasswordHelper() {
    return const Padding(
      padding: EdgeInsets.only(left: 14, top: 2),
      child: Text(
        'Mật khẩu cần ít nhất 8 ký tự.',
        style: TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 12,
          color: Color(0xFF53716E),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return ShadAlert.destructive(
      key: const Key('auth_error_banner'),
      icon: const Icon(
        LucideIcons.circleAlert,
        color: Color(0xFFDC2626),
        size: 18,
      ),
      decoration: ShadDecoration(
        color: const Color(0xFFFEF2F2),
        border: ShadBorder.all(
          color: const Color(0xFFFECACA),
          radius: BorderRadius.circular(10),
          width: 1.0,
        ),
      ),
      description: Text(
        message,
        style: const TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 13,
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildNameField(bool isBusy) {
    return ShadInputFormField(
      id: 'name',
      key: const Key('auth_name_field'),
      controller: _nameController,
      focusNode: _nameFocusNode,
      enabled: !isBusy,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      placeholder: const Text('Nguyễn Văn A'),
      leading: const SizedBox(
        width: 20,
        height: 36,
        child: Icon(LucideIcons.user, size: 20, color: Color(0xFF00A39C)),
      ),
      validator: (value) {
        if (value.trim().isEmpty) {
          return 'Vui lòng nhập họ và tên';
        }
        if (value.trim().length > 100) {
          return 'Họ tên không được vượt quá 100 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(bool isBusy) {
    return ShadInputFormField(
      id: 'email',
      key: const Key('auth_email_field'),
      controller: _emailController,
      focusNode: _emailFocusNode,
      enabled: !isBusy,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      placeholder: const Text('ten@xanhsm.vn'),
      leading: const SizedBox(
        width: 20,
        height: 36,
        child: Icon(LucideIcons.mail, size: 20, color: Color(0xFF00A39C)),
      ),
      validator: (value) {
        if (value.trim().isEmpty) {
          return 'Vui lòng nhập địa chỉ email';
        }
        final email = value.trim();
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(email)) {
          return 'Email không hợp lệ';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isBusy) {
    return ShadInputFormField(
      id: 'password',
      key: const Key('auth_password_field'),
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      enabled: !isBusy,
      obscureText: _obscurePassword,
      textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) {
        if (!_isSignUp && !isBusy) _submit();
      },
      autofillHints: _isSignUp
          ? const [AutofillHints.newPassword]
          : const [AutofillHints.password],
      placeholder: const Text('Tối thiểu 8 ký tự'),
      leading: const SizedBox(
        width: 20,
        height: 36,
        child: Icon(LucideIcons.lock, size: 20, color: Color(0xFF00A39C)),
      ),
      trailing: _buildPasswordSuffix(),
      validator: (value) {
        if (value.isEmpty) {
          return 'Vui lòng nhập mật khẩu';
        }
        if (value.length < 8) {
          return 'Mật khẩu phải có ít nhất 8 ký tự';
        }
        if (value.length > 128) {
          return 'Mật khẩu không được vượt quá 128 ký tự';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordSuffix() {
    return Semantics(
      label: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      button: true,
      child: ShadIconButton.ghost(
        key: const Key('auth_password_toggle_button'),
        width: 36,
        height: 36,
        padding: EdgeInsets.zero,
        decoration: const ShadDecoration(
          border: ShadBorder.none,
          focusedBorder: ShadBorder.none,
          disableSecondaryBorder: true,
        ),
        icon: Icon(
          _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 18,
          color: const Color(0xFF4D6D6A),
        ),
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
    );
  }

  Widget _buildConfirmPasswordField(bool isBusy) {
    return ShadInputFormField(
      id: 'confirmPassword',
      key: const Key('auth_confirm_password_field'),
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocusNode,
      enabled: !isBusy,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (_isSignUp && !isBusy) _submit();
      },
      autofillHints: const [AutofillHints.password],
      placeholder: const Text('Nhập lại mật khẩu'),
      leading: const SizedBox(
        width: 20,
        height: 36,
        child: Icon(LucideIcons.lock, size: 20, color: Color(0xFF00A39C)),
      ),
      trailing: _buildConfirmPasswordSuffix(),
      validator: (value) {
        if (value.isEmpty) {
          return 'Vui lòng xác nhận lại mật khẩu';
        }
        if (value != _passwordController.text) {
          return 'Mật khẩu xác nhận không trùng khớp';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordSuffix() {
    return Semantics(
      label: _obscureConfirmPassword ? 'Hiện xác nhận' : 'Ẩn xác nhận',
      button: true,
      child: ShadIconButton.ghost(
        key: const Key('auth_confirm_password_toggle_button'),
        width: 36,
        height: 36,
        padding: EdgeInsets.zero,
        decoration: const ShadDecoration(
          border: ShadBorder.none,
          focusedBorder: ShadBorder.none,
          disableSecondaryBorder: true,
        ),
        icon: Icon(
          _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 18,
          color: const Color(0xFF4D6D6A),
        ),
        onPressed: () {
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
        },
      ),
    );
  }

  Widget _buildSubmitButton(bool isBusy, bool isHighContrast) {
    final title = _isSignUp ? 'Đăng ký tài khoản' : 'Đăng nhập';
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: const Key('auth_submit_motion'),
      tween: Tween<double>(
        begin: 1,
        end: !reduceMotion && !isBusy && _submitPressed ? 0.96 : 1,
      ),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Semantics(
        button: true,
        label: title,
        child: _buildSubmitControl(isBusy, isHighContrast, title),
      ),
    );
  }

  Widget _buildSubmitControl(bool isBusy, bool isHighContrast, String title) {
    final buttonBg = isHighContrast
        ? const Color(0xFF004D40)
        : const Color(0xFF008B83);
    const textColor = Color(0xFFFFFFFF);
    final borderColor = isHighContrast
        ? const Color(0xFF00241E)
        : const Color(0xFF0E938A);
    return ShadButton(
      key: const Key('auth_submit_button'),
      enabled: !isBusy,
      onPressed: _submit,
      onTapDown: (_) => setState(() => _submitPressed = true),
      onTapUp: (_) => setState(() => _submitPressed = false),
      onTapCancel: () => setState(() => _submitPressed = false),
      width: double.infinity,
      height: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      expands: true,
      backgroundColor: buttonBg,
      foregroundColor: textColor,
      hoverBackgroundColor: isHighContrast
          ? const Color(0xFF003D33)
          : const Color(0xFF00766F),
      pressedBackgroundColor: isHighContrast
          ? const Color(0xFF002E27)
          : const Color(0xFF00645D),
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: borderColor,
          width: 1,
          radius: BorderRadius.circular(10),
          padding: EdgeInsets.zero,
        ),
        disableSecondaryBorder: true,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Center(child: _buildSubmitChild(isBusy, title, isHighContrast)),
      ),
    );
  }

  Widget _buildSubmitChild(bool isBusy, String title, bool isHighContrast) {
    const textColor = Color(0xFFFFFFFF);

    if (!isBusy) {
      return Text(
        title,
        style: TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      );
    }
    return _buildBusySubmitChild(textColor);
  }

  Widget _buildBusySubmitChild(Color textColor) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return Semantics(
        liveRegion: true,
        label: 'Đang xử lý...',
        child: Text(
          'Đang xử lý...',
          style: TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      );
    }

    return SizedBox(
      height: 24,
      child: Center(
        child: Lottie.asset(
          'assets/animations/lottie_dots_loading.json',
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 18,
            height: 18,
            child: Icon(LucideIcons.loader2, size: 18, color: textColor),
          ),
        ),
      ),
    );
  }
}
