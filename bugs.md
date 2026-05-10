# Bugs / 踩坑

已知問題與曾經繞過 / 解過的坑。新坑加在最下方,寫上**現象**、**為什麼會發生**、**怎麼處理**。

---

## 已知問題

(目前無)

---

## 解過 / 釐清過的坑

### `MKLocalSearch(request: MKLocalPointsOfInterestRequest)` 看起來像 type mismatch,實際可編譯
**現象**:看到 `MKLocalSearch(request: poiRequest)` 直接傳 `MKLocalPointsOfInterestRequest`,header 又顯示兩個不同型別的 init,直覺以為會 type error。

**實際**:`xcrun swiftc -typecheck -sdk $(xcrun --sdk iphoneos --show-sdk-path) -target arm64-apple-ios17.2 ...` 確認 exit=0,兩種寫法都過。Swift 把 Obj-C 的 `initWithPointsOfInterestRequest:` 也匯入成 `init(request:)` overload。

**結論**:不要看 header 就假定不能編,有疑慮就跑 `swiftc -typecheck` 驗一下。
