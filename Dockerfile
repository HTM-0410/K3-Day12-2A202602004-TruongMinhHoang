# �══════════════════════════════════════════════════════════════════
# CP2 — Containerization (multi-stage, production-ready)
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency vào /install ────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ COPY requirements.txt trước → cache còn dùng được khi sửa code
COPY requirements.txt .
# Cài vào /install để bên runtime COPY --from=builder dễ dàng
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: runtime — image cuối, chỉ chứa thứ cần thiết ────────
FROM python:3.11-slim AS runtime

# Không chạy bằng root: lỗ hổng trong code Python ≠ quyền root trên host
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

# Mang KẾT QUẢ cài đặt từ builder sang (không mang compiler)
COPY --from=builder /install /usr/local

# Copy source SAU khi pip install để tận dụng cache
COPY app ./app
COPY utils ./utils

USER appuser

# Cloud (Railway/Render/Cloud Run) tự gán PORT — bind 0.0.0.0 để bên ngoài gọi vào được
ENV PORT=8000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD sh -c "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/health').read()\"" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
