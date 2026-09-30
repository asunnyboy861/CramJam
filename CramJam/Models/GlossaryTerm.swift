import Foundation
import SwiftData

@Model
final class GlossaryTerm {
    var term: String = ""
    var definition: String = ""
    var courseName: String = ""
    var hits: Int = 0

    init(term: String, definition: String, courseName: String) {
        self.term = term
        self.definition = definition
        self.courseName = courseName
        self.hits = 0
    }
}
