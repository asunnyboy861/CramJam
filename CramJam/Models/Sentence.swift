import Foundation
import SwiftData

@Model
final class Sentence {
    var text: String = ""
    var startSeconds: Double = 0
    var endSeconds: Double = 0
    var confidence: Double = 1.0
    var orderIndex: Int = 0
    var isCorrected: Bool = false
    var lecture: Lecture?

    init(text: String, startSeconds: Double, endSeconds: Double, confidence: Double, orderIndex: Int) {
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.confidence = confidence
        self.orderIndex = orderIndex
    }
}
