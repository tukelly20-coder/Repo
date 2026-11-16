# Chạy toàn bộ dự án Repo bằng Docker

Docker giúp bạn **không cần cài Python, Node.js, venv, npm** trên máy mới. Chỉ cần cài Docker Desktop, clone repo và chạy một lệnh.

## 1. Yêu cầu

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) hoặc Docker Engine (Linux)
- Git

## 2. Clone repo

```bash
git clone --recurse-submodules https://github.com/tukelly20-coder/Repo.git
cd Repo
```

Lưu ý: `--recurse-submodules` để tải kèm hai submodule `folderscaner` và `propack`.

## 3. Tạo file biến môi trường

```bash
copy .env.example .env
```

Mở `.env` và sửa những quan trọng:

| Biến | Mô tả | Ví dụ |
|------|-------|-------|
| `SMB_ROOT` | Thư mục chia sẻ mạng SMB/UNC | `\\SERVER\THU_MUC` hoặc `./folderscaner/test_smb_root` |
| `SCAN_INTERVAL` | Chu kỳ quét thư mục (giây) | `10` |
| `POSTGRES_USER` | Tên user DB | `folder_user` |
| `POSTGRES_PASSWORD` | Mật khẩu DB | `folder_pass` |
| `POSTGRES_DB` | Tên database | `folder_sync` |

Nếu thư mục SMB yêu cầu đăng nhập, điền `SMB_USERNAME`, `SMB_PASSWORD`, `SMB_DOMAIN`.

## 4. Build và chạy

```bash
docker compose up -d --build
```

Docker sẽ tự build và chạy 5 container:

| Container | Mô tả | Truy cập |
|-----------|-------|----------|
| `propack-server` | Quản lý dự án, mã bản vẽ, thông báo | `http://localhost:8001` |
| `scanner-frontend` | Giao diện web quét thư mục (React + Nginx) | `http://localhost:8002` |
| `scanner-backend` | API FastAPI, quét SMB, WebSocket | nội bộ (cổng 18001) |
| `scanner-db` | PostgreSQL lưu dữ liệu thư mục | `localhost:5432` |

## 5. Xem log và quản lý

```bash
# Xem log tất cả container
docker compose logs -f

# Xem log một container cụ thể
docker compose logs -f propack-server
docker compose logs -f scanner-backend

# Xem trạng thái container
docker compose ps

# Tắt tất cả container
docker compose down

# Dừng và xóa volume (xóa sạch dữ liệu)
docker compose down -v
```

## 6. Truy cập ứng dụng

- **Propack VP (quản lý dự án):** http://localhost:8001
- **Folder Scanner (quét thư mục SMB):** http://localhost:8002

Máy khác trong cùng mạng LAN có thể truy cập qua địa chỉ IP của máy chủ:
- `http://<IP-MAY-CHU>:8001` — Propack
- `http://<IP-MAY-CHU>:8002` — Scanner

## 7. Lưu dữ liệu

Dữ liệu được lưu trong Docker volume, không bị mất khi container khởi động lại:

- `propack-db`, `propack-used-codes`, `propack-sessions`, ... (dữ liệu Propack)
- `scanner-data`, `scanner-exports`, `postgres_data` (dữ liệu Scanner)

Nếu muốn xóa sạch và bắt đầu lại từ đầu:

```bash
docker compose down -v
```

## 8. Cách khác: chạy từng phần riêng lẻ

Nếu chỉ muốn chạy **Propack**:

```bash
cd propack
docker compose up -d
```

Nếu chỉ muốn chạy **Folder Scanner**:

```bash
cd folderscaner
docker compose up -d
```

## 9. Khắc phục sự cố

- **Lỗi không kết nối Docker API:** Thêm user vào group docker (`sudo usermod -aG docker $USER`) hoặc chạy với `sudo`.
- **Lỗi mount SMB_ROOT:** Đường dẫn UNC Windows (`\\SERVER\SHARE`) có thể không mount được trực tiếp vào Docker container. Hãy dùng thư mục cục bộ (`./folderscaner/test_smb_root`) để thử, hoặc chia sẻ thư mục qua Docker Desktop settings.
- **Port đã được sử dụng:** Nếu cổng 8001 hoặc 8002 đã có dịch vụ khác, sửa port trong `docker-compose.yml` cấp gốc.
