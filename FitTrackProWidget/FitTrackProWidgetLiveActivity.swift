//
//  FitTrackProWidgetLiveActivity.swift
//  FitTrackProWidget
//
//  Created by P016324 on 09.06.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FitTrackProWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FitTrackProWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FitTrackProWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FitTrackProWidgetAttributes {
    fileprivate static var preview: FitTrackProWidgetAttributes {
        FitTrackProWidgetAttributes(name: "World")
    }
}

extension FitTrackProWidgetAttributes.ContentState {
    fileprivate static var smiley: FitTrackProWidgetAttributes.ContentState {
        FitTrackProWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FitTrackProWidgetAttributes.ContentState {
         FitTrackProWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FitTrackProWidgetAttributes.preview) {
   FitTrackProWidgetLiveActivity()
} contentStates: {
    FitTrackProWidgetAttributes.ContentState.smiley
    FitTrackProWidgetAttributes.ContentState.starEyes
}
