import SwiftUI

struct CramPlanDay: Codable, Identifiable {
    var id: Int { offset }
    var offset: Int
    var date: Date
    var cardIDs: [UUID]
    var weakCount: Int
    var isSprint: Bool
}

struct CramPlan: Codable {
    var courseName: String
    var examDate: Date
    var dailyQuota: Int
    var days: [CramPlanDay]
}

enum CramPlanner {
    static func generate(courseName: String, examDate: Date, dailyQuota: Int, cards: [Flashcard], priorityLectureDates: Set<Date> = []) -> CramPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let examDay = calendar.startOfDay(for: examDate)
        var remainingDays = calendar.dateComponents([.day], from: startOfToday, to: examDay).day ?? 0
        if remainingDays < 1 { remainingDays = 1 }
        let sprintDays = min(2, remainingDays)
        let planDays = remainingDays

        let sorted = cards.sorted { lhs, rhs in
            let lhsPriority = priorityLectureDates.contains(lhs.lecture?.date ?? Date.distantPast) ? 0 : 1
            let rhsPriority = priorityLectureDates.contains(rhs.lecture?.date ?? Date.distantPast) ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.retrievability < rhs.retrievability
        }
        let queue = Array(sorted)
        var cursor = 0
        var days: [CramPlanDay] = []
        let quota = max(5, min(dailyQuota, 60))

        for offset in 0..<planDays {
            let dayDate = calendar.date(byAdding: .day, value: offset + 1, to: startOfToday) ?? examDate
            let isSprint = offset >= planDays - sprintDays
            let count = min(quota, max(0, queue.count - cursor))
            let slice = Array(queue[cursor..<(cursor + count)])
            cursor += count
            let weakCount = slice.filter { $0.retrievability < 0.5 }.count
            days.append(CramPlanDay(
                offset: offset,
                date: dayDate,
                cardIDs: slice.map { $0.cardID },
                weakCount: weakCount,
                isSprint: isSprint
            ))
            if cursor >= queue.count && !isSprint { break }
        }

        if cursor < queue.count {
            let dayDate = calendar.date(byAdding: .day, value: planDays, to: startOfToday) ?? examDate
            let leftover = Array(queue[cursor...])
            days.append(CramPlanDay(
                offset: days.count,
                date: dayDate,
                cardIDs: leftover.map { $0.cardID },
                weakCount: leftover.filter { $0.retrievability < 0.5 }.count,
                isSprint: true
            ))
        }

        return CramPlan(courseName: courseName, examDate: examDate, dailyQuota: quota, days: days)
    }

    static func encode(_ plan: CramPlan) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(plan) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ json: String) -> CramPlan? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CramPlan.self, from: data)
    }
}
