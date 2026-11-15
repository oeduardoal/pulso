import SwiftUI

/// Line and area chart over a fixed window of samples. New samples enter on the right and
/// older ones scroll left, so a partially filled window starts mid-chart.
struct SeriesChart: View {
    struct Line {
        let values: [Double]
        let color: Color
        var lineWidth: CGFloat = 2
        var fill = true
    }

    let lines: [Line]
    /// Upper bound of the value axis. Nil scales to the highest value with some headroom.
    var maximum: Double?
    var capacity = Series.capacity
    var gridlines = 3
    let accessibilityLabel: String

    var body: some View {
        Canvas { context, size in
            let top = maximum ?? max(lines.flatMap(\.values).max() ?? 0, 1e-9) * 1.15
            for index in stride(from: 1, through: gridlines, by: 1) {
                let y = size.height * CGFloat(index) / CGFloat(gridlines + 1)
                var grid = Path()
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(Theme.gridline), lineWidth: 1)
            }
            for line in lines where line.values.count > 1 {
                let path = Self.path(line.values, top: top, capacity: capacity, size: size)
                if line.fill, let first = path.first, let last = path.last {
                    var area = Path()
                    area.move(to: CGPoint(x: first.x, y: size.height))
                    path.forEach { area.addLine(to: $0) }
                    area.addLine(to: CGPoint(x: last.x, y: size.height))
                    area.closeSubpath()
                    context.fill(area, with: .color(line.color.opacity(0.2)))
                }
                var stroke = Path()
                stroke.addLines(path)
                context.stroke(stroke, with: .color(line.color), style: StrokeStyle(lineWidth: line.lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    static func path(_ values: [Double], top: Double, capacity: Int, size: CGSize, mirrored: Bool = false) -> [CGPoint] {
        let step = size.width / CGFloat(max(capacity - 1, 1))
        let offset = CGFloat(capacity - values.count) * step
        return values.enumerated().map { index, value in
            let ratio = CGFloat(min(max(value / top, 0), 1))
            return CGPoint(x: offset + CGFloat(index) * step, y: mirrored ? ratio * size.height : size.height * (1 - ratio))
        }
    }
}

/// Download above the midline, upload mirrored below it, as in the network panel.
struct MirroredChart: View {
    let up: [Double]
    let down: [Double]
    let upColor: Color
    let downColor: Color
    let accessibilityLabel: String

    var body: some View {
        Canvas { context, size in
            let top = max((up + down).max() ?? 0, 1) * 1.1
            let half = CGSize(width: size.width, height: size.height / 2)
            var midline = Path()
            midline.move(to: CGPoint(x: 0, y: half.height))
            midline.addLine(to: CGPoint(x: size.width, y: half.height))
            context.stroke(midline, with: .color(.white.opacity(0.25)), lineWidth: 1)

            for (values, color, mirrored) in [(up, upColor, false), (down, downColor, true)] where values.count > 1 {
                let points = SeriesChart.path(values, top: top, capacity: Series.capacity, size: half, mirrored: mirrored)
                    .map { mirrored ? CGPoint(x: $0.x, y: $0.y + half.height) : $0 }
                guard let first = points.first, let last = points.last else { continue }
                var area = Path()
                area.move(to: CGPoint(x: first.x, y: half.height))
                points.forEach { area.addLine(to: $0) }
                area.addLine(to: CGPoint(x: last.x, y: half.height))
                area.closeSubpath()
                context.fill(area, with: .color(color.opacity(0.2)))
                var line = Path()
                line.addLines(points)
                context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: mirrored ? 1.8 : 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }
}

struct RingGauge: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 3
    var track = Color.white.opacity(0.35)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}
