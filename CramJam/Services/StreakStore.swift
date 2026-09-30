import Foundation
import UserNotifications
import WidgetKit

enum WidgetBridge {
    static let appGroupID = "group.com.zzoutuo.CramJam"
    static let widgetKind = "DueCardsWidget"

    static func updateDueCount(_ count: Int) {
        UserDefaults(suiteName: appGroupID)?.set(count, forKey: "dueCardCount")
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func notesReady(cardCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CramJam"
        content.body = "Notes are ready! \(cardCount) flashcards created"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    @Published private(set) var days: Set<String>

    private let key = "reviewDays"
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init() {
        days = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func dayString(_ date: Date) -> String {
        formatter.string(from: date)
    }

    func markToday() {
        let today = Self.dayString(Date())
        guard !days.contains(today) else { return }
        days.insert(today)
        UserDefaults.standard.set(Array(days), forKey: key)
    }

    var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var cursor = Date()
        if !days.contains(Self.dayString(cursor)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(Self.dayString(cursor)) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    func reviewed(on date: Date) -> Bool {
        days.contains(Self.dayString(date))
    }
}
