#!/bin/bash

IMAGE="betterweb/hugo:extended-0.121.1-20-1"
UID="1030:1030"

# --- 模式 1: 启动 Server (后台运行) ---
if [ "$1" = "server" ]; then
  URL=$2
  # 检查 URL，若为空则提示并退出
  [ -z "$URL" ] && echo "Error: 请指定 baseURL (例如: $0 server http://example.com:1313)" && exit 1

  echo ">> 启动后台服务 (URL: $URL)..."
  docker run -d --name hugo --restart unless-stopped --user "$UID" \
    -v "$PWD":/home/app -p 1313:1313 "$IMAGE" \
    -c "hugo server -D -w --bind \"0.0.0.0\" -b \"$URL\" --disableFastRender"

# --- 模式 2: CLI 工具 (临时运行) ---
else
  # 如果有参数则使用参数，否则默认执行 "version"
  ARGS=${*:-"version"}
  
  # 执行命令 (临时容器用完即删)
  docker run --rm -it --user "$UID" \
    -v "$PWD":/home/app "$IMAGE" \
    -c "hugo $ARGS"
fi
