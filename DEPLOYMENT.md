# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Trương Minh Hoàng |
| Mã học viên | 2A202602004 |
| Repo | https://github.com/HTM-0410/K3-Day12-2A202602004-TruongMinhHoang |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://agent-production-589c.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | set thủ công qua `railway variables --set PORT=8000` (Railway CLI với `railway up` không expand `$PORT` trong exec form, nên fix bằng cách bind giá trị tĩnh) |
| `AGENT_API_KEY` | ✅ | set qua `railway variables --set AGENT_API_KEY=...` — KHÔNG nằm trong repo |
| `REDIS_URL` | ✅ | Redis add-on của Railway (`railway add --database redis`) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```powershell
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl.exe -i https://agent-production-589c.up.railway.app/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl.exe -i https://agent-production-589c.up.railway.app/ready

# 3. Không có API key — mong đợi 401
curl.exe -i -X POST https://agent-production-589c.up.railway.app/ask `
  -H "Content-Type: application/json" `
  --data-binary "@body.json"
# (body.json: {"question":"Hello"})

# 4. Có API key — mong đợi 200 kèm câu trả lời
$env:AGENT_API_KEY="<đặt trong shell session của bạn, KHÔNG commit>"
curl.exe -i -X POST https://agent-production-589c.up.railway.app/ask `
  -H "Content-Type: application/json" `
  -H "X-API-Key: $env:AGENT_API_KEY" `
  -H "X-User-Id: sv-test" `
  --data-binary "@body.json"

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for ($i=1; $i -le 15; $i++) {
  $code = (curl.exe -s -o $null -w "%{http_code}" -X POST `
    https://agent-production-589c.up.railway.app/ask `
    -H "Content-Type: application/json" `
    -H "X-API-Key: $env:AGENT_API_KEY" `
    -H "X-User-Id: sv-test" `
    --data-binary "@body.json")
  Write-Host -NoNewline "$code "
}
Write-Host ""
```

## Kết Quả Chạy Thật

**1. `/health`**
```
HTTP/1.1 200 OK
Content-Type: application/json
Server: railway-hikari
x-railway-edge: sin1

{"status":"ok","service":"day12-agent","version":"1.0.0"}
```

**2. `/ready`**
```
HTTP/1.1 200 OK
Content-Type: application/json
Server: railway-hikari
x-railway-edge: sin1

{"status":"ready","redis":true}
```

**3. Không có API key — POST `/ask`**
```
HTTP/1.1 401 Unauthorized
Content-Type: application/json
Server: railway-hikari

{"detail":"invalid or missing API key"}
```

**4. Có API key — POST `/ask`**
```
HTTP/1.1 200 OK
Content-Type: application/json
Server: railway-hikari

{
  "answer": "Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.",
  "user_id": "sv-test",
  "history_length": 0,
  "cost_usd": 2.265e-05,
  "tokens": {"in": 3, "out": 37}
}
```

**5. Rate limit (15 lần liên tiếp, RATE_LIMIT_PER_MINUTE=10)**
```
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```
- 9 request đầu: 200 OK
- Từ request 10 trở đi: 429 `{"detail":"rate limit exceeded"}` (đúng kỳ vọng: 10 req/min)

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/` (chụp bằng dashboard hoặc curl ở trên):

- `screenshots/dashboard.png` — trang quản lý service trên Railway
- `screenshots/health.png` — output `curl /health` (đã có bên trên)

---

## Ghi Chú Kỹ Thuật (Bug Đã Sửa)

Trong lúc deploy, healthcheck fail lần đầu train về "service unavailable".

**Root cause:** `railway.toml` ban đầu có
```toml
startCommand = "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
```
Khi `railway up` đẩy qua CLI, Railway không expand `$PORT` trong exec form —
`uvicorn` nhận đúng literal `"$PORT"` → `--port '$PORT' is not a valid integer` →
container crash loop → `/health` 503 (service unavailable).

**Fix:**
1. Bỏ `startCommand` trong `railway.toml` để dùng `Dockerfile` CMD (dạng `["sh", "-c", "...${PORT:-8000}"]` — shell-expand chuẩn).
2. Set `PORT=8000` qua `railway variables --set PORT=8000` làm giá trị mặc định.

Sau fix, log runtime:
```
INFO:     Started server process [2]
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     100.64.0.2:43529 - "GET /health HTTP/1.1" 200 OK
```

App hiện đang phục vụ 200 OK trên public URL.
