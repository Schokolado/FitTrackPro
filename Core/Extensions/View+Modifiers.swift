import Charts
import SwiftUI

// MARK: - Chart X-Axis Edge Helper

enum ChartAxisHelper {
    /// Aligns edge X-axis labels inward so outer labels are never clipped without squishing the plot.
    static func edgeSafeAnchor(for value: AxisValue) -> UnitPoint {
        guard value.count > 1 else { return .top }
        if value.index == 0 { return .topLeading }
        if value.index == value.count - 1 { return .topTrailing }
        return .top
    }
}

extension View {
    /// Configures a date-based X-axis with inward-anchored edge labels and modest plot padding.
    func edgeSafeDateXAxis(
        values: AxisMarkValues = .automatic(desiredCount: 4),
        format: Date.FormatStyle,
        showGridLines: Bool = true
    ) -> some View {
        self
            .chartXScale(range: .plotDimension(padding: 12))
            .chartXAxis {
                AxisMarks(values: values) { value in
                    if showGridLines {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                    }
                    AxisValueLabel(
                        anchor: ChartAxisHelper.edgeSafeAnchor(for: value),
                        collisionResolution: .automatic
                    ) {
                        if let date = value.as(Date.self) {
                            Text(date, format: format)
                                .font(.caption2)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
    }
}

// MARK: - Card Style Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.backgroundCard)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonModifier: ViewModifier {
    var backgroundColor: Color = .brand

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

extension View {
    func primaryButtonStyle(backgroundColor: Color = .brand) -> some View {
        self.modifier(PrimaryButtonModifier(backgroundColor: backgroundColor))
    }
}
