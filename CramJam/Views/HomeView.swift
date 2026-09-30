import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var pipelineMonitor: PipelineMonitor
    @Query private var courses: [Course]
    @Query private var pendingLectures: [Lecture]
    @State private var showRecorder = false
    @State private var showReview = false

    init() {
        _pendingLectures = Query(
            filter: #Predicate<Lecture> { $0.processedAt == nil && $0.audioFileName != nil }
        )
    }

    private var defaultCourse: Course? {
        courses.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if pipelineMonitor.activeCount > 0 {
                        processingBanner
                    }
                    recordCard
                    dueCard
                    StreakGridView(compact: true)
                    salvageSection
                }
                .padding()
            }
            .navigationTitle("CramJam")
            .fullScreenCover(isPresented: $showRecorder) {
                if let course = defaultCourse {
                    RecordView(course: course)
                } else {
                    RecordView(course: nil)
                }
            }
            .fullScreenCover(isPresented: $showReview) {
                NavigationStack { ReviewView() }
            }
        }
    }

    private var processingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Generating notes…")
                    .font(.subheadline.weight(.semibold))
                Text(pipelineMonitor.stage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recordCard: some View {
        VStack(spacing: 14) {
            Text("Press record. Walk out. Notes ready.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button {
                showRecorder = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.18))
                        .frame(width: 148, height: 148)
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 112, height: 112)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel("Start recording lecture")
            Text(defaultCourse.map { "Recording into \($0.name)" } ?? "Create a course to organize recordings")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var dueCard: some View {
        Button {
            showReview = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today: \(Flashcard.dueCount(modelContext)) cards due")
                        .font(.title3.weight(.bold))
                    Text("Review is free forever")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.title)
                    .foregroundStyle(.appSuccess)
            }
            .padding()
            .background(Color.appMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Review due flashcards")
    }

    @ViewBuilder
    private var salvageSection: some View {
        let salvageable = pendingLectures.filter { $0.date < Calendar.current.startOfDay(for: Date()) }
        if !salvageable.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recordings from yesterday can still be processed")
                    .font(.subheadline.weight(.semibold))
                ForEach(salvageable) { lecture in
                    Button {
                        let date = lecture.date
                        let container = modelContext.container
                        Task { await PostClassPipeline.process(lectureDate: date, container: container) }
                    } label: {
                        HStack {
                            Text(lecture.title)
                                .lineLimit(1)
                            Spacer()
                            Text("Process now")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.appAccent)
                        }
                    }
                }
            }
            .padding()
            .background(Color.appMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
