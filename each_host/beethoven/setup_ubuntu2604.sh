#!/bin/bash
set -euo pipefail
set -x

# rootユーザーだけが実行できるスクリプトです。amiユーザーがログインしている場合の実行は中止します。
if [ "$EUID" -ne 0 ]; then
    echo 'rootユーザーで実行してください。' >&2
    exit 1
fi
if loginctl list-sessions --no-legend | awk '$3 == "ami" { found = 1 } END { exit found }'; then
    if pgrep -u ami > /dev/null; then
        echo 'amiユーザーのプロセスが実行中のため中止します。rootユーザーで直接ログインしてください。' >&2
        exit 1
    fi
else
    echo 'amiユーザーがログイン中のため中止します。rootユーザーで直接ログインしてください。' >&2
    exit 1
fi

# etckeeperのインストール
apt-get -y install etckeeper

# 初期作成ユーザーamiのホームディレクトリを変更
# mv /home/ami /home_local/ami
# sed -i 's|:/home/ami:|:/home_local/ami:|' /etc/passwd
ami_home=$(awk -F: '$1 == "ami" { print $6; exit }' /etc/passwd)
if [ "$ami_home" = "/home/ami" ]; then
    mkdir -p /home_local
    usermod -m -d /home_local/ami ami
fi

# rootでのsshログインを許可する
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# ssh接続時のエラーに対処する
sed -i.bak -E 's/account[[:space:]]+\[default=bad success=ok user_unknown=ignore\][[:space:]]+pam_sss.so/account\t[default=bad success=ok user_unknown=ignore service_err=ignore system_err=ignore authinfo_unavail=ignore]\tpam_sss.so/' /etc/pam.d/common-account

# updateとupgrade
apt-get update
apt-get -y upgrade
apt-get -y autoremove

# nvidia-driverのインストール
ubuntu-drivers devices
ubuntu-drivers install --include-dkms nvidia-driver-595-server-open
# reboot

# 時刻同期
timedatectl set-timezone Asia/Tokyo
apt-get -y install chrony
if [ -e /etc/chrony/sources.d/ubuntu-ntp-pools.sources ]; then
    if [ ! -e /etc/chrony/sources.d/ubuntu-ntp-pools.sources.bak ]; then
        mv /etc/chrony/sources.d/ubuntu-ntp-pools.sources /etc/chrony/sources.d/ubuntu-ntp-pools.sources.bak
    else
        rm -f /etc/chrony/sources.d/ubuntu-ntp-pools.sources
    fi
fi
cat > /etc/chrony/sources.d/ami.sources << 'EOF'
server 172.22.26.254 iburst prefer
server 10.3.2.3 iburst
server 172.16.2.14 iburst
EOF
systemctl restart chrony

# swapファイルサイズの拡張
# swapon --show
swap_size=$(stat -c %s /swap.img 2> /dev/null || echo 0)
if [ "$swap_size" -ne $((512 * 1024 * 1024 * 1024)) ]; then
    if swapon --show=NAME --noheadings | grep -qx /swap.img; then
        swapoff /swap.img
    fi
    fallocate -l 512G /swap.img
    chmod 600 /swap.img
    mkswap /swap.img
fi
if ! swapon --show=NAME --noheadings | grep -qx /swap.img; then
    swapon /swap.img
fi
# swapon --show

# Firewallの停止
ufw disable

# AppArmorの停止
systemctl disable --now apparmor

# ctrl-alt-delの無効化
systemctl mask ctrl-alt-del.target

# 自動更新の停止
sed -i -e '/^APT::Periodic::Update-Package-Lists/s/"1"/"0"/' \
       -e '/^APT::Periodic::Unattended-Upgrade/s/"1"/"0"/' \
       /etc/apt/apt.conf.d/20auto-upgrades
	
# NFS関連のパッケージのインストール
apt-get -y install nfs-common nfs-kernel-server nfs4-acl-tools autofs

# pythonのインストール
apt-get -y install python3 python3-pip python3-venv
apt-get -y install software-properties-common
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get -y install python3.10 python3.10-venv
	
# 標準リポジトリからCUDA Toolkitのインストール
# 事前にbuild-essentialのインストールが必要。
apt-get -y install build-essential
apt-get -y install cuda-toolkit-13-1

# nvidiaのリポジトリ（PPA)を追加して、より新しいCUDA Toolkitをインストールする
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
rm -f cuda-keyring_1.1-1_all.deb
apt-get update
apt-get -y install cuda-toolkit-13-3
cat > /etc/profile.d/cuda.sh << 'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/lib:$LD_LIBRARY_PATH
export TF_FORCE_GPU_ALLOW_GROWTH=true
export CUDA_DEVICE_ORDER=PCI_BUS_ID
# export CUDA_VISIBLE_DEVICES=0
EOF

# Dockerのインストール
install -d -m 755 /etc/apt/keyrings
apt-get -y install ca-certificates curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Nvidia Dockerのインストール
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' > /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get -y install nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl stop docker
systemctl enable --now docker
# docker run --rm --gpus all nvcr.io/nvidia/cuda:11.7.1-cudnn8-devel-ubuntu22.04 bash -c "nvidia-smi; nvcc -V"
	
# sendmailのインストール
apt-get -y install sendmail mailutils
if ! grep -q "SMART_HOST.*smtp-internal\.advanced-media\.co\.jp" /etc/mail/sendmail.mc; then
    sed -i "/FEATURE(\`no_default_msa\')dnl/i define(\`SMART_HOST\', \`smtp-internal.advanced-media.co.jp\')dnl" /etc/mail/sendmail.mc
fi
(cd /etc/mail; make)
systemctl stop sendmail
systemctl enable --now sendmail
if ! grep -q "^root:" /etc/aliases; then
    echo "root: r-oguro@advanced-media.co.jp" >> /etc/aliases
    newaliases
fi
	
# muninのインストール
apt-get -y install munin-node
if ! grep -qF 'allow ^10\..*$' /etc/munin/munin-node.conf; then
    perl -i.orig -pe 's/^(allow \^127.*)$/$1\nallow ^10\\..*\$/' /etc/munin/munin-node.conf
fi 
munin-node-configure -shell | sh > /dev/null 2>&1 || true
systemctl stop munin-node
systemctl enable --now munin-node

# ここまでの作業でリブート。残りは再起動後に実行する
echo "Done. Please reboot the system and run the remaining setup after reboot."
exit
