# Yoga C630 — Ubuntu ARM64 導入チェックリスト

**機体**: Snapdragon 850, 8GB RAM, 128GB UFS, BIOS V2.06
**方針**: 内部UFS（Windows 11 ARM）保持 + 外付け256GB SSDにUbuntu 24.04.4 LTS導入

---

## フェーズ 1: 事前確認・準備（Windows上）

### 1-1. 外付けSSD確認
- [ ] スクリプト実行: `PowerShell -ExecutionPolicy Bypass -File .\yoga_c630_firmware_backup.ps1`
- [ ] 256GB SSDが認識されているか確認（出力で "Found external SSD" が表示されること）

### 1-2. BIOSアップデート確認（高優先度）
- [ ] Lenovo サポートページを確認:
      `https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/yoga-series/yoga-c630-13q50`
- [ ] 現在V2.06（2019年6月）→ 新バージョンがあればダウンロード
- [ ] **ACアダプター接続状態で**BIOSアップデートを実施
- [ ] アップデート後、再度スクリプトを実行

### 1-3. ファームウェア抽出（最重要）
- [ ] スクリプト実行: `.\yoga_c630_firmware_backup.ps1`（管理者権限で）
- [ ] `C:\firmware_backup\` に以下が存在することを確認:
  - [ ] `qcdxkmsuc850.mbn` (GPU ZAP shader) — **CRITICAL**
  - [ ] `qcadsp850.mbn` (Audio DSP) — **CRITICAL**
  - [ ] `bdwlan.bin` (WiFi) — **CRITICAL**
  - [ ] `qcvss850.mbn` (Video codec) — 推奨
  - [ ] `qcslpi850.mbn` (Sensor DSP) — 推奨
  - [ ] `qccdsp850.mbn` (cDSP) — 推奨
- [ ] `SHA256SUMS.txt` が生成されていることを確認
- [ ] 外付けSSDにもコピーされていることを確認（二重バックアップ）

### 1-4. Windows 回復メディア作成
- [ ] `設定 > 更新とセキュリティ > 回復 > 回復ドライブの作成` でUSB回復メディアを作成

---

## フェーズ 2: Ubuntu インストールメディア準備

### 2-1. ISOダウンロード
- [ ] Ubuntu 24.04.4 LTS desktop ARM64 ISOをダウンロード:
      `https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.4-desktop-arm64.iso`
- [ ] SHA256検証スクリプト実行:
      `.\yoga_c630_verify_iso.ps1`
      または `-IsoPath` でパスを指定

### 2-2. 起動メディア作成
- [ ] **別の** USBメモリ（256GB SSDではなく小容量USB）を用意
- [ ] Balena Etcher または Rufus（ARM64対応）でブータブルメディアを作成
- [ ] 書き込み完了後、USBメモリが正常に認識されることを確認

---

## フェーズ 3: BIOS設定変更

- [ ] `F2` でBIOS設定画面を開く（起動時）
- [ ] **Secure Boot を無効化**
- [ ] **USB Boot を有効化**
- [ ] Boot Order: USB/外付けデバイスを最優先に設定
- [ ] 設定保存 (`F10`) して再起動

---

## フェーズ 4: Ubuntu インストール

- [ ] Ubuntuインストールメディア（USB）から起動
- [ ] インストール種別: **「カスタムパーティション」を選択**（重要）
- [ ] **内部UFS（Windows）には一切書き込まない**
- [ ] 外付けSSDへのパーティション構成:
  - [ ] EFI: 512MB (fat32)
  - [ ] `/`: 残り全て (ext4)
- [ ] **Bootloaderのインストール先を外付けSSDのEFIパーティションに指定**
- [ ] インストール完了後、USBメモリを抜いて再起動

---

## フェーズ 5: 初回起動後の設定

- [ ] 外付けSSDからUbuntuが起動することを確認
- [ ] ファームウェアバックアップのSSDをマウント
- [ ] 設定スクリプト実行:
      `sudo bash /path/to/yoga_c630_post_install.sh`
- [ ] 実行完了後、**再起動**

---

## 検証項目（再起動後）

| 確認項目 | コマンド | 期待値 |
|---|---|---|
| HWEカーネル | `uname -r` | `6.8.x-xx-generic` 以上 |
| ZRAM有効 | `zramctl` | zram0が表示される |
| WiFi動作 | `nmcli dev status` | wifi行が表示 |
| 音声出力 | `aplay -l` | カードが表示される |
| バッテリー認識 | `upower -i /org/freedesktop/UPower/devices/battery_BAT0` | state: discharging/charging |
| Bluetooth | `bluetoothctl show` | コントローラー情報表示 |
| タッチスクリーン | 直接タッチ確認 | — |
| CPUガバナー | `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` | `schedutil` |
| TLP | `tlp-stat -s` | TLP status: enabled |

---

## スクリプト一覧

| スクリプト | 実行環境 | 用途 |
|---|---|---|
| `yoga_c630_firmware_backup.ps1` | Windows PowerShell (管理者) | ファームウェア抽出・SSD確認 |
| `yoga_c630_verify_iso.ps1` | Windows PowerShell | Ubuntu ISO SHA256検証 |
| `yoga_c630_post_install.sh` | Ubuntu (sudo) | 初回設定・最適化 |

---

## 進捗状況（2026-03-31 確認）

- [x] レポート検証完了
- [x] 導入スクリプト作成完了（firmware_backup / verify_iso / prep_ssd / post_install）
- [x] ファームウェア抽出完了（`C:\firmware_backup\` 全6ファイル + SHA256SUMS.txt）
- [x] ファームウェアをDドライブ（リムーバブル）へコピー済み
- [x] Ubuntu 24.04.4 LTS ARM64 ISO ダウンロード済み（`C:\Users\lovet\Downloads\`）
- [x] ISO SHA256 検証済み（スクリプトの期待値と一致）
- [x] 256GB SSD 確認・パーティション準備完了（Disk 6 / Realtek RTL9210B-CG）
      → E: FAT32 2GB FW_BACKUP（ファームウェアコピー済み）+ 残り231GB 未割り当て
- [ ] BIOS最新版確認（V2.06 → Lenovoサポートページで要チェック）
- [ ] Windows 回復メディア作成
- [ ] 起動メディア作成（別USB、Balena Etcher等）
- [ ] BIOS設定変更（Secure Boot無効、USB Boot有効）
- [ ] Ubuntu インストール
- [ ] 初回設定完了（post_install.sh）
