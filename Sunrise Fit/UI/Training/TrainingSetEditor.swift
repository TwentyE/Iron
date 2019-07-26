//
//  TrainingSetEditor.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 29.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import Combine

private class TrainingSetViewModel : BindableObject {
    var willChange = PassthroughSubject<Void, Never>()
    
    var trainingSet: TrainingSet
    var weightUnit: WeightUnit
    var weightInput: Double {
        set {
            trainingSet.weight = max(min(WeightUnit.convert(weight: newValue, from: weightUnit, to: .metric), TrainingSet.MAX_WEIGHT), 0)
        }
        get {
            WeightUnit.convert(weight: trainingSet.weight, from: .metric, to: weightUnit)
        }
    }
    var repetitionsInput: Double {
        set {
            trainingSet.repetitions = Int16(max(min(newValue, Double(TrainingSet.MAX_REPETITIONS)), 0))
        }
        get {
            Double(trainingSet.repetitions)
        }
    }
    
    init(trainingSet: TrainingSet, weightUnit: WeightUnit) {
        self.trainingSet = trainingSet
        self.weightUnit = weightUnit
    }
}

private enum KeyboardType {
    case weight
    case repetitions
    case none
}

struct TrainingSetEditor : View {
    @EnvironmentObject var trainingsDataStore: TrainingsDataStore
    @ObjectBinding private var trainingSetViewModel: TrainingSetViewModel
    @State private var showMoreSheet = false
    @State private var showKeyboard: KeyboardType = .none
    @State private var alwaysShowDecimalSeparator = false
    @State private var minimumFractionDigits = 0 // will be set in onAppear()
    private var maximumFractionDigits = 3

    var onDone: () -> Void = {}
    
    init(trainingSet: TrainingSet, weightUnit: WeightUnit, onDone: @escaping () -> Void = {}) {
        trainingSetViewModel = TrainingSetViewModel(trainingSet: trainingSet, weightUnit: weightUnit)
        self.onDone = onDone
    }

    private var weightNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.alwaysShowsDecimalSeparator = alwaysShowDecimalSeparator
        return formatter
    }
    
    private func textButton(label: Text, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                label
                    .padding(6)
                    .transition(.opacity)
                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .foregroundColor(color)
        )
    }
    
    private var moreButton: some View {
        textButton(label: Text("More").foregroundColor(.secondary), color: UIColor.systemGray4.swiftUIColor, action: { self.showMoreSheet = true })
    }
    
    private var doneButton: some View {
        textButton(label: Text(trainingSetViewModel.trainingSet.isCompleted ? "Ok" : "Complete Set").foregroundColor(.white), color: .accentColor, action: {
            self.onDone()
            if self.showKeyboard == .repetitions {
                self.showKeyboard = .weight
            }
        })
    }
    
    private var nextButton: some View {
        textButton(label: Text("Next").foregroundColor(.white), color: .accentColor, action: { self.showKeyboard = .repetitions })
    }
        
    private var hideKeyboardButton: some View {
        Button(action: {
            withAnimation {
                self.showKeyboard = .none
            }
        }) {
            HStack {
                Spacer()
                ZStack {
                    Text("More") // placeholder for button size
                        .foregroundColor(.clear)
                        .padding(6)
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.compact.down")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .foregroundColor(UIColor.systemGray4.swiftUIColor)
        )
    }
    
    private var buttons: some View {
        HStack(spacing: 0) {
            moreButton
                .padding()
            
            doneButton
                .padding()
        }
    }
    
    private var keyboardButtons: some View {
        HStack(spacing: 0) {
            hideKeyboardButton
                .padding()
            
            if showKeyboard == .weight {
                nextButton
                    .padding()
            } else {
                doneButton
                    .padding()
            }
        }
    }
    
    private var weightDragger: some View {
        Dragger(
            value: $trainingSetViewModel.weightInput,
            numberFormatter: weightNumberFormatter,
            unit: Text(trainingSetViewModel.weightUnit.abbrev),
            stepSize: trainingSetViewModel.weightUnit.barbellIncrement,
            minValue: 0,
            maxValue: WeightUnit.convert(weight: TrainingSet.MAX_WEIGHT, from: .metric, to: trainingSetViewModel.weightUnit),
            showCursor: showKeyboard == .weight,
            onDragStep: { _ in
                self.alwaysShowDecimalSeparator = false
                self.minimumFractionDigits = self.trainingSetViewModel.weightUnit.defaultFractionDigits
            },
            onDragCompleted: {
                self.alwaysShowDecimalSeparator = false
                self.minimumFractionDigits = 0
            },
            onTextTapped: {
                withAnimation {
                    self.showKeyboard = .weight
                }
            })
    }
    
    private var repetitionsDragger: some View {
        Dragger(
            value: $trainingSetViewModel.repetitionsInput,
            unit: Text("reps"),
            minValue: 0,
            maxValue: Double(TrainingSet.MAX_REPETITIONS),
            showCursor: showKeyboard == .repetitions,
            onTextTapped: {
                withAnimation {
                    self.showKeyboard = .repetitions
                }
        })
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                weightDragger
                repetitionsDragger
            }
            .padding([.top])
            
            if showKeyboard == .none {
                buttons
            } else {
                keyboardButtons
            }
            
            if showKeyboard == .weight {
                NumericKeyboard(
                    value: $trainingSetViewModel.weightInput,
                    alwaysShowDecimalSeparator: $alwaysShowDecimalSeparator,
                    minimumFractionDigits: $minimumFractionDigits,
                    maximumFractionDigits: maximumFractionDigits
                )
            } else if showKeyboard == .repetitions {
                NumericKeyboard(
                    value: $trainingSetViewModel.repetitionsInput,
                    alwaysShowDecimalSeparator: .constant(false),
                    minimumFractionDigits: .constant(0),
                    maximumFractionDigits: 0
                )
            }
        }
        .drawingGroup() // fixes visual bug with show/hide animation of this view
        .gesture(DragGesture()
            .onEnded({ drag in
                if drag.predictedEndTranslation.height > 100 {
                    withAnimation {
                        self.showKeyboard = .none
                    }
                }
            })
        )
        .sheet(isPresented: $showMoreSheet) {
            MoreView(trainingSet: self.trainingSetViewModel.trainingSet)
        }
    }
}

