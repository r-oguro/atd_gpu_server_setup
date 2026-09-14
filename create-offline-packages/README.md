# Offline Autoinstall ISO staging area

このディレクトリは、Ubuntu Server ISOへ追加するファイルの作業領域です。

```text
create-offline-packages/
├── config/
│   └── current-system-config.tar.zst  # 任意
├── nocloud/
│   ├── meta-data
│   └── user-data
├── packages/
│   └── debs/                          # 収集スクリプトが生成
└── scripts/
    ├── create-offline-packages.sh
    ├── install-offline-packages.sh
    └── restore-config.sh
```

`nocloud/user-data` は `/cdrom/packages` と `/cdrom/scripts` を使うオフライン版です。ISO再作成時は、これらのディレクトリをISOのルートへ配置し、起動パラメーターに次を指定します。

```text
autoinstall ds=nocloud;s=/cdrom/nocloud/
```

パッケージの収集例:

```bash
sudo bash create-offline-packages/scripts/create-offline-packages.sh \
  "$PWD/create-offline-packages/packages"
```

設定アーカイブは任意です。復元前に内容を確認し、machine-id、hostname、SSHホスト鍵、NIC設定、fstabなどのマシン固有情報を含めないでください。
