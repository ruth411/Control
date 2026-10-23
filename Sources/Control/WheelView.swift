@preconcurrency import AppKit

@MainActor
final class WheelView: NSView {
    private let apps: [NSRunningApplication]
    private let wheelCenter: NSPoint
    private let wheelRadius: CGFloat = 140
    private let iconSize: CGFloat = 64
    private let deadZoneRadius: CGFloat = 30

    static let outerRadius: CGFloat = 140 + 64 / 2 + 30
    private(set) var hoveredIndex: Int?

    var selectedApp: NSRunningApplication? {
        hoveredIndex.map { apps[$0] }
    }

    init(frame: NSRect, apps: [NSRunningApplication], center: NSPoint) {
        self.apps = apps
        wheelCenter = center
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSelection(at point: NSPoint) {
        let dx = point.x - wheelCenter.x
        let dy = point.y - wheelCenter.y
        guard hypot(dx, dy) >= deadZoneRadius else {
            setHoveredIndex(nil)
            return
        }

        let sliceAngle = (2 * CGFloat.pi) / CGFloat(apps.count)
        var adjusted = atan2(dy, dx) - CGFloat.pi / 2 + sliceAngle / 2
        if adjusted < 0 { adjusted += 2 * CGFloat.pi }
        setHoveredIndex(Int(adjusted / sliceAngle) % apps.count)
    }

    override func draw(_ dirtyRect: NSRect) {
        let outerRadius = Self.outerRadius
        let sliceAngle = (2 * CGFloat.pi) / CGFloat(apps.count)

        for (index, app) in apps.enumerated() {
            let angle = CGFloat.pi / 2 + sliceAngle * CGFloat(index)
            let isHovered = index == hoveredIndex
            drawSegment(angle: angle, sliceAngle: sliceAngle, outerRadius: outerRadius, isHovered: isHovered)

            let radius = wheelRadius + (isHovered ? 8 : 0)
            let size = iconSize * (isHovered ? 1.15 : 1)
            let iconCenter = NSPoint(x: wheelCenter.x + cos(angle) * radius, y: wheelCenter.y + sin(angle) * radius)
            app.icon?.draw(in: NSRect(x: iconCenter.x - size / 2, y: iconCenter.y - size / 2, width: size, height: size))
        }
    }

    private func drawSegment(angle: CGFloat, sliceAngle: CGFloat, outerRadius: CGFloat, isHovered: Bool) {
        let innerRadius = wheelRadius - 48
        let segmentGap: CGFloat = 0.025
        let cornerRadius: CGFloat = 12
        let startAngle = angle - sliceAngle / 2 + segmentGap
        let endAngle = angle + sliceAngle / 2 - segmentGap
        let outerStartAngle = startAngle + cornerRadius / outerRadius
        let outerEndAngle = endAngle - cornerRadius / outerRadius
        let innerStartAngle = startAngle + cornerRadius / innerRadius
        let innerEndAngle = endAngle - cornerRadius / innerRadius

        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.move(to: point(on: outerRadius, angle: outerStartAngle))
        path.appendArc(
            withCenter: wheelCenter,
            radius: outerRadius,
            startAngle: outerStartAngle * 180 / .pi,
            endAngle: outerEndAngle * 180 / .pi,
            clockwise: false
        )
        path.curve(
            to: point(on: outerRadius - cornerRadius, angle: endAngle),
            controlPoint1: point(on: outerRadius, angle: endAngle),
            controlPoint2: point(on: outerRadius - cornerRadius, angle: endAngle)
        )
        path.line(to: point(on: innerRadius + cornerRadius, angle: endAngle))
        path.curve(
            to: point(on: innerRadius, angle: innerEndAngle),
            controlPoint1: point(on: innerRadius + cornerRadius, angle: endAngle),
            controlPoint2: point(on: innerRadius, angle: endAngle)
        )
        path.appendArc(
            withCenter: wheelCenter,
            radius: innerRadius,
            startAngle: innerEndAngle * 180 / .pi,
            endAngle: innerStartAngle * 180 / .pi,
            clockwise: true
        )
        path.curve(
            to: point(on: innerRadius + cornerRadius, angle: startAngle),
            controlPoint1: point(on: innerRadius, angle: startAngle),
            controlPoint2: point(on: innerRadius + cornerRadius, angle: startAngle)
        )
        path.line(to: point(on: outerRadius - cornerRadius, angle: startAngle))
        path.curve(
            to: point(on: outerRadius, angle: outerStartAngle),
            controlPoint1: point(on: outerRadius - cornerRadius, angle: startAngle),
            controlPoint2: point(on: outerRadius, angle: startAngle)
        )
        path.close()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(isHovered ? 0.35 : 0.24)
        shadow.shadowBlurRadius = isHovered ? 18 : 12
        shadow.shadowOffset = NSSize(width: 0, height: -4)

        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        NSColor(calibratedWhite: 0.72, alpha: isHovered ? 0.46 : 0.30).setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        let gradientColors = isHovered
            ? [
                NSColor.white.withAlphaComponent(0.58),
                NSColor(calibratedWhite: 0.82, alpha: 0.34)
            ]
            : [
                NSColor.white.withAlphaComponent(0.36),
                NSColor(calibratedWhite: 0.62, alpha: 0.22)
            ]
        NSGradient(colors: gradientColors)?.draw(in: path, angle: 90)

        NSColor.white.withAlphaComponent(isHovered ? 0.76 : 0.42).setStroke()
        path.lineWidth = isHovered ? 2.2 : 1.5
        path.stroke()
    }

    private func point(on radius: CGFloat, angle: CGFloat) -> NSPoint {
        NSPoint(
            x: wheelCenter.x + cos(angle) * radius,
            y: wheelCenter.y + sin(angle) * radius
        )
    }

    private func setHoveredIndex(_ index: Int?) {
        guard hoveredIndex != index else { return }
        hoveredIndex = index
        needsDisplay = true
    }
}
