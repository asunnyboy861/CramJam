import Foundation

struct StudyNote: Codable {
    struct Heading: Codable {
        var heading: String?
        var bullets: [String]?
        var sourceSentenceIDs: [Int]?
        var source: String?

        enum CodingKeys: String, CodingKey {
            case heading, bullets, source
            case sourceSentenceIDs = "source_sentence_ids"
        }
    }

    struct KeyTerm: Codable {
        var term: String?
        var definition: String?

        enum CodingKeys: String, CodingKey {
            case term
            case definition
        }
    }

    var title: String?
    var headings: [Heading]?
    var keyTerms: [KeyTerm]?
    var summary: String?

    enum CodingKeys: String, CodingKey {
        case title, headings, summary
        case keyTerms = "key_terms"
    }
}

struct FlashcardSeed: Codable {
    var question: String?
    var answer: String?
    var tag: String?
}

struct QuizSeed: Codable {
    var question: String?
    var options: [String]?
    var answerIndex: Int?
    var explanation: String?

    enum CodingKeys: String, CodingKey {
        case question, options, explanation
        case answerIndex = "answer_index"
    }
}

struct StudyResult: Codable {
    var note: StudyNote?
    var flashcards: [FlashcardSeed]?
    var quiz: [QuizSeed]?
}

struct TermEdit: Codable {
    var original: String?
    var replacement: String?
    var reason: String?
}

struct TermEditList: Codable {
    var edits: [TermEdit]?
}

struct RepairCandidateList: Codable {
    var candidates: [String]?
}
