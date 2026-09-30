import Foundation
import SwiftData

@Model
final class ExamPlan {
    var courseName: String = ""
    var examDate: Date = Date()
    var dailyQuota: Int = 20
    var createdAt: Date = Date()
    var planJSON: String = ""

    init(courseName: String, examDate: Date, dailyQuota: Int) {
        self.courseName = courseName
        self.examDate = examDate
        self.dailyQuota = dailyQuota
        self.createdAt = Date()
    }
}
