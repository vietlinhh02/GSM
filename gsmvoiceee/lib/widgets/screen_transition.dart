import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Keeps the screen visible while showing progress for real asynchronous work.
class ScreenTransition extends StatefulWidget {
  const ScreenTransition({
    super.key,
    required this.child,
    this.isLoading = false,
    this.loadingLabel = 'Đang mở màn hình…',
  });

  final Widget child;
  final bool isLoading;
  final String loadingLabel;

  @override
  State<ScreenTransition> createState() => _ScreenTransitionState();
}

class _ScreenTransitionState extends State<ScreenTransition> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(ignoring: widget.isLoading, child: widget.child),
        if (widget.isLoading)
          const ModalBarrier(color: Color(0x66000000), dismissible: false),
        if (widget.isLoading) IgnorePointer(child: _buildLoading()),
      ],
    );
  }

  Widget _buildLoading() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: Semantics(
            key: const Key('screen_loading'),
            liveRegion: true,
            label: widget.loadingLabel,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 248),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0B2926),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!reduceMotion)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: Lottie.asset(
                          'assets/animations/lottie_dots_loading.json',
                          repeat: true,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      const SizedBox(width: 34, height: 34),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.loadingLabel,
                        style: const TextStyle(
                          fontFamily: 'PublicSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0B2926),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
