import SwiftUI
import SwiftData
import PhotosUI

struct SlideImportView: View {
    @Bindable var lecture: Lecture
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var status: Status = .picking
    @State private var insertedCount = 0

    enum Status: Equatable { case picking, processing, done, failed(String) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                switch status {
                case .picking:
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.appAccent)
                    Text("Photo of a PPT slide becomes bulleted notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text("Choose slide photo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .processing:
                    ProgressView("Reading slide with cloud AI…")
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.appSuccess)
                    Text("Added \(insertedCount) slide sections to this lecture")
                        .font(.subheadline)
                case .failed(let message):
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("Import slide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(status == .done || isFailed ? "Close" : "Cancel") { dismiss() }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await process(item) }
        }
    }

    private var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    private func process(_ item: PhotosPickerItem) async {
        status = .processing
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            status = .failed("Could not load the image.")
            return
        }
        guard let jpeg = resizedJPEG(image, maxBytes: 2_000_000) else {
            status = .failed("Could not encode the image.")
            return
        }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        let language = UserDefaults.standard.string(forKey: "noteLanguage") ?? "English"
        do {
            let slideResult = try await GLMService.shared.noteFromSlide(imageDataURL: dataURL, language: language)
            merge(slideResult)
            status = .done
        } catch {
            status = .failed("Slide import failed: \(error.localizedDescription)")
        }
    }

    private func merge(_ slideResult: StudyResult) {
        var existing: StudyResult
        if let json = lecture.noteJSON, let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(StudyResult.self, from: data) {
            existing = decoded
        } else {
            existing = StudyResult(note: StudyNote(title: lecture.title, headings: [], keyTerms: [], summary: ""), flashcards: [], quiz: [])
        }
        var note = existing.note ?? StudyNote(title: lecture.title, headings: [], keyTerms: [], summary: "")
        let slideHeadings = (slideResult.note?.headings ?? []).map { heading in
            var h = heading
            h.source = "slide"
            return h
        }
        note.headings = (note.headings ?? []) + slideHeadings
        note.keyTerms = (note.keyTerms ?? []) + (slideResult.note?.keyTerms ?? [])
        var updated = existing
        updated.note = note
        updated.flashcards = (existing.flashcards ?? []) + (slideResult.flashcards ?? [])
        if let data = try? JSONEncoder().encode(updated), let json = String(data: data, encoding: .utf8) {
            lecture.noteJSON = json
        }
        insertedCount = slideHeadings.count

        let context = lecture.modelContext
        for seed in (slideResult.flashcards ?? []).prefix(20) {
            let card = Flashcard(question: seed.question ?? "", answer: seed.answer ?? "", tag: seed.tag ?? "slide")
            card.lecture = lecture
            context?.insert(card)
        }
        try? context?.save()
        WidgetBridge.updateDueCount(context.map { Flashcard.dueCount($0) } ?? 0)
    }

    private func resizedJPEG(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.2 {
            quality -= 0.15
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }
}
