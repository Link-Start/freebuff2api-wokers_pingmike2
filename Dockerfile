FROM node:20-alpine

WORKDIR /app

# 运行时需要的工具：wget 用于启动时拉取最新 worker.js
RUN apk add --no-cache wget

# 预置当前版本作为本地兜底（启动时若拉取失败仍可运行）
# 注意：server.js 依赖 node_modules（undici/socks），必须一并拷贝；
# worker.js 每次启动从 GitHub raw 拉最新，但 server.js / node_modules 以镜像内为准。
# 以后只改 worker.js：无需重新构建镜像，重启容器即生效（entrypoint 自动拉取）。
# 改 server.js 或依赖：需要重新构建镜像（触发 docker-publish 工作流）。
COPY package.json package-lock.json server.js worker.js ./
COPY node_modules ./node_modules

# 创建引导器：启动时从 GitHub raw 拉取最新 worker.js
# （fscarmen/Argo-Nezha-Service-Container 模式：容器只做引导，逻辑在远程仓库）
# 拉取失败时回退本地预置副本，保证容器始终可启动。
RUN printf '%s\n' \
    '#!/usr/bin/env sh' \
    '' \
    'set -e' \
    'WORKER_URL="https://raw.githubusercontent.com/pingmike2/freebuff2api-wokers/main/worker.js"' \
    'TMP="/tmp/worker.js"' \
    '' \
    'echo "[entrypoint] fetching latest worker.js from GitHub..."' \
    'if wget -q --timeout=15 -O "$TMP" "$WORKER_URL"; then' \
    '  cp "$TMP" /app/worker.js && echo "[entrypoint] worker.js updated"' \
    'else' \
    '  echo "[entrypoint] fetch failed, keeping bundled worker.js"' \
    'fi' \
    '' \
    'exec node /app/server.js' \
    > /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create credentials dir (mounted at runtime)
RUN mkdir -p /app/credentials && chown -R node:node /app

USER node
EXPOSE 8787

ENTRYPOINT ["/app/entrypoint.sh"]
