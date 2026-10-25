#!/usr/bin/env bash
# 在 WSL 的 Ubuntu 终端里运行：bash tools/setup-wsl.sh
set -uo pipefail

echo "==> 1/3 安装系统依赖"
sudo apt update
sudo apt install -y \
  usbmuxd libimobiledevice-utils \
  build-essential pkg-config unzip tzdata \
  libcurl4-openssl-dev libedit2 libpython3-dev libsqlite3-0 \
  libxml2-dev libz3-dev zlib1g-dev libncurses-dev

echo
echo "==> 2/3 检查 Swift"
if command -v swift >/dev/null 2>&1; then
  swift --version
else
  echo "Swift 还没装。"
  echo "打开 https://swift.org/install/linux ，复制 Ubuntu 那条安装命令执行 6.4 版本，"
  echo "装好后再跑一次本脚本。"
  exit 1
fi

echo
echo "==> 3/3 安装 xtool"
if command -v xtool >/dev/null 2>&1; then
  echo "xtool 已存在，跳过。"
else
  ARCH="$(uname -m)"
  echo "架构: $ARCH"
  curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-${ARCH}.AppImage" -o /tmp/xtool
  chmod +x /tmp/xtool
  sudo mv /tmp/xtool /usr/local/bin/xtool
fi

echo
echo "==> 自检"
printf '  usbmuxd : '; command -v usbmuxd >/dev/null && echo OK || echo 缺失
printf '  ideviceinfo : '; command -v ideviceinfo >/dev/null && echo OK || echo 缺失
printf '  swift   : '; command -v swift >/dev/null && echo OK || echo 缺失
printf '  xtool   : '; command -v xtool >/dev/null && echo OK || echo 缺失

echo
echo "全部 OK 之后，接下来两条命令："
echo "  xtool setup        # 登录 Apple ID，并填 Xcode.xip 的路径"
echo "  cd ~/PhotoSweep && xtool dev"
