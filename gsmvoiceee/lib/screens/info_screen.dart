import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum InfoSection { privacy, faq }

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, this.initialSection = InfoSection.privacy});

  final InfoSection initialSection;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late final ShadTabsController<InfoSection> _tabsController;

  @override
  void initState() {
    super.initState();
    _tabsController = ShadTabsController(value: widget.initialSection);
  }

  @override
  void dispose() {
    _tabsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FBFA),
      child: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: ListenableBuilder(
                listenable: _tabsController,
                builder: (context, _) => _buildTabs(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2EBE8))),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Quay lại',
            child: ShadIconButton.ghost(
              key: const Key('info_back_button'),
              width: 44,
              height: 44,
              icon: const Icon(
                LucideIcons.arrowLeft,
                size: 20,
                color: Color(0xFF0B2926),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Expanded(
            child: Text(
              'Quyền riêng tư & FAQ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B2926),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['Quyền riêng tư', 'Câu hỏi thường gặp'];
    const style = TextStyle(
      fontFamily: 'PublicSans',
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = ((constraints.maxWidth - 10) / 2 - 26).clamp(
            1.0,
            400.0,
          );
          var tabHeight = 44.0;
          for (final label in labels) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: style),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
            )..layout(maxWidth: labelWidth);
            if (painter.height + 16 > tabHeight) {
              tabHeight = painter.height + 16;
            }
            painter.dispose();
          }
          return ShadTabs<InfoSection>(
            controller: _tabsController,
            gap: 16,
            padding: const EdgeInsets.all(4),
            decoration: ShadDecoration(
              color: const Color(0xFFE8EEEC),
              border: ShadBorder.all(
                radius: BorderRadius.circular(10),
                color: const Color(0xFFD1DDD9),
                width: 1,
                padding: EdgeInsets.zero,
              ),
            ),
            tabs: [
              _buildTab(
                InfoSection.privacy,
                labels[0],
                labelWidth,
                tabHeight,
                style,
              ),
              _buildTab(
                InfoSection.faq,
                labels[1],
                labelWidth,
                tabHeight,
                style,
              ),
            ],
          );
        },
      ),
    );
  }

  ShadTab<InfoSection> _buildTab(
    InfoSection section,
    String label,
    double width,
    double height,
    TextStyle style,
  ) {
    return ShadTab(
      key: Key('info_tab_${section.name}'),
      value: section,
      expandContent: true,
      height: height,
      selectedBackgroundColor: const Color(0xFFFFFFFF),
      selectedForegroundColor: const Color(0xFF007E78),
      foregroundColor: const Color(0xFF53716E),
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: const Color(0x00000000),
          width: 1,
          radius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
        ),
        focusedBorder: ShadBorder.all(
          color: const Color(0xFF00A39C),
          width: 1,
          radius: BorderRadius.circular(8),
          padding: EdgeInsets.zero,
        ),
      ),
      content: section == InfoSection.privacy
          ? _buildPrivacyTab()
          : _buildFaqTab(),
      child: SizedBox(
        width: width,
        child: Text(label, style: style, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      key: const Key('info_privacy_scroll'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(
            icon: LucideIcons.info,
            title: 'Thông tin sử dụng dữ liệu',
            subtitle:
                'Cách ứng dụng GSM Voice tiếp nhận và xử lý dữ liệu tài khoản khi bạn đăng nhập hoặc đăng ký.',
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: '1. Dữ liệu gửi đến máy chủ để xác thực',
            content:
                'Khi đăng ký tài khoản, ứng dụng gửi họ tên, địa chỉ email và '
                'mật khẩu bạn đã nhập đến máy chủ để tạo tài khoản mới. Khi đăng nhập, '
                'email và mật khẩu được gửi đến máy chủ để xác thực thông tin. Sau khi '
                'xác thực thành công, máy chủ phản hồi thông tin tài khoản cơ bản bao '
                'gồm mã định danh, họ tên, email và thời gian tạo tài khoản để hiển '
                'thị trên ứng dụng.',
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: '2. Duy trì phiên đăng nhập',
            content:
                'Phiên đăng nhập được duy trì trong suốt quá trình ứng dụng đang '
                'chạy. Ứng dụng không lưu thông tin phiên đăng nhập lâu dài trên bộ '
                'nhớ thiết bị. Khi bạn đóng ứng dụng hoàn toàn hoặc khởi động lại '
                'thiết bị, phiên làm việc sẽ kết thúc và bạn cần đăng nhập lại ở lần '
                'mở ứng dụng kế tiếp. Nếu chỉ tạm thời chuyển ứng dụng xuống chạy '
                'nền, phiên đăng nhập vẫn tiếp tục duy trì.',
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: '3. Bảo vệ thông tin tại các ô nhập liệu',
            content:
                'Ký tự mật khẩu luôn được che giấu theo mặc định trong ô nhập mật '
                'khẩu. Ngay sau khi đăng nhập hoặc đăng ký thành công, toàn bộ '
                'thông tin tài khoản và mật khẩu vừa điền sẽ được xóa sạch khỏi các ô '
                'nhập trên màn hình.',
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: '4. Kiểm tra dữ liệu và hiển thị phản hồi lỗi',
            content:
                'Trước khi gửi yêu cầu đến máy chủ, ứng dụng kiểm tra độ dài và '
                'định dạng trực tiếp trên màn hình; nếu thông tin chưa hợp lệ, thông '
                'báo sẽ hiển thị ngay dưới ô nhập tương ứng. Nếu máy chủ trả về lỗi '
                'khi xác thực (như tài khoản không tồn tại hoặc sai mật khẩu), thông '
                'báo lỗi sẽ xuất hiện tại khung thông báo ở đầu màn hình để bạn nắm '
                'được và chỉnh sửa.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    return SingleChildScrollView(
      key: const Key('info_faq_scroll'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(
            icon: LucideIcons.circleHelp,
            title: 'Câu hỏi thường gặp (FAQ)',
            subtitle:
                'Giải đáp các câu hỏi phổ biến về đăng nhập, đăng ký và quản lý tài khoản.',
          ),
          const SizedBox(height: 16),
          _buildFaqItem(
            question: '1. Quy định về thông tin khi đăng ký tài khoản?',
            answer:
                '• Họ và tên: Tối đa 100 ký tự.\n'
                '• Email: Đúng định dạng thư điện tử (ví dụ: ten@xanhsm.vn).\n'
                '• Mật khẩu: Độ dài từ 8 đến 128 ký tự.\n'
                '• Xác nhận mật khẩu: Phải trùng khớp hoàn toàn với mật khẩu đã nhập.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            question: '2. Cách chuyển đổi giữa Đăng nhập và Đăng ký?',
            answer:
                'Bấm vào liên kết "Đăng ký" hoặc "Đăng nhập" ở ngay bên dưới nút '
                'bấm. Toàn bộ thông tin bạn đã nhập vào các ô sẽ được giữ nguyên khi '
                'chuyển đổi qua lại giữa hai chế độ.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            question: '3. Khi nào ứng dụng yêu cầu tôi đăng nhập lại?',
            answer:
                'Ứng dụng chỉ duy trì phiên đăng nhập trong thời gian đang hoạt '
                'động và không lưu vĩnh viễn trên thiết bị. Bạn cần đăng nhập lại khi '
                'đã đóng hoàn toàn ứng dụng, khởi động lại thiết bị hoặc bấm "Đăng '
                'xuất". Khi chỉ chuyển ứng dụng xuống chạy nền rồi mở lại, bạn vẫn '
                'tiếp tục sử dụng bình thường.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            question:
                '4. Ứng dụng thông báo lỗi như thế nào nếu điền chưa đúng?',
            answer:
                'Nếu thiếu thông tin hoặc sai định dạng, dòng nhắc chữ đỏ xuất hiện '
                'ngay dưới ô nhập tương ứng. Nếu máy chủ báo lỗi khi xác thực, một '
                'khung cảnh báo màu đỏ sẽ xuất hiện ở phía trên các ô nhập.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            question: '5. Làm cách nào để đăng xuất tài khoản?',
            answer:
                'Sau khi đăng nhập thành công, bạn vào màn hình Tài khoản Xanh SM '
                'và nhấn nút "Đăng xuất" ở cuối trang để kết thúc phiên làm việc hiện '
                'tại.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final titleLineHeight = MediaQuery.textScalerOf(context).scale(24);
    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFE2F4F1),
      radius: BorderRadius.circular(10),
      border: ShadBorder.all(color: const Color(0xFFB5E4DE), width: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: titleLineHeight,
            child: Icon(icon, color: const Color(0xFF007E78), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'PublicSans',
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF1E3A37),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String content}) {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFFFFFFF),
      radius: BorderRadius.circular(10),
      border: ShadBorder.all(color: const Color(0xFFDDE6E4), width: 1.2),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B2926),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          content,
          style: const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 13,
            color: Color(0xFF4A6B67),
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFFFFFFF),
      radius: BorderRadius.circular(10),
      border: ShadBorder.all(color: const Color(0xFFDDE6E4), width: 1.2),
      title: Text(
        question,
        style: const TextStyle(
          fontFamily: 'PublicSans',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B2926),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          answer,
          style: const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 13,
            color: Color(0xFF4A6B67),
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
