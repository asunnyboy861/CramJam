import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("transcriptionLanguage") private var transcriptionLanguage = "en-US"
    @State private var selectedLanguage = "en-US"
    @State private var courseName = ""
    @State private var selectedColor = "#FF6B35"

    private let languages: [(id: String, label: String)] = [
        ("en-US", "English"),
        ("zh-CN", "中文"),
        ("es-ES", "Español"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(.appAccent)
            Text("Welcome to CramJam")
                .font(.largeTitle.weight(.bold))
            Text("Record lectures free. Notes, flashcards and review are ready when you walk out.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                Text("Transcription language")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(languages, id: \.id) { language in
                        Button {
                            selectedLanguage = language.id
                        } label: {
                            Text(language.label)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedLanguage == language.id ? Color.appAccent : Color.appMuted)
                                .foregroundStyle(selectedLanguage == language.id ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel("Language \(language.label)")
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Your first course")
                    .font(.headline)
                TextField("e.g. Biology 101", text: $courseName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 2)
                HStack(spacing: 12) {
                    ForEach(AppTheme.coursePalette, id: \.self) { hex in
                        Button {
                            selectedColor = hex
                        } label: {
                            Circle()
                                .fill(AppTheme.courseColor(hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if selectedColor == hex {
                                        Circle().stroke(Color.white, lineWidth: 2).padding(-3)
                                    }
                                }
                        }
                        .accessibilityLabel("Course color")
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                finish()
            } label: {
                Text("Start studying")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            Button("Skip for now") {
                finish(createCourse: false)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
    }

    private func finish(createCourse: Bool = true) {
        transcriptionLanguage = selectedLanguage
        if createCourse {
            let name = courseName.trimmingCharacters(in: .whitespaces)
            let course = Course(name: name.isEmpty ? "My Course" : name, colorHex: selectedColor)
            modelContext.insert(course)
        }
        hasOnboarded = true
    }
}
