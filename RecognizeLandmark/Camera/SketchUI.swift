//
//  SketchUI.swift
//  RecognizeLandmark
//
//  童趣手繪 UI helpers(Stage 6a):色票、字體、抖動 BezierPath、
//  以及對應的 UIView 元件(speech bubble、capsule、reticle、shutter)。
//

import UIKit

// MARK: - Palette / Fonts

enum Sketch {
    static let paper      = UIColor(red: 0.980, green: 0.965, blue: 0.925, alpha: 1.0) // #FAF6EC
    static let ink        = UIColor(red: 0.165, green: 0.122, blue: 0.094, alpha: 1.0) // #2A1F18
    static let accentWarm = UIColor(red: 0.851, green: 0.466, blue: 0.416, alpha: 1.0) // #D9776A
    static let accentCool = UIColor(red: 0.478, green: 0.620, blue: 0.624, alpha: 1.0) // #7A9E9F

    static func font(size: CGFloat, wide: Bool = false) -> UIFont {
        let name = wide ? "MarkerFelt-Wide" : "MarkerFelt-Thin"
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }
}

// MARK: - Seeded RNG(deterministic wobble)

private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max)
    }
    mutating func jitter(_ amplitude: CGFloat) -> CGFloat {
        (next() - 0.5) * 2 * amplitude
    }
}

// MARK: - Sketched paths

enum SketchPath {

    /// 抖動的圓角矩形外框
    static func wobbledRoundedRect(
        in rect: CGRect,
        cornerRadius: CGFloat,
        seed: UInt64 = 42,
        wobble: CGFloat = 1.5,
        edgeSamples: Int = 18,
        arcSamples: Int = 10
    ) -> UIBezierPath {
        var rng = SeededRNG(seed: seed)
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var pts: [CGPoint] = []

        // top edge
        for i in 0..<edgeSamples {
            let t = CGFloat(i) / CGFloat(edgeSamples)
            pts.append(CGPoint(x: rect.minX + r + (rect.width - 2 * r) * t,
                               y: rect.minY))
        }
        // top-right arc
        let trC = CGPoint(x: rect.maxX - r, y: rect.minY + r)
        for i in 0..<arcSamples {
            let a = -CGFloat.pi / 2 + (CGFloat.pi / 2) * CGFloat(i) / CGFloat(arcSamples)
            pts.append(CGPoint(x: trC.x + r * cos(a), y: trC.y + r * sin(a)))
        }
        // right edge
        for i in 0..<edgeSamples {
            let t = CGFloat(i) / CGFloat(edgeSamples)
            pts.append(CGPoint(x: rect.maxX,
                               y: rect.minY + r + (rect.height - 2 * r) * t))
        }
        // bottom-right arc
        let brC = CGPoint(x: rect.maxX - r, y: rect.maxY - r)
        for i in 0..<arcSamples {
            let a = (CGFloat.pi / 2) * CGFloat(i) / CGFloat(arcSamples)
            pts.append(CGPoint(x: brC.x + r * cos(a), y: brC.y + r * sin(a)))
        }
        // bottom edge
        for i in 0..<edgeSamples {
            let t = CGFloat(i) / CGFloat(edgeSamples)
            pts.append(CGPoint(x: rect.maxX - r - (rect.width - 2 * r) * t,
                               y: rect.maxY))
        }
        // bottom-left arc
        let blC = CGPoint(x: rect.minX + r, y: rect.maxY - r)
        for i in 0..<arcSamples {
            let a = CGFloat.pi / 2 + (CGFloat.pi / 2) * CGFloat(i) / CGFloat(arcSamples)
            pts.append(CGPoint(x: blC.x + r * cos(a), y: blC.y + r * sin(a)))
        }
        // left edge
        for i in 0..<edgeSamples {
            let t = CGFloat(i) / CGFloat(edgeSamples)
            pts.append(CGPoint(x: rect.minX,
                               y: rect.maxY - r - (rect.height - 2 * r) * t))
        }
        // top-left arc
        let tlC = CGPoint(x: rect.minX + r, y: rect.minY + r)
        for i in 0..<arcSamples {
            let a = CGFloat.pi + (CGFloat.pi / 2) * CGFloat(i) / CGFloat(arcSamples)
            pts.append(CGPoint(x: tlC.x + r * cos(a), y: tlC.y + r * sin(a)))
        }

        let jittered = pts.map { p in
            CGPoint(x: p.x + rng.jitter(wobble), y: p.y + rng.jitter(wobble))
        }
        let path = UIBezierPath()
        path.move(to: jittered[0])
        for p in jittered.dropFirst() { path.addLine(to: p) }
        path.close()
        return path
    }

