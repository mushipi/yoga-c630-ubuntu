# yoga-c630-ubuntu — Lenovo Yoga C630 Ubuntu ARM64 導入

Lenovo Yoga C630 (Qualcomm Snapdragon 850) に Ubuntu 24.04.4 LTS ARM64 を外付け SSD から起動するためのセットアップ資料とスクリプト集。

## ハードウェア仕様

| 項目 | 値 |
|---|---|
| SoC | Qualcomm Snapdragon 850 (SDM850) |
| CPU | Kryo 385 × 8コア (4+4) |
| RAM | 8 GB LPDDR4x |
| 内部ストレージ | 128 GB UFS 2.1（Windows 11 ARM 保持） |
| GPU | Adreno 630 |
| WiFi | Qualcomm WCN3990 |

## ストレージ構成

```
内部 UFS 128GB  : Windows 11 ARM（保持・変更なし）
外付け SSD 256GB (USB-C, Realtek RTL9210B-CG):
  パーティション 1 : 2 GB   FAT32  ラベル=FW_BACKUP（ファームウェア格納）
  パーティション 2 : 512 MB EFI
  パーティション 3 : 残り    ext4  /（Ubuntu ルート）
```

## ファイル構成

| ファイル | 内容 |
|---|---|
| `yoga_c630_post_install.sh` | Ubuntu 初回起動後のセットアップスクリプト |
| `yoga_c630_checklist.md` | 作業チェックリスト |
| `HANDOVER.md` | 引き継ぎ資料（作業履歴・既知の問題） |
| `CLAUDE.md` | AI エージェント向けコンテキスト |

## セットアップ手順

1. 外付け SSD のパーティションを作成（`HANDOVER.md` 参照）
2. Ubuntu 24.04.4 ARM64 ISO を書き込み・インストール
3. 初回起動後にセットアップスクリプトを実行

```bash
chmod +x yoga_c630_post_install.sh
sudo ./yoga_c630_post_install.sh
```

## 既知の制約

- WiFi (WCN3990) はファームウェアの手動配置が必要
- BIOS V2.06 (2019年) — Secure Boot を無効化して運用
- GPU アクセラレーションは限定的（Adreno 630 オープンソースドライバ）