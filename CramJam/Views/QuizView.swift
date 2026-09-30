import SwiftUI
import SwiftData

struct QuizView: View {
    @Bindable var lecture: Lecture
    @Environment(\.modelContext) private var modelContext

    @State private var currentIndex = 0
    @State private var selectedOption: Int?
    @State private var correctCount = 0
    @State private var finished = false

    private var items: [QuizItem] {
        lecture.quizItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(spacing: 20) {
            if items.isEmpty {
                emptyState
            } else if finished {
                resultState
            } else if currentIndex < items.count {
                questionState
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No quiz yet for this lecture")
                .font(.headline)
            Text("Quizzes are generated together with notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.appSuccess)
            Text("\(correctCount) / \(items.count) correct")
                .font(.title2.weight(.bold))
            Text("Wrong answers flag their related cards for priority review in Cram Mode.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var questionState: some View {
        let item = items[currentIndex]
        let options = item.options
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Question \(currentIndex + 1) of \(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Score \(correctCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.question)
                .font(.headline)
            ForEach(Array(options.enumerated()), id: \.offset) { optionIndex, option in
                Button {
                    guard selectedOption == nil else { return }
                    selectedOption = optionIndex
                    if optionIndex == item.answerIndex {
                        correctCount += 1
                        item.isWrong = false
                    } else {
                        item.isWrong = true
                    }
                    try? modelContext.save()
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedOption != nil {
                            if optionIndex == item.answerIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.appSuccess)
                            } else if optionIndex == selectedOption {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(optionBackground(optionIndex, item: item))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedOption != nil)
                .accessibilityLabel("Option \(option)")
            }
            if selectedOption != nil {
                Text(item.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    withAnimation {
                        selectedOption = nil
                        currentIndex += 1
                        if currentIndex >= items.count {
                            finished = true
                        }
                    }
                } label: {
                    Text(currentIndex + 1 >= items.count ? "Finish" : "Next question")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
        }
    }

    private func optionBackground(_ optionIndex: Int, item: QuizItem) -> Color {
        guard selectedOption != nil else { return Color.appMuted }
        if optionIndex == item.answerIndex { return Color.appSuccess.opacity(0.18) }
        if optionIndex == selectedOption { return Color.red.opacity(0.16) }
        return Color.appMuted
    }
}
