//
//  FitTrackProWidgetLiveActivity.swift
//  FitTrackProWidget
//

import ActivityKit
import WidgetKit
import SwiftUI



extension Color {
    static let brand = Color.blue // Fallback brand color for widget
}

extension Date {
    var flooredToSecond: Date {
        Date(timeIntervalSinceReferenceDate: floor(self.timeIntervalSinceReferenceDate))
    }
}

struct FitTrackProWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack(spacing: 10) {
                // Header: Icon + Title + Status
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Text(context.attributes.workoutName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if context.state.isPaused {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10, weight: .black))
                            Text("Pausiert")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.green)
                    } else if context.state.isRestTimerActive {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Aktiv")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Huge Timer Section
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        if context.state.isRestTimerActive, let startTime = context.state.lastStartTime {
                            Text("WORKOUT")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color.secondary)
                                .tracking(1.5)
                            let anchor = startTime.addingTimeInterval(-context.state.accumulatedTime).flooredToSecond
                            Text(timerInterval: anchor...anchor.addingTimeInterval(360000), countsDown: false)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .minimumScaleFactor(0.5)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(context.state.isRestTimerActive ? "SATZPAUSE" : "DAUER")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color.secondary)
                            .tracking(1.5)
                        
                        if context.state.isPaused {
                            Text(formattedTime(context.state.accumulatedTime))
                                .font(.system(size: 68, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .multilineTextAlignment(.trailing)
                        } else if context.state.isRestTimerActive, let rawRestTargetTime = context.state.restTargetTime {
                            let restTargetTime = rawRestTargetTime.flooredToSecond
                            let startDate = min(Date().flooredToSecond, restTargetTime)
                            Text(timerInterval: startDate...restTargetTime, countsDown: true)
                                .font(.system(size: 68, weight: .black, design: .rounded))
                                .foregroundColor(.green)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .multilineTextAlignment(.trailing)
                        } else if let startTime = context.state.lastStartTime {
                            let anchor = startTime.addingTimeInterval(-context.state.accumulatedTime).flooredToSecond
                            Text(timerInterval: anchor...anchor.addingTimeInterval(360000), countsDown: false)
                                .font(.system(size: 68, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .offset(x: -10)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            // Using system background to adapt to light/dark automatically
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("Pausiert")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        if context.state.isPaused {
                            Text(formattedTime(context.state.accumulatedTime))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        } else if context.state.isRestTimerActive, let restTargetTime = context.state.restTargetTime {
                            Text(timerInterval: Date()...restTargetTime, countsDown: true)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        } else if let startTime = context.state.lastStartTime {
                            let anchor = startTime.addingTimeInterval(-context.state.accumulatedTime).flooredToSecond
                            Text(timerInterval: anchor...anchor.addingTimeInterval(360000), countsDown: false)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .minimumScaleFactor(0.5)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: context.state.isRestTimerActive ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundColor(context.state.isRestTimerActive ? .green : .white)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("Pause")
                        .foregroundColor(.green)
                        .frame(maxWidth: 55, alignment: .trailing)
                } else if context.state.isRestTimerActive, let rawRestTargetTime = context.state.restTargetTime {
                    let restTargetTime = rawRestTargetTime.flooredToSecond
                    let startDate = min(Date().flooredToSecond, restTargetTime)
                    Text(timerInterval: startDate...restTargetTime, countsDown: true)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 55, alignment: .trailing)
                } else if let startTime = context.state.lastStartTime {
                    let anchor = startTime.addingTimeInterval(-context.state.accumulatedTime).flooredToSecond
                    Text(timerInterval: anchor...anchor.addingTimeInterval(360000), countsDown: false)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 55, alignment: .trailing)
                }
            } minimal: {
                Image(systemName: context.state.isRestTimerActive ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundColor(context.state.isRestTimerActive ? .green : .white)
            }
            .widgetURL(URL(string: "fittrackpro://active-workout"))
            .keylineTint(.white)
        }
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "00:00"
    }
}
