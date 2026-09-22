FROM node:22-alpine

WORKDIR /app

# 运行时需要的工具：wget 用于启动时拉取最新 worker.js
RUN apk add --no-cache wget

# 预置当前版本作为本地兜底（启动时若拉取失败仍可运行）
# 注意：server.js 依赖 node_modules（undici/socks）——构建时在镜像内安装，
# 不依赖上下文里的 node_modules（它被 .gitignore 排除，不进构建上下文）。
# worker.js 每次启动从 GitHub raw 拉最新，后续只改 worker.js 无需重建镜像。
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js worker.js ./

# 创建引导器：启动时从 GitHub raw 拉取最新 worker.js
# （单个文件拉取失败时保留镜像内置副本兜底）
RUN printf '%s\n' \
  '#!/bin/sh' \
  'set -e' \
  'URL="https://raw.githubusercontent.com/pingmike2/freebuff2api-wokers/main/worker.js"' \
  'if wget -q -T 20 -O /app/worker.js.tmp "$URL" && [ -s /app/worker.js.tmp ]; then' \
  '  mv /app/worker.js.tmp /app/worker.js' \
  '  echo "[entrypoint] worker.js updated"' \
  'else' \
  '  rm -f /app/worker.js.tmp' \
  '  echo "[entrypoint] fetch failed, keeping bundled worker.js"' \
  'fi' \
  'exec node /app/server.js' \
  > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# credentials 目录挂载点（admin.json 持久化），以非 root 用户运行
RUN mkdir -p /app/credentials && chown -R node:node /app

USER node
EXPOSE 8787

ENTRYPOINT ["/app/entrypoint.sh"]