    /// 抖動的圓
    static func wobbledCircle(
        center: CGPoint,
        radius: CGFloat,
        seed: UInt64 = 42,
        wobble: CGFloat = 1.5,
        segments: Int = 64
    ) -> UIBezierPath {
        var rng = SeededRNG(seed: seed)
        var pts: [CGPoint] = []
        for i in 0..<segments {
            let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(segments)
            let r = radius + rng.jitter(wobble)
            pts.append(CGPoint(x: center.x + r * cos(a),
                               y: center.y + r * sin(a)))
        }
        let path = UIBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.addLine(to: p) }
        path.close()
        return path
    }

    /// 抖動的 speech bubble:圓角矩形 + 上方三角小尾巴(指向 reticle)
    static func wobbledSpeechBubble(
        in rect: CGRect,
        cornerRadius: CGFloat,
        tailHeight: CGFloat = 10,
        tailWidth: CGFloat = 18,
        seed: UInt64 = 42
    ) -> UIBezierPath {
        let bubbleRect = CGRect(x: rect.minX,
                                y: rect.minY + tailHeight,
                                width: rect.width,
                                height: rect.height - tailHeight)
        let path = wobbledRoundedRect(in: bubbleRect, cornerRadius: cornerRadius, seed: seed)

        var rng = SeededRNG(seed: seed &+ 100)
        let mid = bubbleRect.midX
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: mid - tailWidth / 2 + rng.jitter(0.5),
                              y: bubbleRect.minY + rng.jitter(0.5)))
        tail.addLine(to: CGPoint(x: mid + rng.jitter(0.5),
                                 y: rect.minY + rng.jitter(0.5)))
        tail.addLine(to: CGPoint(x: mid + tailWidth / 2 + rng.jitter(0.5),
                                 y: bubbleRect.minY + rng.jitter(0.5)))
        tail.close()
        path.append(tail)
        return path
    }

    /// 4 角檢視框 reticle:回傳一個 path 包含 4 個 L 形角(每個角故意稍微歪)
    static func reticleBrackets(
        in rect: CGRect,
        bracketLength: CGFloat = 50,
        seed: UInt64 = 42,
        wobble: CGFloat = 1.0
    ) -> UIBezierPath {
        var rng = SeededRNG(seed: seed)
        let path = UIBezierPath()
        let segs = 10

        // 每個 corner:從 (corner.x + L*dx, corner.y) → (corner.x, corner.y) → (corner.x, corner.y + L*dy)
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY),  1,  1), // top-left
            (CGPoint(x: rect.maxX, y: rect.minY), -1,  1), // top-right
            (CGPoint(x: rect.minX, y: rect.maxY),  1, -1), // bottom-left
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1), // bottom-right
        ]
        for (corner, dx, dy) in corners {
            // horizontal arm,從 outer 端往 corner 走
            var pts: [CGPoint] = []
            for i in (0...segs).reversed() {
                let t = CGFloat(i) / CGFloat(segs)
                pts.append(CGPoint(
                    x: corner.x + bracketLength * dx * t + rng.jitter(wobble),
                    y: corner.y + rng.jitter(wobble)
                ))
            }
            // vertical arm,從 corner 往 outer 端走
            for i in 1...segs {
                let t = CGFloat(i) / CGFloat(segs)
                pts.append(CGPoint(
                    x: corner.x + rng.jitter(wobble),
                    y: corner.y + bracketLength * dy * t + rng.jitter(wobble)
                ))
            }
            path.move(to: pts[0])
            for p in pts.dropFirst() { path.addLine(to: p) }
        }
        return path
    }
}

// MARK: - Sketched Capsule(用於 records count chip / GPS chip)

