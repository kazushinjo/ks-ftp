# KS-FTP

macOS向けネイティブFTPクライアント（SwiftUI製）

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 概要

KS-FTPはFTP / FTPS / SFTPに対応したmacOSネイティブのGUIファイル転送クライアントです。  
左ペインにローカル、右ペインにリモートを表示するデュアルペインレイアウトで、直感的なファイル操作が可能です。

![KS-FTP Screenshot](Resources/AppIcon.icns)

## 機能

- **FTP / FTPS / SFTP** 対応
- **デュアルペイン** レイアウト（左：ローカル / 右：リモート）
- フォルダの**ダブルクリックで移動**
- ファイルの**ドラッグ&ドロップ**でアップロード
- **ダウンロード**（リモート→ローカルの現在フォルダに保存）
- **アップロード**（ローカルで選択→リモートに送信）
- **接続プロファイルの保存・管理**（複数接続先を登録可能）
- 接続時の**初期パス**指定
- **日本語ファイル名・スペース入りファイル名**に対応
- ファイル・フォルダの**削除・新規フォルダ作成**
- 転送キューパネル（進行中・完了・エラーの確認）

## 動作環境

- macOS 14 (Sonoma) 以降
- Apple Silicon / Intel 両対応

## インストール

### ビルド済みアプリを使う

`/Applications/KS-FTP.app` に配置してください。

### ソースからビルド

```bash
git clone https://github.com/kazushinjo/ks-ftp.git
cd ks-ftp
swift build -c release
```

ビルド後、アプリバンドルを作成してインストール：

```bash
# アプリバンドルのディレクトリ構成を作成
mkdir -p /Applications/KS-FTP.app/Contents/MacOS
mkdir -p /Applications/KS-FTP.app/Contents/Resources

# バイナリとリソースをコピー
cp .build/release/FTPClient /Applications/KS-FTP.app/Contents/MacOS/KS-FTP
cp Resources/AppIcon.icns /Applications/KS-FTP.app/Contents/Resources/

# アドホック署名
codesign --deep --force --sign - /Applications/KS-FTP.app
```

## 使い方

1. **接続先を追加** — サイドバー下部の「＋」ボタンから接続情報を入力して保存
2. **接続** — サイドバーのプロファイルをクリック
3. **フォルダ移動** — リモート側のフォルダをダブルクリック
4. **ダウンロード** — リモートのファイルを選択して「ダウンロード」ボタン
5. **アップロード** — ローカルのファイルを選択して「アップロード」ボタン、またはドラッグ&ドロップ

## 技術スタック

- **Swift / SwiftUI** — UI
- **Swift Package Manager** — ビルドシステム
- **curl** — FTP/FTPS/SFTPバックエンド（システム標準 or Homebrew版）
- **NSEvent** — ダブルクリック検出（AppKitレベル）
- **UserDefaults** — 接続プロファイルの永続化

## ライセンス

MIT License — Copyright © 2026 K.Shinjo
