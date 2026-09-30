import SwiftUI
import SwiftData
import PhotosUI

struct LectureDetailView: View {
    @Bindable var lecture: Lecture

    @Environment(\.modelContext) private var modelContext
    @StateObject private var player = LectureAudioPlayer()
    @State private var repairSentence: Sentence?
    @State private var showSlideImport = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var exportError: String?

    private var result: StudyResult? {
        guard let json = lecture.noteJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StudyResult.self, from: data)
    }

    private var audioURL: URL? {
        guard let name = lecture.audioFileName else { return nil }
        return AudioRecordingManager.url(forFileName: name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let url = audioURL {
                    playBar(url: url)
                }
                noteSection
                keyTermsSection
                transcriptSection
                footer
            }
            .padding()
        }
        .navigationTitle(lecture.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    GlossaryView(courseName: lecture.course?.name ?? "")
                } label: {
                    Image(systemName: "character.book.closed")
                }
                .accessibilityLabel("Course glossary")
                NavigationLink {
                    QuizView(lecture: lecture)
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Take quiz")
                if lecture.processedAt != nil {
                    PhotosPicker(selection: Binding(
                        get: { nil },
                        set: { newValue in
                            if newValue != nil { showSlideImport = true }
                        }
                    ), matching: .images) {
                        Image(systemName: "doc.viewfinder")
                    }
                    .accessibilityLabel("Import slide photo")
                }
                Menu {
                    Button("Export Markdown") { exportMarkdown() }
                    Button("Export PDF") { exportPDF() }
                    Button("Export Anki CSV") { exportCSV() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export notes")
            }
        }
        .sheet(item: $repairSentence) { sentence in
            RepairSheet(sentence: sentence)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSlideImport) {
            SlideImportView(lecture: lecture)
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func playBar(url: URL) -> some View {
        HStack(spacing: 12) {
            Button {
                player.load(url: url)
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.appAccent)
            }
            .accessibilityLabel(player.isPlaying ? "Pause audio" : "Play audio")
            VStack(alignment: .leading, spacing: 2) {
                Text(timeString(player.currentTime) + " / " + timeString(player.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if player.activeSentenceIndex >= 0 {
                    Text("Jumped to source")
                        .font(.caption2)
                        .foregroundStyle(.appSuccess)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var noteSection: some View {
        if let result, let note = result.note {
            VStack(alignment: .leading, spacing: 16) {
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.title2.weight(.bold))
                }
                ForEach(Array((note.headings ?? []).enumerated()), id: \.offset) { _, heading in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(heading.heading ?? "")
                                .font(.headline)
                            if heading.source == "slide" {
                                Text("Slide")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.appAccent.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        ForEach(Array((heading.bullets ?? []).enumerated()), id: \.offset) { bulletIndex, bullet in
                            bulletButton(bullet: bullet, heading: heading, bulletIndex: bulletIndex)
                        }
                    }
                    .padding()
                    .background(Color.appMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if let summary = note.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary")
                            .font(.headline)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.appMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        } else if lecture.processedAt == nil && lecture.audioFileName != nil {
            VStack(spacing: 10) {
                ProgressView()
                Text("Generating notes…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            Text("No notes yet. Record audio or process this lecture from Home.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func bulletButton(bullet: String, heading: StudyNote.Heading, bulletIndex: Int) -> some View {
        let ids = heading.sourceSentenceIDs ?? []
        let sentenceID: Int? = bulletIndex < ids.count ? ids[bulletIndex] : ids.first
        let sentence = sentenceID.flatMap { id in
            lecture.sortedSentences.first { $0.orderIndex == id }
        }
        return Button {
            if let sentence, let url = audioURL {
                player.load(url: url)
                player.activeSentenceIndex = sentence.orderIndex
                player.play(at: max(0, sentence.startSeconds - 0.3))
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: sentence != nil ? "waveform" : "text.justifyLeading")
                    .font(.caption)
                    .foregroundStyle(sentence != nil ? .appAccent : .secondary)
                    .padding(.top, 3)
                Text(bullet)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
        .disabled(sentence == nil || audioURL == nil)
        .accessibilityLabel(sentence != nil ? "Play source: \(bullet)" : bullet)
    }

    @ViewBuilder
    private var keyTermsSection: some View {
        if let terms = result?.note?.keyTerms, !terms.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Key Terms")
                    .font(.headline)
                ForEach(Array(terms.enumerated()), id: \.offset) { _, term in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(term.term ?? "")
                            .font(.subheadline.weight(.semibold))
                        Text(term.definition ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color.appMuted)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transcript")
                .font(.headline)
            let sentences = lecture.sortedSentences
            if sentences.isEmpty {
                Text("No transcript captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(sentences, id: \.persistentModelID) { sentence in
                Button {
                    repairSentence = sentence
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(timeString(sentence.startSeconds))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(sentence.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if sentence.confidence < 0.6 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.appAccent)
                        } else if sentence.isCorrected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.appSuccess)
                        }
                    }
                    .padding(8)
                    .background(sentence.confidence < 0.6 ? Color.appAccent.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Sentence at \(timeString(sentence.startSeconds)), \(sentence.text)")
            }
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        Text("AI may make mistakes — tap any line to verify against the recording.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private func exportMarkdown() {
        let markdown = ExportService.markdown(for: lecture, note: result?.note, cards: lecture.flashcards)
        guard let url = ExportService.writeTemporary(markdown, name: "\(lecture.title).md") else {
            exportError = "Could not create file."
            return
        }
        shareURL = url
        showShare = true
    }

    private func exportCSV() {
        let csv = ExportService.ankiCSV(cards: lecture.flashcards)
        guard let url = ExportService.writeTemporary(csv, name: "\(lecture.title)-anki.csv") else {
            exportError = "Could not create file."
            return
        }
        shareURL = url
        showShare = true
    }

    private func exportPDF() {
        guard let note = result?.note else {
            exportError = "No notes to export yet."
            return
        }
        guard let data = ExportService.pdfData(title: lecture.title, note: note),
              let url = ExportService.writeTemporary(data, name: "\(lecture.title).pdf") else {
            exportError = "Could not render PDF."
            return
        }
        shareURL = url
        showShare = true
    }

    private func timeString(_ interval: Double) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
