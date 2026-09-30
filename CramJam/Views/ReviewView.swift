import SwiftUI
import SwiftData
import FSRS

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Flashcard] = []
    @State private var index = 0
    @State private var showAnswer = false
    @State private var counts = ReviewCounts()
    @State private var sessionDone = false
    @State private var dragOffset: CGSize = .zero
    var limitIDs: [UUID]?

    struct ReviewCounts {
        var again = 0
        var hard = 0
        var good = 0
        var easy = 0
    }

    var body: some View {
        VStack(spacing: 22) {
            if sessionDone {
                summary
            } else if index < queue.count {
                cardArea
                ratingBar
            } else {
                emptyState
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Done") { dismiss() }
        }
        .onAppear(perform: buildQueue)
    }

    private var current: Flashcard? {
        index < queue.count ? queue[index] : nil
    }

    private func buildQueue() {
        guard queue.isEmpty else { return }
        let now = Date()
        let cards: [Flashcard]
        if let limitIDs, !limitIDs.isEmpty {
            let idSet = Set(limitIDs)
            let all = (try? modelContext.fetch(FetchDescriptor<Flashcard>())) ?? []
            cards = all.filter { idSet.contains($0.cardID) }
        } else {
            let descriptor = FetchDescriptor<Flashcard>(
                predicate: #Predicate { $0.dueDate <= now },
                sortBy: [SortDescriptor(\.dueDate)]
            )
            cards = (try? modelContext.fetch(descriptor)) ?? []
        }
        queue = cards
        if queue.isEmpty {
            sessionDone = true
        }
    }

    private var cardArea: some View {
        VStack(spacing: 14) {
            if let current {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(index + 1) / \(queue.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !current.tag.isEmpty {
                            Text(current.tag)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appAccent.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(current.question)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showAnswer {
                        Divider()
                        Text(current.answer)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Button {
                            withAnimation { showAnswer = true }
                        } label: {
                            Label("Show answer", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appAccent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("Show answer")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appMuted)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if value.translation.height < -90 {
                                withAnimation { dragOffset = CGSize(width: 0, height: -600) }
                                rate(.good)
                            } else {
                                withAnimation(.spring()) { dragOffset = .zero }
                            }
                        }
                )
                .accessibilityLabel("Flashcard: \(current.question)")
            }
        }
    }

    private var ratingBar: some View {
        HStack(spacing: 12) {
            ratingButton("Again", icon: "circle.fill", color: .red) { rate(.again) }
            ratingButton("Hard", icon: "square.fill", color: .orange) { rate(.hard) }
            ratingButton("Good", icon: "triangle.fill", color: .blue) { rate(.good) }
            ratingButton("Easy", icon: "diamond.fill", color: .appSuccess) { rate(.easy) }
        }
    }

    private func ratingButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!showAnswer)
        .opacity(showAnswer ? 1 : 0.4)
        .accessibilityLabel("Rate \(title)")
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.appSuccess)
            Text("Session complete")
                .font(.title2.weight(.bold))
            Text("\(queue.count) cards reviewed. Next due dates scheduled by FSRS-6.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Again \(counts.again) · Hard \(counts.hard) · Good \(counts.good) · Easy \(counts.easy)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Come back tomorrow to keep your streak.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No cards due right now")
                .font(.headline)
            Text("Record a lecture to create flashcards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rate(_ grade: Rating) {
        guard let current else { return }
        let next = FSRScheduler.shared.rate(current.fsrsCard, grade: grade)
        current.apply(fsrs: next)
        switch grade {
        case .again: counts.again += 1
        case .hard: counts.hard += 1
        case .good: counts.good += 1
        case .easy: counts.easy += 1
        default: break
        }
        StreakStore.shared.markToday()
        try? modelContext.save()
        withAnimation {
            dragOffset = .zero
            showAnswer = false
            index += 1
            if index >= queue.count {
                sessionDone = true
            }
        }
        WidgetBridge.updateDueCount(Flashcard.dueCount(modelContext))
    }
}
