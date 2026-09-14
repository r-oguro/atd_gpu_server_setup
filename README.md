# atd_gpu_server_setup

GPUサーバーのセットアップについて

## Python簡易HTTPサーバーでAutoinstallを実行する

### 構成

Ubuntu ISOはDVDから起動し、user-data、meta-data、インストール用スクリプトは同じネットワーク上のLinuxホストからHTTPで配信します。Ventoy USBは使用しません。

```text
配布用Linuxホスト:
└── autoinstall-http/
    ├── user-data
    ├── meta-data
    └── scripts/
        ├── install-base-services.sh
        ├── install-cuda-toolkit.sh
        ├── install-docker-nvidia-toolkit.sh
        └── install-nvidia-driver.sh
```

NoCloudは任意のファイル名ではなく、HTTPサーバーのルートにある`user-data`と`meta-data`を読み込みます。

### meta-dataの使い方

`meta-data`は、NoCloudデータソースのインスタンスを識別するための補助ファイルです。OSの設定本体は`user-data`に記述し、`meta-data`には最低限、一意な`instance-id`を記述します。

この構成では、次の内容で十分です。

```text
instance-id: precision87960
```

配布用Linuxホストで、次のように作成します。

```bash
printf 'instance-id: precision87960\n' > ~/autoinstall-http/meta-data
```

ホスト名もNoCloudのmeta-dataで指定したい場合は、`local-hostname`を追加できます。ただし、このuser-dataでは`identity.hostname`にも`precision87960`を指定しているため、通常は追加不要です。

```text
instance-id: precision87960
local-hostname: precision87960
```

`instance-id`は同じインストールを再実行するときも変更できます。別のサーバーを個別に識別する必要がある場合は、サーバーごとに異なる値を指定してください。`meta-data`にパスワードやSSH鍵などの秘密情報は記述しません。

HTTPサーバーから取得できることを確認します。

```bash
curl http://192.168.1.100:8000/meta-data
```

レスポンスに`instance-id`が表示されれば、NoCloudが取得するmeta-dataを配信できています。

### HTTP配信用ファイルを準備する

配布用Linuxホストで、リポジトリからuser-dataとscriptsをコピーします。

```bash
mkdir -p ~/autoinstall-http/scripts
cp autoinstall_user-data/precision87960_user-data.yaml \
   ~/autoinstall-http/user-data
cp autoinstall_user-data/scripts/*.sh ~/autoinstall-http/scripts/
printf 'instance-id: precision87960\n' > ~/autoinstall-http/meta-data
```

### HTTPサーバーを起動する

`http.server`はPython 3の標準ライブラリなので、追加パッケージなしで利用できます。

```bash
cd ~/autoinstall-http
python3 -m http.server 8000 --bind 0.0.0.0
```

配布用ホストのIPアドレスを確認します。

```bash
ip -br address
```

例えばIPアドレスが`192.168.1.100`の場合、次のURLで確認できます。

```bash
curl http://192.168.1.100:8000/user-data
curl http://192.168.1.100:8000/meta-data
```

別ホストから取得できることを確認してからインストールを開始してください。

### Autoinstallを起動する

1. 配布用Linuxホストと対象サーバーを同じネットワークに接続します。
2. `precision87960_user-data.yaml` の `base_url` を配布用LinuxホストのIPアドレスに変更します。
3. 対象サーバーにUbuntu ISOを書き込んだDVDを接続します。USBドライブは不要です。
4. DVDドライブから起動します。
5. Ubuntuインストーラーの起動項目で`e`キーを押し、カーネル起動行の末尾に次を追加します。

```text
autoinstall ds=nocloud-net;s=http://192.168.1.100:8000/
```

6. `Ctrl+X`または`F10`で起動します。キーは環境によって異なります。
7. インストーラーがHTTPサーバーから`user-data`と`meta-data`を取得したことを確認します。

URLの末尾には`/`を付けてください。UbuntuインストーラーがHTTPへ接続する時点でネットワークを取得できている必要があります。

### late-commandsの動作

現在の [precision87960_user-data.yaml](autoinstall_user-data/precision87960_user-data.yaml) は、次の順で処理します。

1. HTTPからuser-dataとmeta-dataを読み込みます。
2. HTTPサーバーの`/scripts/`から4本のスクリプトをインストール先の`/root/autoinstall/scripts/`へ取得します。
3. 基本サービス、NVIDIA Driver、Docker/NVIDIA Container Toolkit、CUDA Toolkitのスクリプトを順番に実行します。

### ネットワークとファイアウォール

配布用ホストでTCP `8000`を許可してください。UFWを使用している場合の例:

```bash
sudo ufw allow from 192.168.1.0/24 to any port 8000 proto tcp
```

ネットワーク範囲は実際の環境に合わせて変更します。HTTPサーバーは認証やHTTPSを提供しないため、インストール用の閉じたネットワークで一時的に使用してください。公開ディレクトリには必要なファイルだけを置きます。

### HTTPサーバーを停止する

HTTPサーバーを起動した端末で`Ctrl+C`を押します。

### インストール内容

- `/dev/nvme0n1`をGPTで初期化
- EFI、`/boot`、LVMによるrootパーティションを作成
- root領域に残りのディスク容量を割り当て
- `bond0`をDHCPで構成
- `enp1s0`をDHCPで構成
- etckeeper、Python、Sendmail、Muninをインストール
- Firewall、AppArmor、自動更新を停止
- NFS関連パッケージをインストール
- NVIDIA Driver、CUDA Toolkit、NCCL、Docker、NVIDIA Container Toolkitをインストール
- NVSwitchを検出した場合だけFabric Managerをインストール

### 注意事項

- ストレージ設定は`/dev/nvme0n1`を消去します。対象サーバーのディスク内容は失われます。
- EFIと`/boot`以外の領域はroot用LVMに割り当てられます。
- `bond0`のメンバーは現在`ens6f0np0`と`ens6f1np1`に固定されています。これらのNICがないサーバーでは、インストール中のbond構成や外部パッケージ取得に失敗する可能性があります。
- `late-commands`実行時にHTTPサーバーへ接続できる必要があります。DHCP、DNSまたはIP到達性、HTTP通信が必要です。
- `late-commands`内の`base_url`は配布用LinuxホストのIPアドレスに変更してください。
- HTTPサーバーはuser-data取得後も、late-commandsが完了するまで起動しておく必要があります。
- NVIDIA Driver、CUDA Toolkit、NCCL、Docker、NVIDIA Container Toolkitのインストールには時間がかかります。
- インストール後、NVIDIA DriverやDockerの状態を確認し、必要に応じて再起動してください。

### インストール後の確認

```bash
nvidia-smi
nvcc --version
docker info
docker run --rm --gpus all nvidia/cuda:13.1.1-base-ubuntu26.04 nvidia-smi
```

Dockerのテストイメージのタグは、NVIDIAが提供するタグに合わせて変更してください。
