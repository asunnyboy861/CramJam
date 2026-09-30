import SwiftUI
import SwiftData

struct RecordView: View {
    let course: Course?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecordingManager()
    @AppStorage("hasSeenRecordingNotice") private var hasSeenRecordingNotice = false
    @State private var lectureDate: Date?
    @State private var isFinishing = false

    var body: some View {
        VStack(spacing: 24) {
            if recorder.isRecording {
                recordingContent
            } else if isFinishing {
                ProgressView("Saving lecture…")
            } else {
                readyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .alert("Before you record", isPresented: Binding(
            get: { !hasSeenRecordingNotice },
            set: { _ in }
        )) {
            Button("Got it") {
                hasSeenRecordingNotice = true
            }
        } message: {
            Text("Check your course policy and local consent requirements before recording.")
        }
        .onDisappear {
            if recorder.isRecording {
                Task { await finishRecording() }
            }
        }
    }

    private var readyContent: some View {
        VStack(spacing: 20) {
            Text(course?.name ?? "Unfiled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Ready to record")
                .font(.title2.weight(.bold))
            Button {
                Task { await startRecording() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.appAccent, lineWidth: 4)
                        .frame(width: 128, height: 128)
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 96, height: 96)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel("Start recording")
            if !recorder.statusText.isEmpty {
                Text(recorder.statusText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 28) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(recorder.isRecording ? 1 : 0.3)
                Text(timeString(recorder.elapsed))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
            }
            .accessibilityLabel("Recording, elapsed \(timeString(recorder.elapsed))")
            Text(course?.name ?? "Unfiled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(recorder.liveCaption.isEmpty ? "Listening…" : recorder.liveCaption)
                        .font(.title3)
                        .foregroundStyle(recorder.liveCaption.isEmpty ? Color.secondary : Color.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .id("caption")
                }
                .frame(maxHeight: 140)
                .onChange(of: recorder.liveCaption) { _, _ in
                    proxy.scrollTo("caption", anchor: .bottom)
                }
            }
            Spacer()
            Button {
                Task { await finishRecording() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                        .frame(width: 110, height: 110)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                }
            }
            .accessibilityLabel("Stop recording")
            Text("Stop to generate notes and flashcards")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func startRecording() async {
        let lecture = Lecture(title: defaultTitle(), language: UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "en-US")
        lecture.course = course
        modelContext.insert(lecture)
        lectureDate = lecture.date
        await recorder.start(language: lecture.language)
        if !recorder.isRecording {
            modelContext.delete(lecture)
            lectureDate = nil
        }
    }

    private func finishRecording() async {
        guard !isFinishing else { return }
        isFinishing = true
        let (sentences, url) = await recorder.stop()
        defer { dismiss() }
        guard let date = lectureDate else { return }
        let context = modelContext
        let container = context.container
        var descriptor = FetchDescriptor<Lecture>(predicate: #Predicate { $0.date == date })
        descriptor.fetchLimit = 1
        guard let lecture = (try? context.fetch(descriptor))?.first else { return }
        if let url {
            lecture.audioFileName = url.lastPathComponent
        }
        for (offset, data) in sentences.enumerated() {
            let sentence = Sentence(
                text: data.text,
                startSeconds: data.start,
                endSeconds: data.end,
                confidence: data.confidence,
                orderIndex: offset
            )
            sentence.lecture = lecture
            context.insert(sentence)
        }
        try? context.save()
        if sentences.isEmpty && url == nil {
            context.delete(lecture)
            return
        }
        Task.detached {
            await PostClassPipeline.process(lectureDate: date, container: container)
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "Lecture — \(formatter.string(from: Date()))"
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
