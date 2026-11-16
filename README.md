# Repo

Không gian làm việc hợp nhất chứa hai dự án con (submodule):

- **folderscaner** — Hệ thống đồng bộ và quản lý dữ liệu thư mục qua SMB/UNC (FastAPI + React)
- **propack** — Ứ dụng web quản lý dự án và tạo mã bản vẽ kỹ thuật (Flask + SQLite)

Ngoài ra còn có tiện ích **chrome-devtools-mcp** (Chrome DevTools MCP server).

## Cấu trúc thư mục

```
Repo/
├── folderscaner/           # submodule: hệ thống quét thư mục SMB
├── propack/                # submodule: quản lý dự án web (cổng 8001)
├── chrome-devtools-mcp/    # submodule: Chrome DevTools MCP server
├── Start_Pro_Scanner.py    # Khởi chạy cả Propack và Folder Scanner cùng lúc
├── Start_Pro_Scanner.bat   # Phiên bản batch Windows
├── Start_Pro_Scanner_Run_Ngam.bat  # Chạy ẩn (không hiện cửa sổ console)
├── Start_Pro_Scanner_Hidden.vbs    # Wrapper chạy ẩn cho batch
├── docker-compose.yml      # Chạy toàn bộ dự án bằng Docker
├── .env.example            # Mẫu biến môi trường
├── README-DOCKER.md        # Hướng dẫn chạy bằng Docker
├── .gitignore
└── .gitmodules
```

## Cách chạy nhanh (không dùng Docker)

### Yêu cầu
- Python 3.10+
- Node.js 20+ (dùng để build frontend của folderscaner)
- Git

### Bước 1: Clone repo kèm submodule

```bash
git clone --recurse-submodules https://github.com/tukelly20-coder/Repo.git
cd Repo
```

### Bước 2: Cài dependencies cho folderscaner

```bash
cd folderscaner
python -m venv .venv
.venv\Scripts\activate
pip install -r backend\requirements.txt

cd frontend
npm install
npm run build
cd ..
cd ..
```

### Bước 3: Cài dependencies cho propack

```bash
cd propack
pip install -r tools\open\requirements.txt
cd ..
```

### Bước 4: Cấu hình môi trường

```bash
copy .env.example .env
```

Mở `.env` và sửa `SMB_ROOT` thành đường dẫn thư mục chia sẻ mạng thực tế.

### Bước 5: Chạy

```bash
python Start_Pro_Scanner.py
```

Sau khi chạy:
- **Propack VP:** http://localhost:8001
- **Folder Scanner UI:** http://localhost:8001/scanner/

## Cách chạy bằng Docker (khuyên dùng, không cần cài Python/Node.js)

Xem chi tiết tại [README-DOCKER.md](README-DOCKER.md).

```bash
copy .env.example .env
# sửa SMB_ROOT trong .env nếu cần
docker compose up -d --build
```

- **Propack:** http://localhost:8001
- **Scanner UI:** http://localhost:8002

## Mô tả hai submodule

### folderscaner
Giám sát tự động thư mục chia sẻ mạng SMB/UNC, đồng bộ hai chiều giữa ổ đĩa và giao diện Web kiểu Excel, ghi lịch sử sự kiện, cập nhật real-time qua WebSocket.
- Backend: Python FastAPI, SQLAlchemy, smbprotocol
- Frontend: React 18, TypeScript, Vite, ag-Grid

### propack
Ứ dụng web quản lý dự án, thông báo công việc Sales↔Kỹ thuật, tạo mã bản vẽ, quản lý người dùng, PropackAI tra cứu.
- Backend: Python Flask, SQLite
- Frontend: HTML5, CSS3, JavaScript (jQuery, Bootstrap 5)
- Port mặc định: 8001

## License

MIT (tham khảo README trong từng submodule để biết chi tiết).
