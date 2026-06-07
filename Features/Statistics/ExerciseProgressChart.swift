import SwiftUI
import Charts

struct ExerciseProgressChart: View {
    let dataPoints: [VolumeDataPoint]
    let metric: StatisticsMetric
    let accentColor: Color

    // Optional: Highlight-Marker für den letzten Datenpunkt
    private var lastPoint: VolumeDataPoint? { dataPoints.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dataPoints.isEmpty {
                emptyStateView
            } else {
                chartView
            }
        }
    }

    // MARK: - Chart View
    private var chartView: some View {
        Chart(dataPoints) { point in
            // Flächendiagramm als Füllung
            AreaMark(
                x: .value("Datum", point.date),
                yStart: .value("Min", yDomain.lowerBound),
                yEnd: .value(metric.rawValue, point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [accentColor.opacity(0.35), accentColor.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Linie über dem Bereich
            LineMark(
                x: .value("Datum", point.date),
                y: .value(metric.rawValue, point.value)
            )
            .foregroundStyle(accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            // Punkt-Marker
            PointMark(
                x: .value("Datum", point.date),
                y: .value(metric.rawValue, point.value)
            )
            .foregroundStyle(accentColor)
            .symbolSize(dataPoints.count > 10 ? 20 : 35)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: adaptiveStride)) { value in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(Color.textSecondary)
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yAxisLabel(v))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
        }
        .frame(height: 200)
        .chartXScale(range: .plotDimension(padding: 15))
        .chartYScale(domain: yDomain)
        .clipped()
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(Color.textSecondary)
            Text("Noch keine Daten")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Text("Absolviere Workouts mit dieser Übung, um Fortschritte zu sehen.")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Helpers
    private var adaptiveStride: Int {
        // Weniger Labels bei vielen Datenpunkten
        switch dataPoints.count {
        case 0...7:   return 1
        case 8...20:  return 3
        default:      return 7
        }
    }

    private func yAxisLabel(_ value: Double) -> String {
        switch metric {
        case .volume, .maxWeight, .avgWeight:
            return "\(Int(value)) kg"
        case .reps:
            return "\(Int(value))"
        }
    }

    private var yDomain: ClosedRange<Double> {
        guard let minVal = dataPoints.map({ $0.value }).min(),
              let maxVal = dataPoints.map({ $0.value }).max() else {
            return 0...100
        }
        let padding = (maxVal - minVal) * 0.15
        return max(0, minVal - padding)...(maxVal + padding)
    }
}
