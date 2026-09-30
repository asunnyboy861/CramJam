import Foundation
import SwiftData

@Model
final class Course {
    var name: String = ""
    var colorHex: String = "#FF6B35"
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Lecture.course) var lectures: [Lecture] = []

    init(name: String, colorHex: String = "#FF6B35") {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}

@Model
final class Lecture {
    var title: String = ""
    var date: Date = Date()
    var audioFileName: String?
    var language: String = "en-US"
    var noteJSON: String?
    var processedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Sentence.lecture) var sentences: [Sentence] = []
    @Relationship(deleteRule: .cascade, inverse: \Flashcard.lecture) var flashcards: [Flashcard] = []
    @Relationship(deleteRule: .cascade, inverse: \QuizItem.lecture) var quizItems: [QuizItem] = []
    var course: Course?

    init(title: String, date: Date = Date(), language: String = "en-US") {
        self.title = title
        self.date = date
        self.language = language
    }

    var sortedSentences: [Sentence] {
        sentences.sorted { $0.orderIndex < $1.orderIndex }
    }
}
