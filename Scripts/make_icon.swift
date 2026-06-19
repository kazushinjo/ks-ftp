#!/usr/bin/swift
import Cocoa

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

let w = CGFloat(size), h = CGFloat(size)
let rect = CGRect(x: 0, y: 0, width: w, height: h)

// ── 背景グラデーション ──────────────────────────────────────
let clip = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
clip.addClip()

let cs = CGColorSpaceCreateDeviceRGB()
// 深いインディゴ → ロイヤルブルー
let bgColors = [
    CGColor(red: 0.04, green: 0.09, blue: 0.38, alpha: 1),
    CGColor(red: 0.06, green: 0.28, blue: 0.78, alpha: 1),
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0] as [CGFloat])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

// ── 装飾：右下の大円 ─────────────────────────────────────────
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.05))
ctx.fillEllipse(in: CGRect(x: 500, y: -150, width: 750, height: 750))

// ── 上部 "KS" 大文字 ─────────────────────────────────────────
let ksFont = NSFont(name: "Helvetica Neue Bold", size: 420)
         ?? NSFont.boldSystemFont(ofSize: 420)

// シャドウ
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 36,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))

let ksAttrs: [NSAttributedString.Key: Any] = [
    .font: ksFont,
    .foregroundColor: NSColor.white,
]
let ksStr = NSAttributedString(string: "KS", attributes: ksAttrs)
let ksSize = ksStr.size()
let ksX = (w - ksSize.width) / 2
let ksY: CGFloat = 390   // NSImage座標は下が0
ksStr.draw(at: NSPoint(x: ksX, y: ksY))
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// ── 区切りライン ──────────────────────────────────────────────
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
ctx.setLineWidth(4)
ctx.move(to: CGPoint(x: 160, y: 380))
ctx.addLine(to: CGPoint(x: 864, y: 380))
ctx.strokePath()

// ── 下部 "FTP" ───────────────────────────────────────────────
let ftpFont = NSFont(name: "Helvetica Neue Bold", size: 210)
           ?? NSFont.boldSystemFont(ofSize: 210)

// シアン色でくっきり
let ftpAttrs: [NSAttributedString.Key: Any] = [
    .font: ftpFont,
    .foregroundColor: NSColor(red: 0.35, green: 0.90, blue: 1.0, alpha: 1),
    .kern: 18.0
]
let ftpStr = NSAttributedString(string: "FTP", attributes: ftpAttrs)
let ftpSize = ftpStr.size()
let ftpX = (w - ftpSize.width) / 2

// FTPのシャドウ
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 20,
              color: CGColor(red: 0, green: 0.4, blue: 0.8, alpha: 0.6))
ftpStr.draw(at: NSPoint(x: ftpX, y: 145))
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// ── 矢印アクセント（小さめ） ─────────────────────────────────
// 上矢印（右上）
func smallUpArrow(cx: CGFloat, cy: CGFloat, color: CGColor) {
    let aw: CGFloat = 28, ah: CGFloat = 52, hw: CGFloat = 60
    ctx.setFillColor(color)
    ctx.fill(CGRect(x: cx - aw/2, y: cy, width: aw, height: ah))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - hw/2, y: cy + ah))
    ctx.addLine(to: CGPoint(x: cx + hw/2, y: cy + ah))
    ctx.addLine(to: CGPoint(x: cx, y: cy + ah + 52))
    ctx.closePath()
    ctx.fillPath()
}

// 矢印（左上角）
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
smallUpArrow(cx: 175, cy: 430, color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))

// 矢印（右上角・下向き）
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
let dcx: CGFloat = 848, dBase: CGFloat = 430
let daw: CGFloat = 28, dah: CGFloat = 52, dhw: CGFloat = 60
ctx.fill(CGRect(x: dcx - daw/2, y: dBase + 52, width: daw, height: dah))
ctx.beginPath()
ctx.move(to: CGPoint(x: dcx - dhw/2, y: dBase + 52))
ctx.addLine(to: CGPoint(x: dcx + dhw/2, y: dBase + 52))
ctx.addLine(to: CGPoint(x: dcx, y: dBase))
ctx.closePath()
ctx.fillPath()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bmp  = NSBitmapImageRep(data: tiff),
      let png  = bmp.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: "/tmp/ksftp_icon2_1024.png"))
print("✓ 完了")
