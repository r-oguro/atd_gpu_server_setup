# Configuration archive

このディレクトリには、再インストール後も維持するアプリケーション設定を配置します。

マシン固有情報を含むため、設定内容を確認してからアーカイブを作成してください。
次のような情報は、通常そのまま復元しません。

- `/etc/machine-id`
- `/etc/hostname`
- SSHホスト鍵
- DHCPリース
- NICのMACアドレスに依存するnetplan
- `/etc/fstab` とディスクUUID

設定アーカイブを作成する場合は、例えば次のようにします。

```bash
sudo tar --zstd -cpf create-offline-packages/config/current-system-config.tar.zst \
  /etc/docker \
  /etc/chrony \
  /etc/munin \
  /etc/mail \
  /etc/auto.master.d \
  /etc/sssd \
  /etc/pam.d
```

アーカイブの内容は、復元前に `tar --zstd -tf` で確認してください。
