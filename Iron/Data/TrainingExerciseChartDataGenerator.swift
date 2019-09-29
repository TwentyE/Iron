//
//  TrainingExerciseChartDataGenerator.swift
//  Rhino Fit
//
//  Created by Karim Abou Zeid on 16.09.18.
//  Copyright © 2018 Karim Abou Zeid Software. All rights reserved.
//

import CoreData
import Charts

struct TrainingExerciseChartDataGenerator {

    private var exercise: Exercise
    private var trainingExerciseHistory: [TrainingExercise]

    init(context: NSManagedObjectContext, exercise: Exercise) {
        self.exercise = exercise
        self.trainingExerciseHistory = (try? context.fetch(TrainingExercise.historyFetchRequest(of: exercise.id, until: Date()))) ?? []
    }

    enum MeasurementType: String, CaseIterable {
        case oneRM
        case totalWeight
        case totalSets
        case totalRepetitions

        var title: String {
            switch self {
            case .oneRM:
                return "1RM"
            case .totalWeight:
                return "Total Weight"
            case .totalSets:
                return "Total Sets"
            case .totalRepetitions:
                return "Total Repetitions"
            }
        }
    }

    enum TimeFrame: CaseIterable {
        case month
        case threeMonths
        case year
        case all

        var title: String {
            switch self {
            case .month:
                return "Month"
            case .threeMonths:
                return "3 Months"
            case .year:
                return "Year"
            case .all:
                return "All"
            }
        }

        var filter: (TrainingExercise) -> Bool {
            switch self {
            case .month:
                return {
                    guard let start = $0.training?.start else { return false }
                    return start >= Calendar.current.date(byAdding: .month, value: -1,  to: Date())!
                }
            case .threeMonths:
                return {
                    guard let start = $0.training?.start else { return false }
                    return start >= Calendar.current.date(byAdding: .month, value: -3,  to: Date())!
                }
            case .year:
                return {
                    guard let start = $0.training?.start else { return false }
                    return start >= Calendar.current.date(byAdding: .year, value: -1,   to: Date())!
                }
            case .all:
                return {
                    guard let _ = $0.training?.start else { return false }
                    return true
                }
            }
        }
    }

    private let xAxisValueFormatter = DateAxisFormatter()
    private let yAxisValueFormatter = DefaultAxisValueFormatter(decimals: 0)

    func xAxisValueFormatter(for measurementType: MeasurementType, weightUnit: WeightUnit) -> IAxisValueFormatter {
        xAxisValueFormatter
    }
    
    func yAxisValueFormatter(for measurementType: MeasurementType, weightUnit: WeightUnit) -> IAxisValueFormatter {
        yAxisValueFormatter
    }
    
    func ballonValueFormatter(for measurementType: MeasurementType, weightUnit: WeightUnit) -> BalloonValueFormatter {
        switch measurementType {
        case .oneRM, .totalWeight:
            return DateBalloonValueFormatter(append: weightUnit.abbrev)
        case .totalSets, .totalRepetitions:
            return DateBalloonValueFormatter(append: "×")
        }
    }

    func chartData(for measurementType: MeasurementType, timeFrame: TimeFrame, weightUnit: WeightUnit, maxRepetitionsFor1rm: Int) -> LineChartData {
        let dataSet = generateChartDataSet(
            trainingExercises: trainingExerciseHistory.filter(timeFrame.filter),
            trainingExerciseToValue: trainingExerciseToValue(for: measurementType, weightUnit: weightUnit, maxRepetitionsFor1rm: maxRepetitionsFor1rm),
            label: measurementType.title)
        return LineChartData(dataSet: dataSet)
    }

