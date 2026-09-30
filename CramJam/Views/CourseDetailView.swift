import SwiftUI
import SwiftData

struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipelineMonitor: PipelineMonitor
    @Bindable var course: Course

    private var weekGroups: [(label: String, lectures: [Lecture])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: course.lectures) { lecture -> Date in
            calendar.dateInterval(of: .weekOfYear, for: lecture.date)?.start ?? lecture.date
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { key, lectures in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                let end = calendar.date(byAdding: .day, value: 6, to: key) ?? key
                return ("Week of \(formatter.string(from: key)) – \(formatter.string(from: end))", lectures.sorted { $0.date > $1.date })
            }
    }

    var body: some View {
        List {
            if pipelineMonitor.activeCount > 0 {
                HStack {
                    ProgressView().tint(.appAccent)
                    Text(pipelineMonitor.stage.isEmpty ? "Generating notes…" : pipelineMonitor.stage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                GlossaryView(courseName: course.name)
            } label: {
                Label("Glossary", systemImage: "character.book.closed.fill")
                    .foregroundStyle(.appAccent)
            }
            ForEach(weekGroups, id: \.label) { group in
                Section(group.label) {
                    ForEach(group.lectures) { lecture in
                        NavigationLink {
                            LectureDetailView(lecture: lecture)
                        } label: {
                            lectureRow(lecture)
                        }
                    }
                }
            }
        }
        .navigationTitle(course.name)
        .overlay {
            if course.lectures.isEmpty {
                Text("Record a lecture from Home to fill this course.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func lectureRow(_ lecture: Lecture) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(lecture.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if lecture.processedAt == nil && lecture.audioFileName != nil {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.appAccent)
                        .font(.caption)
                }
            }
            Text(lecture.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Lecture \(lecture.title)")
    }
}
