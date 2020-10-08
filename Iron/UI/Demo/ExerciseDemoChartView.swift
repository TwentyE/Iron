//
//  ExerciseDemoChartView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 20.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import Charts
import WorkoutDataKit

struct ExerciseDemoChartView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    
    @Environment(\.isEnabled) var isEnabled
    
    var exercise: Exercise
    var measurementType: WorkoutExerciseChartData.MeasurementType
    
    private let xAxisValueFormatter = WorkoutExerciseChartDataGenerator.DateAxisFormatter()
    private let yAxisValueFormatter = DefaultAxisValueFormatter(decimals: 0)

    private var chartData: LineChartData {
        let entries = stride(from: 0, to: 90, by: 5)
            .compactMap { Calendar.current.date(byAdding: .day, value: $0 - Int.random(in: 0...1), to: Date()) }
            .sorted()
            .map { ChartDataEntry(x: dateToValue(date: $0), y: newRandomDemoValue()) }
        
        
        return LineChartData(dataSet: LineChartDataSet(entries: entries, label: measurementType.title))
    }
    
    private var baseValue: Double {
        switch measurementType {
        case .oneRM:
            return WeightUnit.convert(weight: 80, from: .metric, to: settingsStore.weightUnit)
        case .totalWeight:
            return WeightUnit.convert(weight: 1500, from: .metric, to: settingsStore.weightUnit)
        case .totalSets:
            return 5
        case .totalRepetitions:
            return 30
        }
    }
    
    private func newRandomDemoValue() -> Double {
        (baseValue * Double.random(in: 1...1.2)).rounded()
    }
    
    private func dateToValue(date: Date) -> Double {
        return date.timeIntervalSince1970 / (60 * 60)
    }
    
    var body: some View {
        _LineChartView(
            chartData: chartData,
            xAxisValueFormatter: xAxisValueFormatter,
            yAxisValueFormatter: yAxisValueFormatter,
            balloonValueFormatter: nil,
            preCustomization: { chartView, _ in
                chartView.isUserInteractionEnabled = false
                if isEnabled {
                    if #available(iOS 14.0, *) {
                        chartView.tintColor = UIColor(exercise.muscleGroupColor)
                    } else if let cgColor = exercise.muscleGroupColor.cgColor {
                        chartView.tintColor = UIColor(cgColor: cgColor)
                    }
                } else {
                    if #available(iOS 14.0, *) {
                        chartView.tintColor = UIColor(.accentColor)
                    } else if let cgColor = Color.accentColor.cgColor {
                        chartView.tintColor = UIColor(cgColor: cgColor)
                    }
                }
            }
        )
    }
}

#if DEBUG
struct ExerciseDemoChartView_Previews : PreviewProvider {
    static var previews: some View {
        ExerciseDemoChartView(exercise: ExerciseStore.shared.exercises.first(where: { $0.everkineticId == 42 })!, measurementType: .oneRM)
            .mockEnvironment(weightUnit: .metric, isPro: false)
            .previewLayout(.sizeThatFits)
    }
}
#endif
