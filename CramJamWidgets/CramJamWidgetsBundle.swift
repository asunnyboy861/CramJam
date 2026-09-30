import WidgetKit
import SwiftUI

struct DueCardsEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
}

struct DueCardsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DueCardsEntry {
        DueCardsEntry(date: .now, dueCount: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (DueCardsEntry) -> Void) {
        completion(DueCardsEntry(date: .now, dueCount: dueCount()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DueCardsEntry>) -> Void) {
        let entry = DueCardsEntry(date: .now, dueCount: dueCount())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func dueCount() -> Int {
        let defaults = UserDefaults(suiteName: "group.com.zzoutuo.CramJam")
        return defaults?.integer(forKey: "dueCardCount") ?? 0
    }
}

struct DueCardsWidgetView: View {
    let entry: DueCardsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CramJam")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.dueCount)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.21))
            Text("cards due today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) { Color(.systemGray6) }
    }
}

struct DueCardsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DueCardsWidget", provider: DueCardsProvider()) { entry in
            DueCardsWidgetView(entry: entry)
        }
        .configurationDisplayName("Due Cards")
        .description("Shows how many flashcards are due for review today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CramJamWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DueCardsWidget()
    }
}
