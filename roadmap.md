# Roadmap

之後可能會做的開發項目。已完成的進度去看 `git log`,這裡只記「還沒做、但想過要做」的事。

新想到的加在最下方。決定要做的可以升到頂端;放棄的搬到「不做」區並寫上理由。

---

## 之後想做

### Stage 6:相機首頁 UI 改版 → **下一個**
目前相機首頁太空(只有一行辨識文字 + 一顆白圓快門)。計畫加 3 區視覺元素提升精緻度與資訊密度。

**Top 區**
- 黑半透明往下淡出的漸層遮罩(~120 pt)— 亮背景下文字依然讀得到
- 辨識結果從純 `UILabel` 改成毛玻璃膠囊(`UIVisualEffectView` + 圓角)
- 結果切換用 fade 動畫,避免閃爍

**Center 區**
- 4 角檢視框 reticle(畫面正中,約 200×200 pt,白色細線、~30% opacity)
- 呼應 app icon 的視覺語言;告訴使用者「對準這裡會被辨識」
- 高信心動態 pulse **不在這次範圍**

**Bottom 區**
- 對稱 top 的底部漸層遮罩
- GPS 狀態 chip(左下,毛玻璃膠囊):`📍 已定位` / `📍 定位中` / `🚫 無位置權限`
- 快門按鈕重做:外環 88 pt + 內實心圓 72 pt;按下時內圓彈性縮成 64 pt(類 iOS 內建相機 app 的觸感)

**改動檔案**
- `ViewController.swift`(主要)— 加 5 個 UI 元件 + fade animation helper + GPS 狀態同步
- `Main.storyboard` — 移除現有 label,全部改程式建立

**不在這次範圍**
- 最近一筆記錄縮圖預覽(右下)— 需 SwiftData query,留下次
- 記錄總數 badge — 同上
- reticle 高信心動態 pulse

- 出處:Stage 5 完成後使用者反饋「首頁進去更精緻」(2026-05),plan 已對齊但尚未動工
- Commit:單一 commit `Stage 6: 相機首頁視覺改版`

### 換成 Landmark 專用 Core ML 模型
目前 `VNClassifyImageRequest` 輸出 building / tower / church 這類通用標籤,要拿到具名地標(101、Eiffel Tower)需要換成 landmark 訓練的 `.mlmodel`。
- 出處:README「替換成地標模型」章節
- 改動點:`CaptureClassifier.swift` 把 `VNClassifyImageRequest` 換成 `VNCoreMLRequest`;即時 HUD(`ViewController.swift`)是否一起換要評估效能與發熱

### 高信心時跳過確認頁
目前每張都跳確認頁,在景點連拍時會煩。當「附近 POI 距離很近 + 影像 ML 信心很高」時直接存,降低摩擦。
- 出處:Stage 5 設計時刻意延後,等實際使用過再定門檻
- 待決:門檻值(距離幾 m / 信心幾 %)、跳過時的視覺回饋(toast?)

### MKLocalSearch 半徑可調
目前 `PlaceLookup.swift` 寫死 100 m。不同場景(室內 / 大型景點 / 鬧區)效果差很多。
- 出處:Stage 5 commit 後的後續討論
- 想法:Settings 頁開放使用者調,或依當下定位精度自動縮放

### 候選結果快取
短時間在同一地點反覆拍時,不重複打 `MKLocalSearch` / `CLGeocoder`(也省電)。
- 出處:Stage 5 plan「不在這次範圍」
- 待決:cache key(座標四捨五入到幾位小數)、TTL

### 連拍 / 批次確認
按住快門連拍時,改用 batch 確認頁(一次給多張),而不是每張跳一次。
- 出處:Stage 5 plan「不在這次範圍」
- 跟「高信心 skip」可能會合併成同一個流程設計

---

## 不做(已決定放棄)

(目前無)
