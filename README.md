# GSM Voice Assistant Project

Dự án phát triển ứng dụng di động và dịch vụ backend cho nền tảng Xanh SM.

## Cấu trúc Dự án

- [Backend (`gsmvoiceebackend`)](gsmvoiceebackend/README.md): Dịch vụ xác thực tài khoản viết bằng Go (chỉ dùng thư viện chuẩn, PBKDF2-HMAC-SHA256 600.000 iterations, lưu trữ an toàn `data/users.json`, quản lý phiên in-memory).
- [Ứng dụng di động (`gsmvoiceee`)](gsmvoiceee/README.md): Ứng dụng Flutter với giao diện Đăng ký / Đăng nhập / Màn hình Tài khoản chuẩn nhận diện thương hiệu Xanh SM (phông Public Sans, tài nguyên gốc, kết nối mạng `dart:io`).
- [Thiết kế Phase 3 (`docs/voice-assistant-phase3-design.md`)](docs/voice-assistant-phase3-design.md): Tài liệu đặc tả kiến trúc và thiết kế thử nghiệm prototype Phase 3.
- [Tài nguyên tĩnh (`assets-green-sm-5.11.1/`)](assets-green-sm-5.11.1/README.md): Bộ tài nguyên tĩnh trích xuất gốc từ ứng dụng Xanh SM.

## Trạng thái Triển khai Xác thực (Authentication Milestone)

Hệ thống đã hoàn tất phân hệ đăng ký và đăng nhập:
1. **Backend Go**:
   - `POST /auth/register`: Đăng ký người dùng mới, kiểm tra trùng email, băm mật khẩu bảo mật cao.
   - `POST /auth/login`: Xác thực thông tin đăng nhập, cấp token phiên ngẫu nhiên 32-byte.
   - `GET /auth/me`: Kiểm tra Bearer token và trả về thông tin tài khoản hợp lệ.
   - `POST /auth/logout`: Thu hồi phiên đăng nhập hiện tại.
   - `GET /health`: Kiểm tra sức khỏe dịch vụ.
2. **Ứng dụng Flutter**:
   - Giao diện người dùng tối ưu hóa cho màn hình Android: form nhập liệu, bật/tắt hiển thị mật khẩu, thông báo lỗi tiếng Việt, ngăn gửi trùng lặp khi đang tải.
   - Quản lý phiên trong bộ nhớ: lấy dữ liệu người dùng từ backend làm nguồn tin cậy (`/auth/me`).
   - Sẵn sàng tệp Android Debug APK biên dịch cho môi trường Android Emulator.

## Hướng dẫn Vận hành Cục bộ

### 1. Khởi chạy Backend Go với Docker PostgreSQL
```bash
# Khởi chạy nhanh từ thư mục gốc hoặc gsmvoiceebackend:
make dev
```
*(Lệnh trên sẽ tự động khởi động PostgreSQL container qua Docker Compose, chờ sẵn sàng (healthy), và chạy backend server trên `127.0.0.1:8080`).*

### 2. Khởi chạy Ứng dụng trên Android Emulator
```bash
cd gsmvoiceee
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
*(Lưu ý: Địa chỉ `10.0.2.2` trỏ tới `127.0.0.1` của máy chủ host từ môi trường Android emulator).*
