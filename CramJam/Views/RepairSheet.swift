import SwiftUI
import SwiftData

struct RepairSheet: View {
    @Bindable var sentence: Sentence
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [String] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(sentence.text)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.appMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if isLoading {
                    ProgressView("Asking AI for 3 corrections…")
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("You can edit meaning via the glossary or re-check the recording.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap a correction to apply it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                        Button {
                            apply(candidate)
                        } label: {
                            Text(candidate)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.appAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel("Apply correction \(candidate)")
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Fix transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await loadCandidates()
        }
    }

    private func loadCandidates() async {
        do {
            candidates = try await GLMService.shared.repairCandidates(sentence: sentence.text).prefix(3).map { $0 }
            if candidates.isEmpty {
                errorText = "No suggestions available."
            }
        } catch {
            errorText = "Cloud AI unavailable (\(error.localizedDescription))."
        }
        isLoading = false
    }

    private func apply(_ candidate: String) {
        sentence.text = candidate
        sentence.isCorrected = true
        sentence.confidence = 1.0
        dismiss()
    }
}
