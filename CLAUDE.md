# Yoga C630 — Ubuntu 24.04.4 LTS ARM64 セットアップ

このリポジトリは Lenovo Yoga C630 (Snapdragon 850) への Ubuntu ARM64 導入プロジェクトの引き継ぎ資料です。
Windows 側での作業はすべて完了しており、Ubuntu 初回起動後の作業をここから継続します。

## ハードウェア仕様（実機スキャン確定値）

| 項目 | 値 |
|---|---|
| SoC | Qualcomm Snapdragon 850 (SDM850) |
| CPU | Kryo 385 × 8コア (4+4) |
| RAM | 8GB LPDDR4x（※申告16GBと異なる、実測値） |
| 内部ストレージ | 128GB UFS 2.1（Windows 11 ARM 保持） |
| GPU | Adreno 630 |
| WiFi | Qualcomm WCN3990 |
| BIOS | V2.06（2019年6月、最新版は要確認） |

## ストレージ構成

```
内部 UFS 128GB:
  Windows 11 ARM（保持、触らない）

外付け SSD 256GB (USB-C, Realtek RTL9210B-CG):
  パーティション 1: 2GB FAT32  ラベル=FW_BACKUP  ← ファームウェア格納済み
  パーティション 2: EFI 512MB  (Ubuntu インストール時に作成)
  パーティション 3: / (ext4)   (Ubuntu インストール時に作成)
```

## ファームウェアの場所

Ubuntu 起動後、`/lib/firmware/qcom/sdm850/` に以下が配置されている必要があります。
`yoga_c630_post_install.sh` が自動配置します（FW_BACKUP パーティションから読み込み）。

| ファイル | 用途 | 優先度 |
|---|---|---|
| `qcdxkmsuc850.mbn` | GPU ZAP shader (要 pil-splitter 変換) | CRITICAL |
| `qcadsp850.mbn` | Audio DSP | CRITICAL |
| `bdwlan.bin` | WiFi ボードデータ | CRITICAL |
| `qcvss850.mbn` | Video codec (Venus) | 推奨 |
| `qcslpi850.mbn` | Sensor DSP (SLPI) | 推奨 |
| `qccdsp850.mbn` | cDSP | 推奨 |

## 既知の制限事項

- **外部ディスプレイ (DisplayPort)**: DisplayPort over USB-C の UCSI パッチが mainline 未確認（2026-03時点）→ 外部出力不可の可能性あり
- **Bluetooth**: 不安定な場合あり
- **サスペンド/レジューム**: EC ドライバは kernel 6.11 で mainline 統合済み、動作するが完全ではない場合あり
- **RAM**: 8GB のため、重い作業は ZRAM に依存。Chrome より Firefox 推奨

## 初回起動後の必須作業

```bash
# 1. リポジトリをクローン（このファイルが含まれているはず）
git clone https://github.com/mushipi/yoga-c630-ubuntu ~/yoga-c630-ubuntu

# 2. post_install.sh を実行（FW_BACKUP パーティションをマウントしてから）
sudo bash ~/yoga-c630-ubuntu/scripts/yoga_c630_post_install.sh

# 3. 再起動
sudo reboot
```

## 再起動後の検証

```bash
uname -r                             # HWE カーネル (6.8.x 以上)
zramctl                              # zram0 が表示されること
nmcli dev status                     # wifi 行が表示されること
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor  # schedutil
tlp-stat -s                          # TLP status: enabled
```

## 関連ファイル

- `scripts/yoga_c630_post_install.sh` — Ubuntu 初回設定スクリプト（sudo 実行）
- `scripts/yoga_c630_checklist.md` — 全フェーズのチェックリスト（進捗あり）
- `HANDOVER.md` — Windows 側での作業ログと詳細な引き継ぎ情報

## 総合評価

**3.0/5 ★★★☆☆ — 条件付き Go**

ブラウジング + SSH/ターミナル開発には実用レベル。外部ディスプレイ不要かつ Snapdragon エコシステムの制約を理解した上で使用すること。