final class SketchedCapsuleView: UIView {
    private let label = UILabel()
    private let seed: UInt64

    init(seed: UInt64 = 42) {
        self.seed = seed
        super.init(frame: .zero)
        setupContent()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupContent() {
        backgroundColor = .clear
        label.font = Sketch.font(size: 14)
        label.textColor = Sketch.ink
        label.textAlignment = .center
        label.numberOfLines = 1
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    func setText(_ text: String) {
        label.text = text
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    override var intrinsicContentSize: CGSize {
        let s = label.intrinsicContentSize
        return CGSize(width: s.width + 28, height: max(32, s.height + 12))
    }

    override func draw(_ rect: CGRect) {
        let inset = rect.insetBy(dx: 1.5, dy: 1.5)
        let path = SketchPath.wobbledRoundedRect(
            in: inset,
            cornerRadius: inset.height / 2,
            seed: seed,
            wobble: 1.0
        )
        Sketch.paper.withAlphaComponent(0.92).setFill()
        path.fill()
        Sketch.ink.setStroke()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.stroke()
    }
}

// MARK: - Sketched Reticle(中央 4 角檢視框)

final class SketchedReticleView: UIView {
    private let seed: UInt64 = 7

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func draw(_ rect: CGRect) {
        let path = SketchPath.reticleBrackets(
            in: rect.insetBy(dx: 4, dy: 4),
            bracketLength: 50,
            seed: seed,
            wobble: 1.0
        )
        Sketch.ink.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

// MARK: - Sketched Speech Bubble(辨識結果)

final class SketchedBubbleView: UIView {
    private let label = UILabel()
    private let seed: UInt64 = 13

    init() {
        super.init(frame: .zero)
        setupContent()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupContent() {
        backgroundColor = .clear
        label.numberOfLines = 0
        label.font = Sketch.font(size: 16, wide: true)
        label.textColor = Sketch.ink
        label.textAlignment = .center
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 18), // 留 tail 空間
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    func setText(_ text: String) {
        // fade transition,避免文字硬切
        UIView.transition(with: label, duration: 0.18, options: .transitionCrossDissolve) {
            self.label.text = text
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let inset = rect.insetBy(dx: 1.5, dy: 1.5)
        let path = SketchPath.wobbledSpeechBubble(
            in: inset,
            cornerRadius: 14,
            tailHeight: 10,
            tailWidth: 18,
            seed: seed
        )
        Sketch.paper.withAlphaComponent(0.94).setFill()
        path.fill()
        Sketch.ink.setStroke()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.stroke()
    }
}

// MARK: - Sketched Shutter(快門按鈕)

final class SketchedShutterView: UIControl {
    private let seedOuter: UInt64 = 23
    private let seedInner: UInt64 = 71

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1.0 : 0.5 }
    }

    override func draw(_ rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2 - 4
        let innerR = outerR * 0.78

        // outer ring(暖色描邊)
        let outerPath = SketchPath.wobbledCircle(center: center, radius: outerR,
                                                 seed: seedOuter, wobble: 1.5)
        Sketch.accentWarm.setStroke()
        outerPath.lineWidth = 4
        outerPath.lineJoinStyle = .round
        outerPath.stroke()

        // inner solid(奶油填 + 棕墨細描邊)
        let innerPath = SketchPath.wobbledCircle(center: center, radius: innerR,
                                                 seed: seedInner, wobble: 1.0)
        Sketch.paper.setFill()
        innerPath.fill()
        Sketch.ink.setStroke()
        innerPath.lineWidth = 1.5
        innerPath.lineJoinStyle = .round
        innerPath.stroke()
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        UIView.animate(withDuration: 0.10, delay: 0, options: [.curveEaseOut]) {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
        return super.beginTracking(touch, with: event)
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        UIView.animate(withDuration: 0.18, delay: 0,
                       usingSpringWithDamping: 0.55, initialSpringVelocity: 0.5,
                       options: [.curveEaseInOut]) {
            self.transform = .identity
        }
        super.endTracking(touch, with: event)
    }

    override func cancelTracking(with event: UIEvent?) {
        self.transform = .identity
        super.cancelTracking(with: event)
    }
}
