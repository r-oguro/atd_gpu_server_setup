#!/bin/bash
set -euo pipefail
set -x

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

# SSH設定
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i.bak -E 's/account[[:space:]]+\[default=bad success=ok user_unknown=ignore\][[:space:]]+pam_sss.so/account\t[default=bad success=ok user_unknown=ignore service_err=ignore system_err=ignore authinfo_unavail=ignore]\tpam_sss.so/' /etc/pam.d/common-account

# Firewall停止
ufw disable || true

# AppArmor停止
systemctl disable apparmor || true
systemctl stop apparmor 2>/dev/null || true

# 自動更新停止
sed -i -e '/^APT::Periodic::Update-Package-Lists/s/"1"/"0"/' \
       -e '/^APT::Periodic::Unattended-Upgrade/s/"1"/"0"/' \
       /etc/apt/apt.conf.d/20auto-upgrades

# NFS関連パッケージ
apt-get update
apt-get install -y nfs-common nfs-kernel-server nfs4-acl-tools autofs

# etckeeper
apt-get install -y etckeeper

# Python
apt-get install -y python3 python3-pip python3-venv software-properties-common
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get install -y python3.10 python3.10-venv

# Sendmail
apt-get install -y sendmail mailutils
if ! grep -q "SMART_HOST.*smtp-internal\\.advanced-media\\.co\\.jp" /etc/mail/sendmail.mc; then
    sed -i "/FEATURE(\`no_default_msa\')dnl/i define(\`SMART_HOST\', \`smtp-internal.advanced-media.co.jp\')dnl" /etc/mail/sendmail.mc
fi
(cd /etc/mail && make)
systemctl enable sendmail
if ! grep -q "^root:" /etc/aliases; then
    echo "root: r-oguro@advanced-media.co.jp" >> /etc/aliases
    newaliases
fi

# Munin
apt-get install -y munin-node
if ! grep -qF 'allow ^10\\..*$' /etc/munin/munin-node.conf; then
    perl -i.orig -pe 's/^(allow \^127.*)$/$1\nallow ^10\\\\..*\$/' /etc/munin/munin-node.conf
fi
munin-node-configure -shell | sh > /dev/null 2>&1 || true
systemctl enable munin-node

echo "Base services installation completed."
