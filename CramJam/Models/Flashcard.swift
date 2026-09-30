import Foundation
import SwiftData

@Model
final class Flashcard {
    var cardID: UUID = UUID()
    var question: String = ""
    var answer: String = ""
    var tag: String = ""
    var dueDate: Date = Date()
    var stability: Double = 0
    var difficulty: Double = 0
    var lapses: Int = 0
    var reps: Int = 0
    var stateRaw: Int = 0
    var lastReviewDate: Date?
    var sourceSentenceID: Int = -1
    var createdAt: Date = Date()
    var lecture: Lecture?

    init(question: String, answer: String, tag: String = "", dueDate: Date = Date()) {
        self.question = question
        self.answer = answer
        self.tag = tag
        self.dueDate = dueDate
        self.createdAt = Date()
    }

    static func dueCount(_ context: ModelContext) -> Int {
        let now = Date()
        let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.dueDate <= now })
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
