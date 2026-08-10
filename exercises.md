# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder bằng câu trả lời thật của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trương Minh Hoàng    Mã học viên: 2A202602004

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Nếu để giá trị mặc định là `"changeme"`, app sẽ khởi động bình thường dù
> người vận hành quên set biến `AGENT_API_KEY`. Lúc này API key thật sự trong
> production chính là `"changeme"` — bất kỳ ai biết endpoint đều có thể gọi
> thoải mái, tiêu tốn credit, đọc lịch sử của người khác. Với fail fast,
> app không start được nếu thiếu key, buộc người vận hành phải cung cấp giá
> trị thật ngay từ đầu, trước khi container lên production. Không ai có thể
> "vô tình" deploy mà không có bảo mật.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thực tế thu được:
>
> ```
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T03:40:27.164647+00:00",
>  "user_id": "test-user", "tokens_in": 2, "tokens_out": 34, "cost_usd": 2.07e-05}
> ```
>
> **Hai việc `print()` không làm được:**
>
> 1. **Parse tự động bằng script** — Log JSON có cấu trúc chuẩn nên có thể
>    dùng `jq`, `python -c "import json..."`, hoặc bất kỳ công cụ log nào
>    (Datadog, Grafana, Loki...) để đọc, lọc, thống kê. Ví dụ lọc tất cả
>    request có `cost_usd > 0.01`, hoặc tổng chi phí theo user. Với
>    `print()` thuần túy thì phải regex thủ công rất dễ sai.
>
> 2. **Tách đúng trường dữ liệu** — JSON log có `timestamp`, `user_id`,
>    `tokens_in`, `tokens_out`, `cost_usd` là các trường riêng biệt, không
>    phải một chuỗi văn bản. Có thể truy vấn chính xác con số tokens hay
>    chi phí của bất kỳ request nào. `print("đã trả lời xong")` không cho
>    biết user nào, tốn bao nhiêu token, mất bao lâu.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
    docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.01 GB |
