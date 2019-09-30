//
//  TimerBannerView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 14.08.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct TimerBannerView: View {
    @EnvironmentObject var restTimerStore: RestTimerStore
    
    @ObservedObject var training: Training

    @ObservedObject private var refresher = Refresher()
    
    @State private var activeSheet: SheetType?

    private enum SheetType: Identifiable {
        case restTimer
        case editTime
        
        var id: Self { self }
    }

    private let trainingTimerDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    private var closeSheetButton: some View {
        Button("Close") {
            self.activeSheet = nil
        }
    }
    
    private var editTimeSheet: some View {
        NavigationView {
            EditCurrentTrainingTimeView(training: training)
                .navigationBarTitle("Workout Duration", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
        }
    }
    
    private var restTimerSheet: some View {
        NavigationView {
            RestTimerView().environmentObject(self.restTimerStore)
                .navigationBarTitle("Rest Timer", displayMode: .inline)
                .navigationBarItems(leading: closeSheetButton)
        }
    }
    
    var body: some View {
        HStack {
            Button(action: {
                self.activeSheet = .editTime
            }) {
                HStack {
                    Image(systemName: "clock")
                    Text(trainingTimerDurationFormatter.string(from: training.safeDuration) ?? "")
                        .font(Font.body.monospacedDigit())
                }
                .padding()
            }

            Spacer()

            Button(action: {
                self.activeSheet = .restTimer
            }) {
                HStack {
                    Image(systemName: "timer")
                    restTimerStore.restTimerRemainingTime.map({
                        Text(restTimerDurationFormatter.string(from: $0.rounded(.up)) ?? "")
                            .font(Font.body.monospacedDigit())
                    })
                }
                .padding()
            }
        }
        .background(VisualEffectView(effect: UIBlurEffect(style: .systemMaterial)))
        .sheet(item: $activeSheet) { sheet in
            if sheet == .editTime {
                self.editTimeSheet
            } else if sheet == .restTimer {
                self.restTimerSheet
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in self.refresher.refresh() }
    }
}

#if DEBUG
struct TimerBannerView_Previews: PreviewProvider {
    static var previews: some View {
        if RestTimerStore.shared.restTimerRemainingTime == nil {
            RestTimerStore.shared.restTimerStart = Date()
            RestTimerStore.shared.restTimerDuration = 10
        }
        return TimerBannerView(training: mockCurrentTraining)
            .environmentObject(RestTimerStore.shared)
    }
}
#endif
