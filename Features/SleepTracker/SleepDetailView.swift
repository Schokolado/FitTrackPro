import SwiftUI
import Charts

struct SleepDetailView: View {
    let entry: SleepChartDataPoint
    
    // Helper to format minutes to "1h 30m"
    private func formatMinutes(_ totalMinutes: Double) -> String {
        let h = Int(totalMinutes) / 60
        let m = Int(totalMinutes) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Total Duration Header
                VStack(spacing: 8) {
                    Text("Gesamtschlaf")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    let hours = Int(entry.durationHours)
                    let minutes = Int((entry.durationHours - Double(hours)) * 60)
                    
                    Text("\(hours)h \(minutes)m")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.indigo)
                    
                    Text(entry.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                    HStack(spacing: 6) {
                        Image(systemName: entry.source == "HealthKit" ? "heart.fill" : "hand.draw.fill")
                            .foregroundColor(entry.source == "HealthKit" ? .red : .orange)
                        Text(entry.source == "HealthKit" ? "Importiert über Apple Health" : "Manuell hinzugefügt")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding(.top, 20)
                
                if let phases = entry.phases, phases.hasDetailedPhases {
                    // Apple Health Style Horizontal Stacked Bar
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Schlafphasen")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Stacked Bar Chart
                        Chart {
                            if phases.awakeMinutes > 0 {
                                BarMark(
                                    x: .value("Dauer", phases.awakeMinutes),
                                    y: .value("Typ", "Phasen")
                                )
                                .foregroundStyle(Color.orange.gradient)
                                .annotation(position: .overlay, alignment: .center) {
                                    if phases.awakeMinutes > 15 {
                                        Text("Wach").font(.caption2).foregroundColor(.white).bold()
                                    }
                                }
                            }
                            if phases.remMinutes > 0 {
                                BarMark(
                                    x: .value("Dauer", phases.remMinutes),
                                    y: .value("Typ", "Phasen")
                                )
                                .foregroundStyle(Color.teal.gradient)
                                .annotation(position: .overlay, alignment: .center) {
                                    if phases.remMinutes > 15 {
                                        Text("REM").font(.caption2).foregroundColor(.white).bold()
                                    }
                                }
                            }
                            if phases.coreMinutes > 0 {
                                BarMark(
                                    x: .value("Dauer", phases.coreMinutes),
                                    y: .value("Typ", "Phasen")
                                )
                                .foregroundStyle(Color.blue.gradient)
                                .annotation(position: .overlay, alignment: .center) {
                                    if phases.coreMinutes > 15 {
                                        Text("Kern").font(.caption2).foregroundColor(.white).bold()
                                    }
                                }
                            }
                            if phases.deepMinutes > 0 {
                                BarMark(
                                    x: .value("Dauer", phases.deepMinutes),
                                    y: .value("Typ", "Phasen")
                                )
                                .foregroundStyle(Color.indigo.gradient)
                                .annotation(position: .overlay, alignment: .center) {
                                    if phases.deepMinutes > 15 {
                                        Text("Tief").font(.caption2).foregroundColor(.white).bold()
                                    }
                                }
                            }
                            if phases.unspecifiedMinutes > 0 {
                                BarMark(
                                    x: .value("Dauer", phases.unspecifiedMinutes),
                                    y: .value("Typ", "Phasen")
                                )
                                .foregroundStyle(Color.purple.gradient)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartLegend(.hidden)
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                        
                        // Legend and values list
                        VStack(spacing: 0) {
                            PhaseRow(title: "Wach", color: .orange, minutes: phases.awakeMinutes)
                            Divider().padding(.leading, 40)
                            PhaseRow(title: "REM-Schlaf", color: .teal, minutes: phases.remMinutes)
                            Divider().padding(.leading, 40)
                            PhaseRow(title: "Kernschlaf", color: .blue, minutes: phases.coreMinutes)
                            Divider().padding(.leading, 40)
                            PhaseRow(title: "Tiefschlaf", color: .indigo, minutes: phases.deepMinutes)
                            if phases.unspecifiedMinutes > 0 {
                                Divider().padding(.leading, 40)
                                PhaseRow(title: "Schlafend", color: .purple, minutes: phases.unspecifiedMinutes)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.backgroundSecondary)
                        )
                        .padding(.horizontal)
                        
                        // Sleep Sessions List
                        if !phases.sessions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Schlafzeiten")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(phases.sessions.enumerated()), id: \.element.id) { index, session in
                                        if index > 0 {
                                            Divider().padding(.leading, 40)
                                        }
                                        SessionRow(session: session)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.backgroundSecondary)
                                )
                                .padding(.horizontal)
                            }
                            .padding(.top, 8)
                        }
                    }
                } else {
                    // Fallback for manual or unsupported entries
                    VStack(spacing: 16) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                        
                        Text("Keine Phasendaten verfügbar")
                            .font(.headline)
                        
                        Text("Für diesen Eintrag liegen keine detaillierten Schlafphasen vor. Dies ist normal für manuelle Einträge oder wenn Apple Health keine detaillierten Phasen aufgezeichnet hat.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.backgroundSecondary)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Schlafdetails")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PhaseRow: View {
    let title: LocalizedStringKey
    let color: Color
    let minutes: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color.gradient)
                .frame(width: 12, height: 12)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            let h = Int(minutes) / 60
            let m = Int(minutes) % 60
            if minutes > 0 {
                Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                    .font(.body.bold())
                    .foregroundColor(.secondary)
            } else {
                Text("0m")
                    .font(.body)
                    .foregroundColor(Color.secondary.opacity(0.5))
            }
        }
        .padding()
    }
}

private struct SessionRow: View {
    let session: SleepSession
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: session.durationMinutes > 180 ? "moon.zzz.fill" : "sun.max.fill")
                .foregroundColor(session.durationMinutes > 180 ? .indigo : .orange)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                let sessionType: LocalizedStringKey = session.durationMinutes > 180 ? "Hauptschlaf" : "Nickerchen"
                Text(sessionType)
                    .font(.body)
                
                HStack(spacing: 4) {
                    Text(session.startDate, style: .time)
                    Text("-")
                    Text(session.endDate, style: .time)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            let h = Int(session.durationMinutes) / 60
            let m = Int(session.durationMinutes) % 60
            Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                .font(.body.bold())
                .foregroundColor(.primary)
        }
        .padding()
    }
}
