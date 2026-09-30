import Foundation
import SwiftData

enum GlossaryEngine {
    static func matches(in sentences: [Sentence], terms: [GlossaryTerm]) -> [String: String] {
        let corpus = sentences.map { $0.text }.joined(separator: " ").lowercased()
        var result: [String: String] = [:]
        for term in terms where !term.term.isEmpty {
            if corpus.contains(term.term.lowercased()) {
                result[term.term] = term.definition
                term.hits += 1
            }
        }
        return result
    }
}

final class PipelineMonitor: ObservableObject {
    static let shared = PipelineMonitor()
    @Published var activeCount = 0
    @Published var stage = ""
}

enum PostClassPipeline {
    static func process(lectureDate: Date, container: ModelContainer) async {
        await MainActor.run {
            PipelineMonitor.shared.activeCount += 1
            PipelineMonitor.shared.stage = "Analyzing transcript"
        }
        defer {
            Task { @MainActor in
                PipelineMonitor.shared.activeCount = max(0, PipelineMonitor.shared.activeCount - 1)
                PipelineMonitor.shared.stage = ""
            }
        }

        let context = ModelContext(container)
        let date = lectureDate
        var descriptor = FetchDescriptor<Lecture>(predicate: #Predicate { $0.date == date })
        descriptor.fetchLimit = 1
        guard let lecture = (try? context.fetch(descriptor))?.first else { return }
        let course = lecture.course
        let language = UserDefaults.standard.string(forKey: "noteLanguage") ?? "English"
        let sentences = lecture.sortedSentences

        guard !sentences.isEmpty else {
            lecture.processedAt = Date()
            try? context.save()
            return
        }

        var terms: [GlossaryTerm] = []
        if let courseName = course?.name {
            terms = (try? context.fetch(FetchDescriptor<GlossaryTerm>(predicate: #Predicate { $0.courseName == courseName }))) ?? []
        }
        let glossaryMap = GlossaryEngine.matches(in: sentences, terms: terms)

        await MainActor.run { PipelineMonitor.shared.stage = "Checking terminology" }
        if !glossaryMap.isEmpty {
            if let edits = try? await GLMService.shared.repairTranscript(
                sentences: sentences.map { $0.text },
                glossary: glossaryMap
            ) {
                applyEdits(edits, to: sentences)
            }
        }

        await MainActor.run { PipelineMonitor.shared.stage = "Generating notes with cloud AI" }
        var result: StudyResult?
        if let cloud = try? await GLMService.shared.generateStudyResult(
            sentences: sentences.map { (index: $0.orderIndex, text: $0.text) },
            glossary: glossaryMap,
            language: language
        ) {
            result = cloud
        }

        if result == nil {
            await MainActor.run {
                PipelineMonitor.shared.stage = "Cloud unavailable — using on-device AI (free)"
                GLMService.shared.lastRouteWasOnDevice = true
            }
            if let outline = await AppleFMService.shared.outlineDraft(
                sentences: sentences.map { $0.text },
                language: language
            ) {
                result = StudyResult(note: outline, flashcards: [], quiz: [])
            }
        }

        if result == nil {
            await MainActor.run {
                PipelineMonitor.shared.stage = "Using offline notes (free)"
                GLMService.shared.lastRouteWasOnDevice = true
            }
            result = degradedResult(lecture: lecture, sentences: sentences, glossary: glossaryMap)
        }

        guard let final = result else {
            lecture.processedAt = Date()
            try? context.save()
            return
        }

        var note = final.note ?? degradedNote(lecture: lecture, sentences: sentences)
        note.headings = (note.headings ?? []).map { heading in
            var h = heading
            if h.source == nil { h.source = "transcript" }
            return h
        }
        let merged = StudyResult(note: note, flashcards: final.flashcards, quiz: final.quiz)

        if let data = try? JSONEncoder().encode(merged), let json = String(data: data, encoding: .utf8) {
            lecture.noteJSON = json
        }

        let existingCards = Set(lecture.flashcards.map { $0.question })
        let cardSeeds = (final.flashcards ?? []).prefix(20)
        for seed in cardSeeds {
            let question = seed.question ?? ""
            let answer = seed.answer ?? ""
            guard !question.isEmpty, !existingCards.contains(question) else { continue }
            let card = Flashcard(question: question, answer: answer, tag: seed.tag ?? "")
            card.sourceSentenceID = sourceID(for: seed, sentences: sentences)
            card.lecture = lecture
            context.insert(card)
        }

        let quizSeeds = (final.quiz ?? []).prefix(5)
        for (offset, seed) in quizSeeds.enumerated() {
            guard let question = seed.question, !question.isEmpty else { continue }
            let item = QuizItem(
                question: question,
                options: seed.options ?? [],
                answerIndex: seed.answerIndex ?? 0,
                explanation: seed.explanation ?? "",
                orderIndex: offset
            )
            item.lecture = lecture
            context.insert(item)
        }

        lecture.processedAt = Date()
        try? context.save()

        let cardCount = lecture.flashcards.count
        _ = await NotificationService.requestAuthorization()
        NotificationService.notesReady(cardCount: cardCount)
        WidgetBridge.updateDueCount(Flashcard.dueCount(context))
    }

    private static func applyEdits(_ edits: [TermEdit], to sentences: [Sentence]) {
        for edit in edits {
            guard let original = edit.original, !original.isEmpty,
                  let replacement = edit.replacement, !replacement.isEmpty else { continue }
            for sentence in sentences where sentence.text.contains(original) {
                sentence.text = sentence.text.replacingOccurrences(of: original, with: replacement)
                sentence.isCorrected = true
            }
        }
    }

    private static func sourceID(for seed: FlashcardSeed, sentences: [Sentence]) -> Int {
        let tag = seed.tag?.lowercased() ?? ""
        if !tag.isEmpty {
            for sentence in sentences where sentence.text.lowercased().contains(tag) {
                return sentence.orderIndex
            }
        }
        let question = seed.question?.lowercased() ?? ""
        guard question.count > 12 else { return -1 }
        for sentence in sentences {
            let words = question.split(separator: " ").filter { $0.count > 5 }
            if words.contains(where: { sentence.text.lowercased().contains($0) }) {
                return sentence.orderIndex
            }
        }
        return -1
    }

    private static func degradedResult(lecture: Lecture, sentences: [Sentence], glossary: [String: String]) -> StudyResult {
        let note = degradedNote(lecture: lecture, sentences: sentences)
        var cards: [FlashcardSeed] = []
        for (term, definition) in glossary {
            cards.append(FlashcardSeed(question: "What does \"\(term)\" mean in this course?", answer: definition, tag: term))
        }
        if cards.isEmpty {
            cards.append(FlashcardSeed(
                question: "Summarize this lecture in your own words.",
                answer: note.summary ?? "",
                tag: "review"
            ))
        }
        return StudyResult(note: note, flashcards: cards, quiz: [])
    }

    private static func degradedNote(lecture: Lecture, sentences: [Sentence]) -> StudyNote {
        let count = sentences.count
        let third = max(1, count / 3)
        var headings: [StudyNote.Heading] = []
        let boundaries = [0, third, third * 2, count]
        let titles = ["Opening", "Main Points", "Wrap-Up"]
        for section in 0..<3 {
            let lower = boundaries[section]
            let upper = min(boundaries[section + 1], count)
            guard lower < upper else { continue }
            let slice = sentences[lower..<upper]
            let bullets = slice.prefix(4).map { $0.text }
            let ids = slice.prefix(4).map { $0.orderIndex }
            headings.append(StudyNote.Heading(heading: titles[section], bullets: Array(bullets), sourceSentenceIDs: Array(ids), source: "transcript"))
        }
        let summary = sentences.prefix(3).map { $0.text }.joined(separator: " ")
        return StudyNote(title: lecture.title, headings: headings, keyTerms: [], summary: summary)
    }
}
