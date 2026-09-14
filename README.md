# atd_gpu_server_setup

GPUサーバーのセットアップについて

## DVDとUSBを使ってAutoinstallを実行する

### 使用する媒体

次の2つの媒体を使用します。

- `ubuntu-26.04-live-server-amd64.iso`を書き込んだDVD
- `autoinstall_user-data/` と `scripts/` を保存した別のUSBドライブ

Ubuntu ISOはDVDから起動します。USBドライブはインストール中に読み込む補助媒体であり、Ubuntu ISOを書き込む必要はありません。

### USBドライブの準備

USBドライブのデータパーティションのラベルは、デフォルトのVentoyラベルである`Ventoy`を使用します。この設定では、インストール中に次のデバイスを検索します。

```text
/dev/disk/by-label/Ventoy
```

ラベルを確認するには、USBドライブを接続して次を実行します。

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

USBドライブの大容量データパーティションが`Ventoy`以外のラベルの場合は、[precision87960_user-data.yaml](autoinstall_user-data/precision87960_user-data.yaml) の`late-commands`にある`/dev/disk/by-label/Ventoy`を実際のラベルに変更してください。

USBドライブをマウントし、リポジトリのファイルをコピーします。次の例では、USBが`/media/$USER/Ventoy`にマウント済みであるとします。

```bash
USB_MOUNT=/media/$USER/Ventoy

mkdir -p "$USB_MOUNT/autoinstall_user-data"
mkdir -p "$USB_MOUNT/scripts"
cp autoinstall_user-data/precision87960_user-data.yaml \
   "$USB_MOUNT/autoinstall_user-data/"
cp autoinstall_user-data/scripts/*.sh "$USB_MOUNT/scripts/"
sync
```

USBドライブの構成は次のようにします。

```text
Ventoy USBのデータパーティション/
├── autoinstall_user-data/
│   └── precision87960_user-data.yaml
└── scripts/
    ├── install-base-services.sh
    ├── install-cuda-toolkit.sh
    ├── install-docker-nvidia-toolkit.sh
    └── install-nvidia-driver.sh
```

### user-dataの指定

DVD起動ではVentoyの`ventoy.json`は使用されません。別USBをuser-dataの読み込み元にする場合は、Ubuntuインストーラーの起動パラメーターでNoCloud datasourceを指定します。

NoCloudは任意のファイル名を直接読むのではなく、指定したディレクトリ内の`user-data`と`meta-data`を読み込みます。USB上に次の構成を用意してください。

```text
Ventoy USBのデータパーティション/
├── autoinstall_user-data/
│   └── precision87960_user-data.yaml
├── nocloud/
│   ├── user-data
│   └── meta-data
└── scripts/
```

`user-data`はシンボリックリンクではなく、実ファイルとして作成してください。例えば次のようにコピーします。

```bash
USB_MOUNT=/media/$USER/Ventoy
mkdir -p "$USB_MOUNT/nocloud"
cp "$USB_MOUNT/autoinstall_user-data/precision87960_user-data.yaml" \
    "$USB_MOUNT/nocloud/user-data"
printf 'instance-id: precision87960\n' > "$USB_MOUNT/nocloud/meta-data"
sync
```

Ubuntuインストーラーのカーネル起動パラメーターには、USBが`/media/usb`にマウント済みである場合、次を追加します。

```text
autoinstall ds=nocloud;s=/media/usb/nocloud/
```

ただし、通常のUbuntu DVD起動では、別USBが`/media/usb`へ自動的にマウントされる保証はありません。実際の環境でUSBのマウント先を確認し、起動パラメーターのパスを合わせる必要があります。USBがマウントされる前にNoCloudの検索が実行される場合、この方法ではuser-dataを読み込めず、Autoinstallは開始されません。

そのため、この方法を使用するには、次のいずれかが必要です。

- Ubuntuインストーラー環境で別USBを`/media/usb`などの固定パスへマウントするカスタム起動構成
- USBを起動時にマウントする仕組みを含むカスタムISO
- NoCloudの代わりに、DVD内またはHTTPサーバー上のseedを使用する構成

このリポジトリのYAMLにある`late-commands`は、user-dataを読み込んだ後に実行されるため、late-commandsでUSBをマウントして、そのUSB上のuser-data自身を読み込むことはできません。現在の`late-commands`は、NoCloudで読み込まれたuser-dataから実行され、USB上の`/scripts`をインストール先へコピーするために`Ventoy`パーティションをマウントします。

### インストールを実行する

1. Ubuntu 26.04 Server ISOを書き込んだDVDと、準備したUSBドライブを対象サーバーに接続します。
2. DVDドライブから起動します。
3. Ubuntuインストーラーの起動メニューでAutoinstallを選択します。
4. `precision87960_user-data.yaml`をAutoinstallのuser-dataとして指定します。
5. Ubuntuインストーラーがuser-dataを読み込んだことを確認して処理を開始します。
6. 対象ディスクを消去してインストールすることを確認します。

`late-commands`は次の処理を行います。

1. USBの`Ventoy`データパーティションを`/mnt/ventoy`へ読み取り専用でマウントします。
2. USBの`/scripts`をインストール先の`/root/autoinstall/scripts/`へコピーします。
3. 基本サービス、NVIDIA Driver、Docker/NVIDIA Container Toolkit、CUDA Toolkitのスクリプトを順番に実行します。
4. USBをアンマウントします。

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
- `late-commands`実行時にUSBドライブが接続され、データパーティションのラベルが`Ventoy`である必要があります。
- インストーラー環境がUSBドライブのファイルシステムをマウントできる必要があります。
- `late-commands`は外部APTリポジトリへ接続します。DHCP、DNS、HTTPS通信が必要です。
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
