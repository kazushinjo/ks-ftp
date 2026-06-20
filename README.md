# KS-FTP

macOS向けネイティブFTPクライアント（SwiftUI製）

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 概要

KS-FTPはFTP / FTPS / SFTPに対応したmacOSネイティブのGUIファイル転送クライアントです。  
左ペインにローカル、右ペインにリモートを表示するデュアルペインレイアウトで、直感的なファイル操作が可能です。

## 機能

- **FTP / FTPS / SFTP** 対応
- **デュアルペイン** レイアウト（左：ローカル / 右：リモート）
- **フォルダを含む再帰的なアップロード・ダウンロード**
- フォルダの**ダブルクリックで移動**（ローカル・リモート両対応）
- ファイル・フォルダの**ドラッグ&ドロップ**でアップロード
- **右クリックメニュー**（常時表示、未選択時はグレーアウト）
  - 右ペイン（リモート）：ダウンロード / 新規フォルダ・ファイル / 開く / 削除
  - 左ペイン（ローカル）：リモートにアップロード / 新規フォルダ・ファイル / Finderで表示 / ゴミ箱に移動
- **新規フォルダ・新規ファイル作成**（ローカル・リモート両対応、空フォルダでも右クリック可）
- **ファイル・フォルダの削除**（ローカルはゴミ箱へ移動）
- **接続プロファイルの保存・管理**（複数接続先を登録可能）
- 接続時の**初期パス**指定（未指定時はサーバーのホームディレクトリに接続）
- **日本語ファイル名・スペース入りファイル名**に対応
- **Unicode正規化（NFC）対応** — macOS(NFD)とLinux(NFC)間のファイル名重複を防止
- 転送キューパネル（進行中・完了・エラーの確認）

## UI デザイン

- サイドバーは**黒背景・白文字**のダークデザイン
- 接続先ボタンは**水色（シアン）**の背景で視認性を確保
- プロトコルアイコンは**白・太字**で背景とのコントラストを最大化
- 起動時からサイドバーを**常時表示**（折りたたみなし）
- 接続先未登録時はアプリアイコンと「接続を追加」ボタンをサイドバーに表示

## 動作環境

- macOS 14 (Sonoma) 以降
- Apple Silicon / Intel 両対応

## インストール

### ソースからビルド

```bash
git clone https://github.com/kazushinjo/ks-ftp.git
cd ks-ftp
swift build -c release
```

ビルド後、アプリバンドルを作成してインストール：

```bash
APP_DIR="/tmp/FTPClient.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/arm64-apple-macosx/release/FTPClient "$APP_DIR/MacOS/FTPClient"
cp Resources/AppIcon.icns "$APP_DIR/Resources/AppIcon.icns"

cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>FTPClient</string>
    <key>CFBundleIdentifier</key><string>com.kazuichishinjo.FTPClient</string>
    <key>CFBundleName</key><string>KS-FTP</string>
    <key>CFBundleDisplayName</key><string>KS-FTP</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

cp -R /tmp/FTPClient.app /Applications/FTPClient.app
```

## 使い方

1. **接続先を追加** — サイドバー下部の「＋」ボタンから接続情報を入力して保存
2. **接続** — サイドバーのプロファイルをクリック（初期パス未指定時はホームディレクトリ）
3. **フォルダ移動** — フォルダをダブルクリック（ローカル・リモート両対応）
4. **ダウンロード** — リモートのファイル・フォルダを選択して右クリック→「ダウンロード」またはツールバーボタン
5. **アップロード** — ローカルのファイル・フォルダを選択して右クリック→「リモートにアップロード」またはドラッグ&ドロップ
6. **新規作成・削除** — 右クリックメニューまたはツールバーから操作

## 技術スタック

- **Swift / SwiftUI** — UI
- **Swift Package Manager** — ビルドシステム
- **curl** — FTP/FTPS/SFTPバックエンド（システム標準 or Homebrew版）
- **NSEvent** — ダブルクリック・右クリック検出（AppKitレベル）
- **NSAlert / NSMenu** — 確実に動作するダイアログ・コンテキストメニュー
- **UserDefaults** — 接続プロファイルの永続化

## ライセンス

MIT License — Copyright © 2026 K.Shinjo
