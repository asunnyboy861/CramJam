import Foundation
import SwiftData

@Model
final class QuizItem {
    var question: String = ""
    var optionsData: String = "[]"
    var answerIndex: Int = 0
    var explanation: String = ""
    var isWrong: Bool = false
    var orderIndex: Int = 0
    var lecture: Lecture?

    init(question: String, options: [String], answerIndex: Int, explanation: String, orderIndex: Int) {
        self.question = question
        if let data = try? JSONEncoder().encode(options), let raw = String(data: data, encoding: .utf8) {
            self.optionsData = raw
        }
        self.answerIndex = answerIndex
        self.explanation = explanation
        self.orderIndex = orderIndex
    }

    var options: [String] {
        guard let data = optionsData.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
