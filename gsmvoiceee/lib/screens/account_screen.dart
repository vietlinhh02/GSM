import 'package:flutter/widgets.dart';
import 'package:gsmvoiceee/widgets/screen_transition.dart';
import 'package:gsmvoiceee/state/auth_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    final name = user?.name ?? 'Khách hàng';
    final email = user?.email ?? '';
    final userId = user?.id ?? '';
    final createdAt = user?.createdAt;

    String dateText = 'Chưa xác định';
    if (createdAt != null) {
      final local = createdAt.toLocal();
      dateText =
          '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}/${local.year} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return ScreenTransition(
      child: Container(
        color: const Color(0xFFF3F7F6),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2EBE8), width: 1),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Tài khoản Xanh SM',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF0F2634),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAvatarCard(name, email),
                      const SizedBox(height: 20),
                      _buildInfoSection(userId, dateText),
                      const SizedBox(height: 32),
                      _buildLogoutButton(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(String name, String email) {
    return ShadCard(
      padding: const EdgeInsets.all(20),
      radius: BorderRadius.circular(20),
      backgroundColor: const Color(0xFFFFFFFF),
      border: ShadBorder.all(color: const Color(0xFFE2EBE8), width: 1),
      shadows: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7F5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00B1A9), width: 2),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/ic_car_service.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2634),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ShadBadge(
            backgroundColor: const Color(0xFFE8FDF8),
            foregroundColor: const Color(0xFF00B1A9),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFB2ECE4), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 16,
                  color: Color(0xFF00B1A9),
                ),
                SizedBox(width: 6),
                Text(
                  'Đã xác thực phiên làm việc',
                  style: TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00B1A9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String userId, String dateText) {
    return ShadCard(
      padding: const EdgeInsets.all(18),
      radius: BorderRadius.circular(16),
      backgroundColor: const Color(0xFFFFFFFF),
      border: ShadBorder.all(color: const Color(0xFFE2EBE8), width: 1),
      shadows: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
      child: Column(
        children: [
          _buildInfoRow(
            icon: LucideIcons.idCard,
            label: 'Mã người dùng',
            value: userId.length > 12
                ? '${userId.substring(0, 12)}...'
                : userId,
          ),
          const ShadSeparator.horizontal(
            margin: EdgeInsets.symmetric(vertical: 12),
            color: Color(0xFFF1F5F9),
          ),
          _buildInfoRow(
            icon: LucideIcons.calendar,
            label: 'Thời gian đăng ký',
            value: dateText,
          ),
          const ShadSeparator.horizontal(
            margin: EdgeInsets.symmetric(vertical: 12),
            color: Color(0xFFF1F5F9),
          ),
          _buildInfoRow(
            icon: LucideIcons.shield,
            label: 'Cơ chế phiên',
            value: 'Bộ nhớ tạm (1 giờ)',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00B1A9)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'PublicSans',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F2634),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Đăng xuất tài khoản',
      child: ShadButton.outline(
        key: const Key('account_logout_button'),
        onPressed: () => controller.logout(),
        width: double.infinity,
        height: 50,
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFFDC2626),
        decoration: ShadDecoration(
          border: ShadBorder.all(
            color: const Color(0xFFFCA5A5),
            radius: BorderRadius.circular(12),
            width: 1.0,
          ),
          disableSecondaryBorder: true,
        ),
        leading: const Icon(
          LucideIcons.logOut,
          size: 20,
          color: Color(0xFFDC2626),
        ),
        child: const Text(
          'Đăng xuất',
          style: TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDC2626),
          ),
        ),
      ),
    );
  }
}
