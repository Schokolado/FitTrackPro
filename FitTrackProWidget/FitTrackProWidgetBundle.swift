//
//  FitTrackProWidgetBundle.swift
//  FitTrackProWidget
//
//  Created by P016324 on 09.06.26.
//

import WidgetKit
import SwiftUI

@main
struct FitTrackProWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitTrackProWidget()
        FitTrackProWidgetControl()
        FitTrackProWidgetLiveActivity()
    }
}
