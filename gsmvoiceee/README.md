# GSM Voice App (`gsmvoiceee`)

Ứng dụng Flutter cho giao diện xác thực tài khoản (Đăng ký / Đăng nhập) mang phong cách Xanh SM.

## Tính năng Triển khai

- **Giao diện chuẩn phong cách Xanh SM**:
  - Tông màu xanh ngọc chủ đạo (`#00B1A9`) và xanh đậm (`#0F2634`).
  - Phông chữ chính thức `Public Sans` (Regular, Medium, SemiBold, Bold) được tích hợp trong thư mục assets.
  - Hình ảnh thành phố isometric `background_home_page.webp` và biểu tượng xe `ic_car_service.png`.
- **Luồng Xác thực Người dùng**:
  - Form Đăng ký: Họ và tên, Email, Mật khẩu, Xác nhận mật khẩu.
  - Form Đăng nhập: Email, Mật khẩu.
  - Chuyển đổi tab linh hoạt, nút bật/tắt hiển thị mật khẩu, thông báo lỗi tiếng Việt thân thiện.
  - Trạng thái chờ (loading) vô hiệu hóa bấm gửi trùng lặp (duplicate submission).
  - Ghi nhớ email đăng nhập trên thiết bị khi bật “Lưu tài khoản”; không lưu mật khẩu.
  - Hiệu ứng focus nhẹ cho các ô nhập liệu.
  - Tự động cuộn tránh tràn bàn phím (keyboard overflow) và tuân thủ kích thước chạm >= 48px.
  - Màn hình Tài khoản (`AccountScreen`): Hiển thị thông tin người dùng được tải từ API `/auth/me` và nút Đăng xuất an toàn.
- **Tầng Mạng & Quản lý Phiên**:
  - Sử dụng thư viện chuẩn của Dart: `dart:io` (`HttpClient`) và `dart:convert` mà không cần thư viện ngoài.
  - Cấu hình địa chỉ máy chủ mặc định cho Android Emulator: `http://10.0.2.2:8080` (có thể tùy biến qua `--dart-define=API_BASE_URL=...`).
  - Token được lưu trữ độc quyền trong bộ nhớ tạm (in-memory); đóng ứng dụng và mở lại sẽ yêu cầu đăng nhập mới.
  - Thông tin đăng nhập được xóa khỏi bộ nhớ biểu mẫu ngay khi gửi thành công.
  - Cho phép lưu lượng HTTP không mã hóa (cleartext) riêng cho các bản build debug trên emulator (không mở trong release).

## Lệnh Kiểm tra & Biên dịch

Thực hiện trong thư mục `gsmvoiceee`:

```bash
# 1. Kiểm tra định dạng mã nguồn Dart
dart format --output=none --set-exit-if-changed .

# 2. Phân tích tĩnh (không có cảnh báo hay lỗi)
flutter analyze

# 3. Chạy bộ kiểm thử tự động (Unit & Widget tests)
flutter test

# 4. Biên dịch Android Debug APK (sử dụng OpenJDK 17)
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 flutter build apk --debug

# 5. Khởi chạy ứng dụng kết nối tới backend cục bộ trên Android Emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
