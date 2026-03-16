import SwiftUI

/// The two-arc brand mark — west arc at full opacity, east arc dimmed.
struct ParseMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            ParseArc(westArc: true)
                .stroke(
                    Color.theme.accent.opacity(0.9),
                    style: StrokeStyle(lineWidth: max(0.8, size * 0.022), lineCap: .round)
                )
            ParseArc(westArc: false)
                .stroke(
                    Color.theme.accent.opacity(0.38),
                    style: StrokeStyle(lineWidth: max(0.8, size * 0.022), lineCap: .round)
                )
        }
        .frame(width: size, height: size)
    }
}

private struct ParseArc: Shape {
    let westArc: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 23.0 / 56.0
        // clockwise:false = counterclockwise on screen = passes through west/left side
        // clockwise:true  = clockwise on screen         = passes through east/right side
        p.addArc(
            center: center, radius: radius,
            startAngle: .degrees(-90), endAngle: .degrees(90),
            clockwise: !westArc
        )
        return p
    }
}

#Preview {
    HStack(spacing: 24) {
        ParseMark(size: 16)
        ParseMark(size: 24)
        ParseMark(size: 48)
        ParseMark(size: 72)
    }
    .padding(40)
    .background(Color.theme.background)
}
