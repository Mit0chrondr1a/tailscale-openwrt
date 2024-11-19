#!/bin/sh
arch_=$(uname -m)
endianness=""

case "$arch_" in
    i386)
        arch=386
        ;;
    x86_64)
        arch=amd64
        ;;
    armv7l)
        arch=arm
        ;;
    aarch64 | armv8l)
        arch=arm64
        ;;
    geode)
        arch=geode
        ;;
    mips)
        arch=mips
        endianness=$(echo -n I | hexdump -o | awk '{ print (substr($2,6,1)=="1") ? "le" : "be"; exit }')
        ;;
    riscv64)
        arch=riscv64
        ;;
    *)
        echo "INSTALL: --------------------------------------------"
        echo "当前机器的架构是 [${arch_}${endianness}]"
        echo "脚本内置的架构代码可能有误,不符合您的机器"
        echo "请在这个issue留下评论以便作者及时修改脚本"
        echo "https://github.com/CH3NGYZ/tailscale-openwrt/issues/6"
        echo "------------------------------------------------------"
        exit 1
        ;;
esac

if [ -e /tmp/tailscaled ]; then
    echo "INSTALL: ------------------"
    echo "存在残留, 请卸载并重启后重试"
    echo "卸载命令: wget -qO- https://ghproxy.net/https://raw.githubusercontent.com/CH3NGYZ/tailscale-openwrt/chinese_mainland/uninstall.sh | sh"
    echo "---------------------------"
    exit 1
fi

opkg update

# 检查并安装包
required_packages="libustream-openssl ca-bundle kmod-tun coreutils-timeout"
for package in $required_packages; do
    # 检查包是否已安装
    if ! opkg list-installed | grep -q "$package"; then
        echo "INSTALL: 包 $package 未安装，开始安装..."
        opkg install "$package"
        if [ $? -ne 0 ]; then
            echo "INSTALL: 安装 $package 失败，跳过该包，如果无法正常运行 tailscale，请排查是否需要手动安装该包"
            continue
        else
            echo "INSTALL: 包 $package 安装成功"
        fi
    else
        echo "INSTALL: 包 $package 已安装，跳过"
    fi
done


# 下载安装包
wget --tries=5 -c -t 60 https://raw.githubusercontent.com/CH3NGYZ/tailscale-openwrt/main/tailscale-openwrt.tgz

# 解压
tar x -pzvC / -f tailscale-openwrt.tgz

# 删除安装包
rm tailscale-openwrt.tgz
# 设定开机启动
/etc/init.d/tailscale enable
ls /etc/rc.d/*tailscale*
#启动
# /etc/init.d/tailscale start
/etc/rc.d/S90tailscale start
echo "Please wait, the timeout time is three minutes, the Tailscaled service is downloading the Tailscale executable file in the background..."

start_time=$(date +%s)
timeout=180  # 3分钟的超时时间

while true; do
    if [ -e /tmp/tailscaled ]; then
        echo "/tmp/tailscaled 存在, 继续"
        break
    else
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ $elapsed_time -ge $timeout ]; then
            echo "The script has timed out. Please manually open the Syslog to see the reason for the failure."
            exit 1
        else
            sleep 2
        fi
    fi
done

echo "If the login fails, check the background service running status by running /etc/init.d/tailscaled status"
tailscale up --accept-dns=false --advertise-exit-node
echo "The current machine architecture is arch_:${arch_}${endianness} | arch:${arch} . If it works successfully, leave a comment on this issue so that the author can revise the documentation in time: https://github.com/CH3NGYZ/tailscale-openwrt/issues/6"
