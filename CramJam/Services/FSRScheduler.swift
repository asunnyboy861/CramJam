import Foundation
import FSRS
import SwiftData

struct FSRScheduler {
    static let shared = FSRScheduler()

    private let scheduler = FSRS(parameters: FSRSParameters(w: FSRSDefaults.defaultWv6))

    func newCard(now: Date = Date()) -> Card {
        Card(due: now)
    }

    func rate(_ card: Card, grade: Rating, now: Date = Date()) -> Card {
        (try? scheduler.next(card: card, now: now, grade: grade))?.card ?? card
    }

    func retrievability(of card: Card, now: Date = Date()) -> Double {
        scheduler.getRetrievability(card: card, now: now).number
    }
}

extension Flashcard {
    var fsrsCard: Card {
        Card(
            due: dueDate,
            stability: stability,
            difficulty: difficulty,
            elapsedDays: 0,
            scheduledDays: 0,
            reps: reps,
            lapses: lapses,
            state: CardState(rawValue: stateRaw) ?? .new,
            lastReview: lastReviewDate
        )
    }

    func apply(fsrs card: Card) {
        dueDate = card.due
        stability = card.stability
        difficulty = card.difficulty
        reps = card.reps
        lapses = card.lapses
        stateRaw = card.state.rawValue
        lastReviewDate = card.lastReview ?? Date()
    }

    var retrievability: Double {
        FSRScheduler.shared.retrievability(of: fsrsCard)
    }
}
