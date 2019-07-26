//
//  ExercisesView.swift
//  Sunrise Fit
//
//  Created by Karim Abou Zeid on 04.07.19.
//  Copyright © 2019 Karim Abou Zeid Software. All rights reserved.
//

import SwiftUI

struct ExercisesView : View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var trainingsDataStore: TrainingsDataStore // TODO: (bug in beta3?) remove in future, only needed for the presentation of the statistics view
    var exercises: [Exercise]
    
    var body: some View {
        List(exercises, id: \.id) { exercise in
            NavigationLink(exercise.title, destination: ExerciseDetailView(exercise: exercise)
                .environmentObject(self.trainingsDataStore)
                .environmentObject(self.settingsStore))
        }
    }
}

#if DEBUG
struct ExercisesView_Previews : PreviewProvider {
    static var previews: some View {
        ExercisesView(exercises: EverkineticDataProvider.exercises)
            .environmentObject(mockTrainingsDataStore)
            .environmentObject(mockSettingsStoreMetric)
    }
}
#endif