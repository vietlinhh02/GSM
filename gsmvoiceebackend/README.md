# GSM Voice Backend (`gsmvoiceebackend`)

Dịch vụ backend Go xác thực tài khoản phục vụ môi trường phát triển cục bộ cho ứng dụng Xanh SM.

## Tính năng & Kiến trúc Phát triển (Development Scope)

- **Tầng cơ sở dữ liệu**:
  - Sử dụng **PostgreSQL** chạy qua Docker Compose với image cố định `postgres:18.6-alpine3.23`.
  - Cổng container được bind an toàn vào loopback `127.0.0.1:5433` để tránh phơi nhiễm thông tin phát triển ra mạng công cộng.
  - Tích hợp driver `github.com/jackc/pgx/v5` (v5.11.0) qua thư viện chuẩn `database/sql`.
  - Tự động khởi tạo bảng `users` và index `idx_users_email_lower` khi khởi động máy chủ.
  - Cơ chế nạp dữ liệu chuyển tiếp từ `data/users.json` (nếu có): kiểm tra hợp lệ toàn bộ bản ghi, nhập theo transaction nguyên tử (atomic), và an toàn khi khởi động lại nhiều lần (`ON CONFLICT DO NOTHING`).
- **Mã hóa mật khẩu**: PBKDF2-HMAC-SHA256 với 600.000 vòng lặp (khuyến nghị OWASP), salt ngẫu nhiên 16 bytes, khóa dẫn xuất 32 bytes, kiểm tra bằng hàm thời gian không đổi `subtle.ConstantTimeCompare`.
- **Lưu trữ dữ liệu**: Volume Docker bền vững `gsmvoicee_postgres_data` mount tại `/var/lib/postgresql`.
- **Quản lý phiên**: Token dạng chuỗi ngẫu nhiên 32 bytes (64 ký tự hex) lưu trữ trong bộ nhớ tạm (in-memory), thời hạn 1 giờ.

## Các Endpoint API

| Phương thức | Đường dẫn | Tiêu đề | Mô tả |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Không | Kiểm tra trạng thái máy chủ (`{"status":"ok"}`) |
| `POST` | `/auth/register` | `Content-Type: application/json` | Đăng ký tài khoản (`name`, `email`, `password`) |
| `POST` | `/auth/login` | `Content-Type: application/json` | Đăng nhập (`email`, `password`) |
| `GET` | `/auth/me` | `Authorization: Bearer <token>` | Lấy thông tin tài khoản đang xác thực |
| `POST` | `/auth/logout` | `Authorization: Bearer <token>` | Đăng xuất và hủy token trong bộ nhớ |

*Lưu ý bảo mật*: Không trả về mật khẩu, chuỗi băm (hash) hay salt trong bất kỳ phản hồi API nào. Giới hạn payload tối đa 16 KB và từ chối các trường JSON không hợp lệ / thừa.

## Cấu hình Biến Môi trường

Sao chép file mẫu `.env.example` thành `.env`:

```bash
cp .env.example .env
```

Các biến môi trường cấu hình:

| Biến | Mặc định | Mô tả |
| :--- | :--- | :--- |
| `APP_ADDR` | `127.0.0.1:8080` | Địa chỉ backend lắng nghe |
| `POSTGRES_HOST` | `127.0.0.1` | Địa chỉ máy chủ PostgreSQL cục bộ |
| `POSTGRES_PORT` | `5433` | Cổng host ánh xạ vào PostgreSQL (tránh xung đột với cổng 5432) |
| `POSTGRES_USER` | `gsmvoicee` | Tên tài khoản database cục bộ |
| `POSTGRES_PASSWORD` | `gsmvoicee_dev_secret` | Mật khẩu database cục bộ |
| `POSTGRES_DB` | `gsmvoicee` | Tên database cục bộ |
| `POSTGRES_SSLMODE` | `disable` | Chế độ SSL cho môi trường phát triển cục bộ |
| `DATABASE_URL` | *(Tùy chọn, để trống)* | Ghi đè toàn bộ chuỗi kết nối PostgreSQL nếu cần |

## Hướng dẫn Khởi chạy Cục bộ (`make dev`)

Khởi động PostgreSQL trong Docker (chờ trạng thái healthy) và chạy backend server:

```bash
# Cách 1: Chạy từ thư mục gsmvoiceebackend
cd gsmvoiceebackend
make dev

# Cách 2: Chạy từ thư mục gốc của dự án
make dev
```

### Quản lý Docker Database

```bash
# Khởi động PostgreSQL và chờ container healthy
make db-up

# Kiểm tra trạng thái container và cổng
make db-status

# Xem logs container PostgreSQL
make db-logs

# Dừng PostgreSQL an toàn (dữ liệu volume được bảo toàn)
make db-down
```

### Địa chỉ kết nối từ Android Emulator
- Android Emulator kết nối tới backend máy chủ host thông qua: `http://10.0.2.2:8080`.

## Lệnh Kiểm tra & Kiểm thử

```bash
# 1. Kiểm tra định dạng và phân tích tĩnh
make lint

# 2. Chạy toàn bộ bài kiểm thử với PostgreSQL cục bộ (-count=1, không dùng cache)
make test

# 3. Chạy riêng bài kiểm thử tích hợp cơ sở dữ liệu
make test-integration
```
