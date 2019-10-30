//
//  WorkoutSet.swift
//  Rhino Fit
//
//  Created by Karim Abou Zeid on 14.02.18.
//  Copyright © 2018 Karim Abou Zeid Software. All rights reserved.
//

import CoreData
import Combine

class WorkoutSet: NSManagedObject, Codable {
    static var MAX_REPETITIONS: Int16 = 9999
    static var MAX_WEIGHT: Double = 99999
    
    // MARK: Derived properties

    var isPersonalRecord: Bool? {
        guard let start = workoutExercise?.workout?.start else { return nil }
        guard let exerciseUuid = workoutExercise?.exerciseUuid else { return nil }

        let previousSetsRequest: NSFetchRequest<WorkoutSet> = WorkoutSet.fetchRequest()
        let previousSetsPredicate = NSPredicate(format:
            "\(#keyPath(WorkoutSet.workoutExercise.exerciseUuid)) == %@ AND \(#keyPath(WorkoutSet.isCompleted)) == %@ AND \(#keyPath(WorkoutSet.workoutExercise.workout.start)) < %@",
            exerciseUuid as CVarArg, true as NSNumber, start as NSDate
        )
        previousSetsRequest.predicate = previousSetsPredicate
        guard let numberOfPreviousSets = try? managedObjectContext?.count(for: previousSetsRequest) else { return nil }
        if numberOfPreviousSets == 0 { return false } // if there was no set for this exercise in a prior workout, we consider no set as a PR

        let betterOrEqualPreviousSetsRequest: NSFetchRequest<WorkoutSet> = WorkoutSet.fetchRequest()
        betterOrEqualPreviousSetsRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates:
            [
                previousSetsPredicate,
                NSPredicate(format:
                    "\(#keyPath(WorkoutSet.weight)) >= %@ AND \(#keyPath(WorkoutSet.repetitions)) >= %@",
                    weight as NSNumber, repetitions as NSNumber
                )
            ]
        )
        guard let numberOfBetterOrEqualPreviousSets = try? managedObjectContext?.count(for: betterOrEqualPreviousSetsRequest) else { return nil }
        if numberOfBetterOrEqualPreviousSets > 0 { return false } // there are better sets
        
        guard let index = workoutExercise?.workoutSets?.index(of: self), index != NSNotFound else { return nil }
        guard let numberOfBetterOrEqualPreviousSetsInCurrentWorkout = (workoutExercise?.workoutSets?.array[0..<index]
            .compactMap { $0 as? WorkoutSet }
            .filter { $0.isCompleted && $0.weight >= weight && $0.repetitions >= repetitions } // check isCompleted only to be sure, but it should never be false here
            .count)
            else { return nil }
        return numberOfBetterOrEqualPreviousSetsInCurrentWorkout == 0
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case repetitions
        case weight
        case rpe
        case tag
        case comment
    }
    
    required convenience init(from decoder: Decoder) throws {
        guard let contextKey = CodingUserInfoKey.managedObjectContextKey,
            let context = decoder.userInfo[contextKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "WorkoutSet", in: context)
            else {
            throw CodingUserInfoKey.DecodingError.managedObjectContextMissing
        }
        self.init(entity: entity, insertInto: context)
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repetitions = try container.decode(Int16.self, forKey: .repetitions)
        weight = try container.decode(Double.self, forKey: .weight)
        displayRpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        displayTag = WorkoutSetTag(rawValue: try container.decodeIfPresent(String.self, forKey: .tag) ?? "")
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        isCompleted = true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repetitions, forKey: .repetitions)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(displayRpe, forKey: .rpe)
        try container.encodeIfPresent(displayTag?.rawValue, forKey: .tag)
        try container.encodeIfPresent(comment, forKey: .comment)
    }
}

// MARK: Display
extension WorkoutSet {
    func displayTitle(unit: WeightUnit) -> String {
        let numberFormatter = unit.numberFormatter
        numberFormatter.minimumFractionDigits = unit.defaultFractionDigits
        let weightInUnit = WeightUnit.convert(weight: weight, from: .metric, to: unit)
        return "\(numberFormatter.string(from: weightInUnit as NSNumber) ?? String(format: "%\(unit.maximumFractionDigits).f")) \(unit.abbrev) × \(repetitions)"
    }
    
    // use this instead of tag
    var displayTag: WorkoutSetTag? {
        get {
            WorkoutSetTag(rawValue: tag ?? "")
        }
        set {
            tag = newValue?.rawValue
        }
    }
    
    // use this instead of rpe
    var displayRpe: Double? {
        get {
            RPE.allowedValues.contains(rpe) ? rpe : nil
        }
        set {
            let newValue = newValue ?? 0
            rpe = RPE.allowedValues.contains(newValue) ? newValue : 0
        }
    }
    
    func logTitle(unit: WeightUnit) -> String {
        let title = displayTitle(unit: unit)
        guard let tag = displayTag?.title.capitalized, !tag.isEmpty else { return title }
        return title + " (\(tag))"
    }
}

extension WorkoutSet {
    override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateConsistency()
    }
    
    override func validateForInsert() throws {
        try super.validateForInsert()
        try validateConsistency()
    }
    
    func validateConsistency() throws {
        if !isCompleted, let workout = workoutExercise?.workout, !workout.isCurrentWorkout {
            throw error(code: 1, message: "uncompleted set in workout that is not current workout")
        }
    }
    
    private func error(code: Int, message: String) -> NSError {
        NSError(domain: "WORKOUT_SET_ERROR_DOMAIN", code: code, userInfo: [NSLocalizedFailureReasonErrorKey: message, NSValidationObjectErrorKey: self])
    }
}
