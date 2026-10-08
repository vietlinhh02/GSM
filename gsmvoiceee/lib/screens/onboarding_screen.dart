import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    (
      title: 'Di chuyển xanh, sống tiện nghi',
      description:
          'Khám phá trải nghiệm di chuyển hiện đại cùng hệ sinh thái Xanh SM.',
    ),
    (
      title: 'Mọi hành trình trong tầm tay',
      description:
          'Quản lý thông tin và theo dõi các dịch vụ của bạn thật dễ dàng.',
    ),
    (
      title: 'Bắt đầu cùng GSM Voice',
      description:
          'Đăng nhập hoặc tạo tài khoản để tiếp tục trải nghiệm dịch vụ.',
    ),
  ];

  static const _backgroundAlignments = [
    Alignment.topCenter,
    Alignment.center,
    Alignment.bottomCenter,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_page == _pages.length - 1) {
      widget.onFinish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: SizedBox.expand(
              key: ValueKey(_page),
              child: Image.asset(
                'assets/images/background_home_page.webp',
                fit: BoxFit.cover,
                alignment: _backgroundAlignments[_page],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.48, 0.68, 1],
                colors: [
                  Color(0x18000000),
                  Color(0x16FFFFFF),
                  Color(0xF2FFFFFF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 24,
                  child: Image.asset(
                    'assets/images/brand_logo_xanhsm.png',
                    key: const Key('onboarding_brand_logo'),
                    width: 148,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 12,
                  child: ShadButton.ghost(
                    key: const Key('onboarding_skip_button'),
                    onPressed: widget.onFinish,
                    child: const Text('Bỏ qua'),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 54),
                    Expanded(
                      child: PageView.builder(
                        key: const Key('onboarding_pages'),
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (pageIndex) =>
                            setState(() => _page = pageIndex),
                        itemBuilder: (context, index) {
                          final item = _pages[index];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final imageSize = (constraints.maxHeight * 0.30)
                                    .clamp(112.0, 188.0);
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: constraints.maxHeight * 0.12,
                                    ),
                                    Image.asset(
                                      'assets/images/ic_car_service.png',
                                      width: imageSize * 0.78,
                                      height: imageSize * 0.78,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(height: imageSize * 0.22),
                                    Text(
                                      item.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'PublicSans',
                                        fontSize: 23,
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0B2926),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.description,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'PublicSans',
                                        fontSize: 15,
                                        height: 1.5,
                                        color: Color(0xFF53716E),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _pages.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: index == _page ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: index == _page
                                      ? const Color(0xFF00A39C)
                                      : const Color(0xFFB8C9C6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ShadButton(
                            key: const Key('onboarding_continue_button'),
                            width: double.infinity,
                            height: 52,
                            onPressed: _continue,
                            child: Text(
                              _page == _pages.length - 1
                                  ? 'Vào trang đăng nhập'
                                  : 'Tiếp tục',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
