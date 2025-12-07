# ===============================
# Giai đoạn 1: Build (TypeScript → JavaScript)
# ===============================
FROM node:20-slim AS builder

WORKDIR /usr/src/app

# Sao chép file cấu hình
COPY package*.json ./

# Cài dependencies (bao gồm dev để build)
RUN npm install

# Sao chép toàn bộ source code
COPY . .

# *** FIX LỖI: Cấp quyền thực thi cho tsc và các file nguồn ***
RUN chmod -R 755 .

# Biên dịch TypeScript sang JavaScript
RUN npm run build


# ===============================
# Giai đoạn 2: Runtime (Chạy code đã build)
# ===============================
FROM node:20-slim

WORKDIR /usr/src/app

# Chỉ copy thư mục đã build và package.json
COPY --from=builder /usr/src/app/lib ./lib
COPY package*.json ./

# Cài đặt dependencies runtime (loại bỏ dev)
RUN npm install --omit=dev

# Cloud Run bắt buộc dùng PORT từ biến môi trường
ENV PORT=8080

EXPOSE 8080

CMD ["npm", "start"]