private struct MoreView: View {
    var trainingSet: TrainingSet
    
    // TODO: move these properties to TrainingSet in CoreData
    @State private var trainingSetTag: String? = nil
    @State private var trainingSetComment: String = ""
    @State private var trainingSetRPE: Double? = nil
    
    private let RPEs = stride(from: 7, through: 10, by: 0.5).reversed()
    private let tags = ["Warm up", "Dropset", "Failure"]
    
    private func titleForRPE(_ RPE: Double) -> String? {
        switch RPE {
        case 7:
            return "You could do 3 more repetitions."
        case 7.5:
            return "You could do 2-3 more repetitions."
        case 8:
            return "You could do 2 more repetitions."
        case 8.5:
            return "You could do 1-2 more repetitions."
        case 9:
            return "You could do 1 more repetitions."
        case 9.5:
            return "You couldn't do more repetitions, but possibly you could've increased the weight."
        case 10:
            return "You couldn't do more repetitions."
        default:
            return nil
        }
    }
    
    private func colorForTag(_ tag: String) -> Color? {
        switch tag {
        case "Warm up":
            return .yellow
        case "Dropset":
            return .purple
        case "Failure":
            return .red
        default:
            return nil
        }
    }
    
    private func tagButton(tag: String) -> some View {
        Button(action: {
            if self.trainingSetTag == tag {
                self.trainingSetTag = nil
            } else {
                self.trainingSetTag = tag
            }
        }) {
            HStack {
                Image(systemName: "circle.fill")
                    .imageScale(.small)
                    .foregroundColor(self.colorForTag(tag))
                Text(tag)
                Spacer()
                if self.trainingSetTag == tag {
                    Image(systemName: "checkmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func RPEButton(RPE: Double) -> some View {
        Button(action: {
            if self.trainingSetRPE == RPE {
                self.trainingSetRPE = nil
            } else {
                self.trainingSetRPE = RPE
            }
        }) {
            HStack {
                Text(String(format: "%.1f", RPE))
                Text(self.titleForRPE(RPE) ?? "")
                    .lineLimit(nil)
                    .foregroundColor(.secondary)
                Spacer()
                if self.trainingSetRPE == RPE {
                    Image(systemName: "checkmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        List {
            Section(header: Text("Tag".uppercased())) {
                ForEach(tags, id: \.self) { tag in
                    self.tagButton(tag: tag)
                }
            }
            
            Section(header: Text("Comment".uppercased())) {
                TextField("Comment", text: $trainingSetComment, onEditingChanged: { _ in }, onCommit: {})
            }
            
            Section(header: Text("RPE (Rating of Perceived Exertion)")) {
                ForEach(RPEs, id: \.self) { RPE in
                    self.RPEButton(RPE: RPE)
                }
            }
        }
        .listStyle(.grouped)
    }
}

#if DEBUG
struct TrainingSetEditor_Previews : PreviewProvider {
    static var previews: some View {
        return Group {
            TrainingSetEditor(trainingSet: mockTrainingSet, weightUnit: .metric)
                .environmentObject(mockTrainingsDataStore)
                .previewDisplayName("Metric")
                .previewLayout(.sizeThatFits)
            
            TrainingSetEditor(trainingSet: mockTrainingSet, weightUnit: .imperial)
                .environmentObject(mockTrainingsDataStore)
                .previewDisplayName("Imperial")
                .previewLayout(.sizeThatFits)
            
            MoreView(trainingSet: mockTrainingSet)
                .previewLayout(.sizeThatFits)
                .listStyle(.grouped)
        }
    }
}
#endif