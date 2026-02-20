#!/bin/bash

# 1. 加载配置（只导出 KEY=value 行，忽略注释和空行）
if [ -f .env ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        export "$line"
    done < <(grep -v '^#' .env | grep -v '^$')
else
    echo "错误: 找不到 .env 文件"
    exit 1
fi

echo ">>> 目标官方版本: $OFFICIAL_TAG"

# 2. 如果是 latest，尝试解析真实的语义化版本号（优先使用 jq，fallback 到 python）
TARGET_TAG=$OFFICIAL_TAG
if [ "$OFFICIAL_TAG" = "latest" ]; then
    echo ">>> 正在检测官方 latest 对应的真实版本..."
    
    # 方法1: 使用 jq（如果可用）
    if command -v jq &>/dev/null; then
        DIGEST=$(curl -s https://hub.docker.com/v2/repositories/sharelatex/sharelatex/tags/latest | jq -r '.digest')
        REAL_VER=$(curl -s "https://hub.docker.com/v2/repositories/sharelatex/sharelatex/tags/?page_size=100" | \
            jq -r ".results[] | select(.digest == \"$DIGEST\" and .name != \"latest\") | .name" | \
            sort -V | tail -n 1)
        if [ -n "$REAL_VER" ]; then
            TARGET_TAG=$REAL_VER
            echo ">>> 检测到真实版本为: $TARGET_TAG (使用 jq)"
        fi
    # 方法2: 使用 Python 脚本（fallback）
    elif command -v python3 &>/dev/null || command -v python &>/dev/null; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        PYTHON_CMD=$(command -v python3 2>/dev/null || command -v python)
        REAL_VER=$($PYTHON_CMD "$SCRIPT_DIR/get_latest_version.py" sharelatex/sharelatex 2>/dev/null)
        if [ -n "$REAL_VER" ]; then
            TARGET_TAG=$REAL_VER
            echo ">>> 检测到真实版本为: $TARGET_TAG (使用 Python)"
        fi
    else
        echo ">>> 未检测到 jq 或 Python，将直接使用 latest 标签"
    fi
fi

# 3. 构建镜像
# 我们同时给镜像打两个标签：具体版本号 和 latest
docker build \
    --build-arg OFFICIAL_TAG=$OFFICIAL_TAG \
    --build-arg TL_MIRROR=$TL_MIRROR \
    -t ${MY_REPO}:${TARGET_TAG} \
    -t ${MY_REPO}:latest .

# 4. 推送
if [ $? -eq 0 ]; then
    echo ">>> 构建成功，准备推送..."
    docker push ${MY_REPO}:${TARGET_TAG}
    docker push ${MY_REPO}:latest
    echo ">>> 所有任务完成！"
    echo ">>> 你的镜像地址: ${MY_REPO}:${TARGET_TAG}"
else
    echo ">>> 构建失败，请检查网络或磁盘。"
fi