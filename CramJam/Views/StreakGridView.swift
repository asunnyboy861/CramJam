import SwiftUI

struct StreakGridView: View {
    let compact: Bool
    @ObservedObject private var streak = StreakStore.shared

    init(compact: Bool = false) {
        self.compact = compact
    }

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let totalDays = compact ? 7 * 16 : 7 * 53
        let start = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today
        let offsetToMonday = (calendar.component(.weekday, from: start) + 5) % 7
        let alignedStart = calendar.date(byAdding: .day, value: -offsetToMonday, to: start) ?? start
        var result: [[Date]] = []
        var cursor = alignedStart
        while cursor <= today {
            var column: [Date] = []
            for dayOffset in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: cursor), date <= today {
                    column.append(date)
                }
            }
            result.append(column)
            cursor = calendar.date(byAdding: .day, value: 7, to: cursor) ?? today
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(streak.currentStreak)-day streak")
                    .font(.headline)
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(.appAccent)
            }
            ScrollView(compact ? [.horizontal] : [.horizontal, .vertical], showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(streak.reviewed(on: day) ? Color.appSuccess : Color.appMuted)
                                    .frame(width: compact ? 9 : 12, height: compact ? 9 : 12)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: compact ? 80 : nil)
            .accessibilityLabel("Review streak grid, current streak \(streak.currentStreak) days")
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