    private func trainingExerciseToValue(for measurementType: MeasurementType, weightUnit: WeightUnit, maxRepetitionsFor1rm: Int) -> TrainingExerciseToValue {
        switch measurementType {
        case .oneRM:
            return {
                $0.trainingSets?
                    .compactMap { $0 as? TrainingSet }
                    .compactMap { trainingSet in
                        guard trainingSet.repetitions > 0 else { return nil }
                        guard trainingSet.repetitions <= maxRepetitionsFor1rm else { return nil }
                        assert(trainingSet.repetitions < 37) // we don't want to divide with 0 or get negative values
                        return Double(trainingSet.weight) * (36 / (37 - Double(trainingSet.repetitions))) // Brzycki 1RM formula
                    }
                    .max()
                    .map { WeightUnit.convert(weight: $0, from: .metric, to: weightUnit)}
            }
        case .totalWeight:
            return  { $0.totalCompletedWeight.map { WeightUnit.convert(weight: Double($0), from: .metric, to: weightUnit) } }
        case .totalSets:
            return { $0.numberOfCompletedSets.map { Double($0) } }
        case .totalRepetitions:
            return  { $0.numberOfCompletedRepetitions.map { Double($0) } }
        }
    }

    private typealias TrainingExerciseToValue = (TrainingExercise) -> Double?
    private func generateChartDataSet(trainingExercises: [TrainingExercise], trainingExerciseToValue: TrainingExerciseToValue, label: String?) -> LineChartDataSet {
        // Define chart entries
        let entries: [ChartDataEntry] = trainingExercises
            .reversed()  // fixes a strange bug, where the chart line is not drawn
            .compactMap { trainingExercise in
                guard let start = trainingExercise.training?.start else { return nil }
                guard let yValue = trainingExerciseToValue(trainingExercise) else { return nil }
                let xValue = dateToValue(date: start)
                return ChartDataEntry(x: xValue, y: yValue)
            }

        return LineChartDataSet(entries: entries, label: label)
    }

    // MARK: - Formatter
    class DateAxisFormatter: IAxisValueFormatter {
        let dateFormatter: DateFormatter
        let yearDateFormatter: DateFormatter

        weak var chartView: LineChartView!

        init() {
            dateFormatter = DateFormatter()
            yearDateFormatter = DateFormatter()
            dateFormatter.doesRelativeDateFormatting = true
            yearDateFormatter.doesRelativeDateFormatting = true
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
            yearDateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMd")
        }

        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            let date = valueToDate(value: value)
            if Calendar.current.compare(date, to: Date(), toGranularity: .year) == .orderedSame {
                return dateFormatter.string(from: date)
            }
            return yearDateFormatter.string(from: date)
        }
    }

    class DateBalloonValueFormatter: BalloonValueFormatter {
        let yAxisValueFormatter = DefaultAxisValueFormatter(formatter: {
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            formatter.usesGroupingSeparator = true
            return formatter
        }())
        let dateFormatter: DateFormatter
        let yearDateFormatter: DateFormatter
        let append: String?

        init(append: String?) {
            self.append = append
            dateFormatter = DateFormatter()
            yearDateFormatter = DateFormatter()
            dateFormatter.doesRelativeDateFormatting = true
            yearDateFormatter.doesRelativeDateFormatting = true
            dateFormatter.setLocalizedDateFormatFromTemplate("MMMdjmm")
            yearDateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMdjmm")
        }

        func stringForXValue(x: Double) -> String? {
            let date = valueToDate(value: x)
            if Calendar.current.compare(valueToDate(value: x), to: Date(), toGranularity: .year) == .orderedSame {
                return dateFormatter.string(from: date)
            }
            return yearDateFormatter.string(from: date)
        }

        func stringForYValue(y: Double) -> String? {
            return yAxisValueFormatter.stringForValue(y, axis: nil) + (append ?? "")
        }
    }
    
    public static func dateEqualsValue(date: Date, value: Double) -> Bool {
        return dateToValue(date: date) == value
    }
}

private func dateToValue(date: Date) -> Double {
    return date.timeIntervalSince1970 / (60 * 60)
}

private func valueToDate(value: Double) -> Date {
    return Date(timeIntervalSince1970: value * (60 * 60))
}
