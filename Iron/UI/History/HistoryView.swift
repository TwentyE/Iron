//
//  HistoryView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 22.06.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI
import CoreData

struct HistoryView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @FetchRequest(fetchRequest: HistoryView.fetchRequest) var trainings

    static var fetchRequest: NSFetchRequest<Training> {
        let request: NSFetchRequest<Training> = Training.fetchRequest()
        request.predicate = NSPredicate(format: "\(#keyPath(Training.isCurrentTraining)) != %@", NSNumber(booleanLiteral: true))
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Training.start, ascending: false)]
        return request
    }
    
    @State private var offsetsToDelete: IndexSet?

    var body: some View {
        NavigationView {
            List {
                ForEach(trainings, id: \.objectID) { training in
                    NavigationLink(destination: TrainingDetailView(training: training)
                        .environmentObject(self.settingsStore)
                    ) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(training.displayTitle(in: self.exerciseStore.exercises))
                                    .font(.body)
                                Text("\(Training.dateFormatter.string(from: training.start, fallback: "Unknown date")) for \(Training.durationFormatter.string(from: training.duration, fallback: "Unknown time")!)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                training.comment.map {
                                    Text($0.enquoted)
                                        .lineLimit(1)
                                        .font(Font.caption.italic())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .layoutPriority(1)
                            Spacer()
                            training.muscleGroupImage(in: self.exerciseStore.exercises)
                        }
                    }
                }
                .onDelete { offsets in
                    self.offsetsToDelete = offsets
                }
            }
            .navigationBarItems(trailing: EditButton())
            .actionSheet(item: $offsetsToDelete) { offsets in
                ActionSheet(title: Text("This cannot be undone."), buttons: [
                    .destructive(Text("Delete Workout"), action: {
                        let trainings = self.trainings
                        for i in offsets.sorted().reversed() {
                            self.managedObjectContext.delete(trainings[i])
                        }
                        self.managedObjectContext.safeSave()
                    }),
                    .cancel()
                ])
            }
            .placeholder(show: trainings.isEmpty,
                         Text("Your finished workouts will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
            )
            .navigationBarTitle(Text("History"))
        }
    }
}

#if DEBUG
struct HistoryView_Previews : PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(SettingsStore.mockMetric)
            .environmentObject(ExerciseStore.shared)
            .environment(\.managedObjectContext, mockManagedObjectContext)
    }
}
#endif
