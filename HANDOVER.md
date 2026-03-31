# 引き継ぎ文書 — Yoga C630 Ubuntu 導入プロジェクト

**作成日**: 2026-03-31
**状態**: Windows 側の事前作業完了 / Ubuntu インストール待ち

---

## プロジェクト概要

Lenovo Yoga C630 (Snapdragon 850) に外付け 256GB SSD を使って Ubuntu 24.04.4 LTS ARM64 を導入する。
内部 UFS に入っている Windows 11 ARM は完全保持。

**採用理由**:
- レポート (`comprehensive_report_yoga_c630_actual.md`) による実機検証で「条件付き Go」と判断
- EC ドライバが kernel 6.11 で mainline 統合済み → Ubuntu 24.04.4 の HWE カーネルで動作見込み
- 外部 SSD ブートにより内部 Windows に影響なし

---

## Windows 側の完了作業（2026-03-31時点）

### ファームウェア抽出（最重要）

- **場所**: `C:\firmware_backup\` および外付け SSD の `FW_BACKUP` パーティション (E:)
- **ファイル数**: 全 6 ファイル + `SHA256SUMS.txt`
- **スクリプト**: `yoga_c630_firmware_backup.ps1`（管理者権限で実行済み）

```
C:\firmware_backup\
  qcdxkmsuc850.mbn  ← GPU ZAP shader (Adreno 630用、要変換)
  qcadsp850.mbn     ← Audio DSP
  bdwlan.bin        ← WiFi ボードデータ
  qcvss850.mbn      ← Video codec
  qcslpi850.mbn     ← Sensor DSP
  qccdsp850.mbn     ← cDSP
  SHA256SUMS.txt    ← 検証用ハッシュ
```

### SSD パーティション準備

- **ディスク**: Disk 6 (Realtek RTL9210B-CG, 256GB, USB接続)
- **構成**:
  - パーティション 1: 2GB FAT32、ラベル `FW_BACKUP`、ドライブレター `E:`
    - ファームウェア 6 ファイル + SHA256SUMS.txt コピー済み
  - 残り 231GB: 未割り当て（Ubuntu インストール先）

### Ubuntu ISO

- **場所**: `C:\Users\lovet\Downloads\ubuntu-24.04.4-desktop-arm64.iso`
- **SHA256 検証**: 通過済み（`yoga_c630_verify_iso.ps1` 実行済み）

---

## 残作業（Ubuntu インストールまで）

### 優先度: 高

- [ ] **BIOS 最新版確認**
  - 現在: V2.06（2019年6月）
  - Lenovo サポートページで新バージョン確認
  - ACアダプター接続状態でアップデート実施

- [ ] **Windows 回復メディア作成**
  - `設定 > 更新とセキュリティ > 回復 > 回復ドライブの作成`

- [ ] **起動メディア作成**
  - 別の USB メモリ（SSD とは別）に Balena Etcher でISOを書き込む
  - `ubuntu-24.04.4-desktop-arm64.iso` を使用

### Ubuntu インストール手順

1. USB から起動（F2 で BIOS → Secure Boot 無効 → USB Boot 有効）
2. インストール種別: **カスタムパーティション**（必須）
3. パーティション構成（外付け SSD の未割り当て領域に作成）:
   - EFI パーティション: 512MB (fat32)
   - `/`: 残り全て (ext4)
4. **Bootloader のインストール先を外付け SSD の EFI パーティションに指定**
5. 内部 UFS には絶対に書き込まない

---

## Ubuntu 初回起動後の作業

### 1. このリポジトリをクローン

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/mushipi/yoga-c630-ubuntu ~/yoga-c630-ubuntu
```

### 2. FW_BACKUP パーティションのマウント確認

スクリプトは `/media/$USER/FW_BACKUP/firmware_backup/` を自動検出します。
自動マウントされていない場合は手動マウント:

```bash
# SSD のデバイス名を確認
lsblk

# マウント（デバイス名は環境に応じて変更）
sudo mkdir -p /media/$USER/FW_BACKUP
sudo mount /dev/sdX1 /media/$USER/FW_BACKUP
```

### 3. post_install.sh を実行

```bash
sudo bash ~/yoga-c630-ubuntu/scripts/yoga_c630_post_install.sh
```

**スクリプトが実行する内容**:
1. ファームウェアを `/lib/firmware/qcom/sdm850/` へ配置
   - GPU ZAP shader は `pil-splitter` で変換（自動）
2. HWE カーネル (`linux-generic-hwe-24.04`) インストール
3. ZRAM 設定（4GB zstd 圧縮、`vm.swappiness=150`）
4. カーネルパラメータ最適化
5. CPU governor を `schedutil` に設定
6. TLP（電源管理）インストール・有効化

### 4. 再起動

```bash
sudo reboot
```

---

## 動作検証チェックリスト（再起動後）

| 確認項目 | コマンド | 期待値 |
|---|---|---|
| HWE カーネル | `uname -r` | `6.8.x-xx-generic` 以上 |
| ZRAM 有効 | `zramctl` | zram0 が表示 |
| WiFi | `nmcli dev status` | wifi 行が表示 |
| 音声 | `aplay -l` | カードが表示 |
| バッテリー | `upower -i /org/freedesktop/UPower/devices/battery_BAT0` | state 表示 |
| Bluetooth | `bluetoothctl show` | コントローラー情報 |
| タッチスクリーン | 直接タッチ確認 | — |
| CPU governor | `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` | `schedutil` |
| TLP | `tlp-stat -s` | TLP status: enabled |

---

## 参考資料（Windows 側のファイル）

| ファイル | 場所 | 内容 |
|---|---|---|
| 総合レポート | `C:\Users\lovet\Documents\outputs\comprehensive_report_yoga_c630_actual.md` | 実機スキャン結果、評価 3.0/5 |
| 詳細調査 | `C:\Users\lovet\Documents\outputs\deep_investigation_yoga_c630_2026.md` | カーネル/OS 詳細調査 |
| Feasibility | `C:\Users\lovet\Documents\outputs\feasibility_report_yoga_c630.md` | 導入可否判断レポート |

---

## トラブルシューティング

### WiFi が動作しない
1. `ls /lib/firmware/qcom/sdm850/bdwlan.bin` でファームウェアの存在確認
2. `dmesg | grep -i wcn3990` でドライバエラー確認
3. ファームウェアがない場合は FW_BACKUP からコピー: `sudo cp /media/$USER/FW_BACKUP/firmware_backup/bdwlan.bin /lib/firmware/qcom/sdm850/`

### GPU (Adreno 630) が動作しない / 画面が黒い
1. ZAP shader の確認: `ls /lib/firmware/qcom/sdm850/qcdxkmsuc850*`
2. `dmesg | grep -i zap` でエラー確認
3. pil-splitter 変換が失敗していた場合は手動実行:
   ```bash
   pip3 install pil-splitter
   pil-splitter /media/$USER/FW_BACKUP/firmware_backup/qcdxkmsuc850.mbn /tmp/zap
   sudo cp /tmp/zap* /lib/firmware/qcom/sdm850/
   ```

### Ubuntu が起動しない（BIOS が外付け SSD を認識しない）
- BIOS で Boot Order を確認（USB/外付けデバイスが最優先になっているか）
- Secure Boot が無効になっているか再確認
- SSD の EFI パーティションが正しく作成されているか確認
