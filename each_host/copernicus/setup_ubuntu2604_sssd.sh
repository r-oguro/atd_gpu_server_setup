#!/bin/bash
set -euo pipefail
set -x

# rootユーザーだけが実行できるスクリプトです。amiユーザーがログインしている場合の実行は中止します。
if [ "$EUID" -ne 0 ]; then
    echo 'rootユーザーで実行してください。' >&2
    exit 1
fi

# 情シスにパスワード入力をしてもらう作業
apt-get -y install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit
if ! realm list | grep -q '^advanced-media\.co\.jp$'; then
    echo "次のコマンドを実行します。"
    echo "情シスにAD接続のためのパスワードを入力してもらってください。"
    echo "realm discover advanced-media.co.jp"
    echo "realm join advanced-media.co.jp"
    realm discover advanced-media.co.jp
    realm join advanced-media.co.jp
    echo "${0}を終了します"
    systemctl stop sssd
    exit
fi

# パスワードなしでssh接続する
if [ ! -e /root/.ssh/id_ed25519 ]; then
    scp -p pythagoras:/root/.ssh/id_ed25519 /root/.ssh/
fi

# autofsファイルのコピー、応技ユーザーリストのコピー
mkdir -p /root/setup
scp -p  pythagoras:/work/Admin/atd_users_list.txt /root/setup/
scp -p  pythagoras:/work/Admin/add_permission_to_sssd.sh /root/setup/
scp -pr pythagoras:/etc/auto.master.d /root/setup/
scp -pr pythagoras:/etc/auto.{ctd,home,work,direct} /root/setup/
scp -p  pythagoras:/etc/sssd/sssd.conf /root/setup/

# ユーザーアカウント(SSSD)
# SSSDの設定ファイルのバックアップと設定ファイルのコピーと初期データの削除とsssdの起動
systemctl stop sssd
rm -f /var/lib/sss/db/*.ldb
if [ ! -e /etc/sssd/sssd.conf.orig ] && [ -e /etc/sssd/sssd.conf ]; then
    mv /etc/sssd/sssd.conf /etc/sssd/sssd.conf.orig
fi
cp -p /root/setup/sssd.conf /etc/sssd/sssd.conf
chmod 640 /etc/sssd/sssd.conf
chgrp sssd /etc/sssd/sssd.conf
systemctl enable --now sssd

# 応技のユーザーをusersグループなどに追加、ログインユーザーの制限
set +e
cat /root/setup/atd_users_list.txt | while read line; do gpasswd -a $line users; done
cat /root/setup/atd_users_list.txt | while read line; do gpasswd -a $line docker; done
for user in r-oguro tanaka k-susuta t-sasame; do gpasswd -a $user sudo; done
bash /root/setup/add_permission_to_sssd.sh
set -e
systemctl restart sssd

# ホームディレクトリなどのNFSマウント、オートマウンタの設定、/dataのマウントの設定
cp -p /root/setup/auto.master.d/* /etc/auto.master.d/
cp -p /root/setup/auto.{ctd,home,work,direct} /etc/
systemctl stop autofs
systemctl enable --now autofs

# ここまでの作業でリブート。残りは再起動後に実行する
echo "Done. Please reboot the system and run the remaining setup after reboot."
exit