| Multi-stage | 63.7 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Bản multi-stage chỉ nặng **63.7 MB** so với **~1 GB** của bản 1 stage —
> nhẹ hơn khoảng **16 lần**. Phần chênh lệch gồm: Python interpreter đầy đủ
> (không cần trong production), pip cache, các file wheel tạm thời, compiler
> C nếu có dependency compiled, và toàn bộ build artifacts không cần khi chạy.
> Multi-stage dùng stage `builder` để cài vào `/install`, rồi chỉ COPY
> kết quả (thư viện đã cài, không kèm compiler hay cache) sang stage runtime
> `python:3.11-slim` — vốn đã rất nhẹ. Ngoài ra, `python:3.11-slim` không
> chứa documentation, locale data, và các tool không cần thiết.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Dockerfile hiện tại có thứ tự:
>
> 1. `COPY requirements.txt .`
> 2. `RUN pip install --prefix=/install`
> 3. `COPY app ./app` / `COPY utils ./utils`
>
> Khi sửa 1 ký tự trong `app/main.py` (ví dụ thêm dấu chấm phẩy):
>
> - Layer 1 (`COPY requirements.txt`) → **CACHED** (requirements.txt không đổi)
> - Layer 2 (`RUN pip install`) → **CACHED** (requirements.txt không đổi)
> - Layer 3 (`COPY app ./app`) → **PHẢI CHẠY LẠI** (file source thay đổi)
>
> `pip install` không phải chạy lại vì đã cached — tiết kiệm ~30 giây mỗi
> lần sửa code. Nếu đặt `COPY . .` lên **trước** `RUN pip install`, thì mỗi
> lần sửa bất kỳ file nào (kể cả `app/main.py`), Docker sẽ hiểu layer
> `COPY` đã thay đổi → **toàn bộ layer sau nó cũng phải chạy lại**, bao gồm
> `RUN pip install`. Build lúc đó mất thời gian gấp nhiều lần.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện:
>
> 1. Code Python có lỗ hổng cho phép RCE (Remote Code Execution) — ví dụ
>    `eval()` dữ liệu từ input không sanitize, hoặc deserialization attack.
> 2. Kẻ tấn công khai thác lỗ hổng này, gửi payload để chạy lệnh shell.
> 3. Vì container chạy bằng **root**, lệnh thực thi với UID 0.
> 4. Từ bên trong container, kẻ tấn công có thể mount filesystem của host
>    (`mount /dev/sda /mnt`) vì có quyền root.
> 5. Ghi vào `/etc/passwd` hoặc `/root/.ssh/authorized_keys` trên host,
>    mở cửa backdoor vĩnh viễn.
>
> Lệnh `USER appuser` (trong Dockerfile) cắt đứt ở **bước 3**: dù lỗ hổng RCE
> bị khai thác thành công, lệnh shell chạy với quyền của `appuser` (UID
> 10001, không phải root), không thể mount thiết bị hay ghi vào file hệ
> thống host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request** trong 2 giây.
>
> Cách đạt được: Giả sử cửa sổ đếm theo phút đồng hồ, reset lúc giây 00 mỗi
> phút. User gửi 10 request vào lúc **phút X, giây 59** (dùng hết hạn mức
> phút X). Chờ 1 giây, sang **phút X+1, giây 00** — hạn mức reset, user lại
> gửi được 10 request tiếp. Tổng: 10 + 10 = 20 request trong khoảng
> giây 59 → giây 01 (tổng cộng ~2 giây).
>
> Sliding window 60 giây ngăn chặn điều này vì mỗi request chỉ được tính
> trong 60 giây kể từ lúc nó được gửi — user không thể "lướt" qua ranh giới
> phút để lấy hạn mức mới.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> **Khác nhau:** Rate limit giới hạn **số lượng request** mỗi phút, không quan
> tâm câu hỏi dài ngắn. Cost guard giới hạn **chi phí thực tế** phát sinh khi
> gọi API bên ngoài.
>
> **Rate limit cho qua, cost guard chặn:** Một user hỏi 10 câu rất dài,
> mỗi câu tốn 5000 token (rất nhiều context). 10 request trong 1 phút vẫn nằm
> trong rate limit, nhưng tổng chi phí đã vượt ngân sách $10/tháng → cost guard
> trả 402.
>
> **Cost guard cho qua, rate limit chặn:** Một user hỏi rất nhiều câu hỏi
> ngắn, mỗi câu chỉ tốn vài trăm token. Chi phí mỗi request rất nhỏ, ngân sách
> còn dồi — nhưng user gửi 50 request trong 1 phút (vượt rate limit 10/phút)
> → rate limit trả 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> **Thứ tự sự kiện khi Redis chết 30 giân:**
>
> 1. Tà 0: Redis mất kết nối.
> 2. Tà 1: Kubernetes/load balancer gọi `/health` (đã gộp với kiểm tra Redis).
>    Health trả **503** → Kubernetes hiểu container không healthy.
> 3. Tà 2-29: Load balancer **ngừng gửi traffic** đến tất cả 3 container
>    (vì health trả 503 hết).
> 4. Tà 30: Redis khôi phục kết nối.
> 5. Tà 31: Health trả 200 trở lại → Kubernetes nhận biết service đã sống.
> 6. Tà 32+: Load balancer bắt đầu điều phối lại traffic.
>
> **Hậu quả:** Trong suốt 30 giây Redis chết, **toàn bộ 3 container đều bị
> loại khỏi traffic** dù bản thân ứng dụng vẫn chạy tốt. Nếu tách `/health`
> (không kiểm tra Redis) ra khỏi `/ready` (kiểm tra Redis), thì trong 30
> giây đó: health vẫn trả 200 (Kubernetes vẫn giữ container), nhưng ready
> trả 503 (không nhận request mới). Traffic không bị gián đoạn hoàn toàn,
> và ngay khi Redis hồi, service tiếp tục nhận request không miss.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis làm backend: `history_length` tăng đều đặn theo mỗi lần gọi
> `/ask` (0 → 1 → 2 → 3...) vì tất cả 3 container cùng kết nối đến một Redis
> duy nhất. Dù request nào đi đến container nào, lịch sử đều được đọc/ghi
> vào cùng một chỗ.
>
> Nếu dùng `dict` Python trong bộ nhớ mỗi container: `history_length` sẽ
> **không nhất quán** giữa các lần gọi, tùy thuộc container nào nhận request.
> Request 1 đi container A → history_length = 1. Request 2 đi container B →
> history_length = 1 (container B chưa có lịch sử). Request 3 đi container A →
> history_length = 2. Request 4 đi container C → history_length = 1. User sẽ
> thấy lịch sử "nhảy cóc" hoặc bị reset, trải nghiệm rất kém.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** Health check timeout trên Railway — service trả 200 OK nhưng
> Railway vẫn báo "Deployment failed — Health check timed out".
>
> **Nguyên nhân:** Tôi đặt `HEALTHCHECK` trong Dockerfile nhưng Railway không
> chờ đủ thời gian cho cold start của free tier. Cloud free tier (Cold Start)
> cần 20-40 giây lần đầu khởi động, nhưng Railway health check mặc định có
> timeout ngắn hơn. Cộng thêm việc chưa set đúng `PORT` environment variable
> trên Railway → uvicorn bind sai cổng, health check gọi nhưng trả 404.
>
> **Cách tìm ra:** Tôi mở tab "Deployments" trên Railway dashboard, xem log
> của deployment failed. Log cho thấy health check endpoint được gọi nhưng
> không nhận phản hồi đúng. Kiểm tra `railway.toml` và biến `PORT` trong
> dashboard → thấy Railway tự set `PORT=8000` nhưng app cần bind đúng biến
> này.
>
> **Sửa:** Đảm bảo Dockerfile đọc `${PORT}` từ biến môi trường
> (`CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`),
> đồng thời set health check timeout dài hơn trong Railway Nixpacks config.
> Sau khi sửa, health check trả 200 và deployment thành công.
