import SwiftUI

struct ContactSupportView: View {
    enum Topic: String, CaseIterable, Identifiable {
        case general, feature, bug, usage, performance, ui, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .feature: return "Feature Suggestion"
            case .bug: return "Bug Report"
            case .usage: return "Usage Question"
            case .performance: return "Performance Issue"
            case .ui: return "UI Improvement"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .general: return "bubble.left.fill"
            case .feature: return "lightbulb.fill"
            case .bug: return "ant.fill"
            case .usage: return "questionmark.circle.fill"
            case .performance: return "gauge.with.dots.needle.67percent"
            case .ui: return "paintpalette.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }

    @State private var topic: Topic = .general
    @State private var name = ""
    @State private var email = ""
    @State private var customSubject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var resultText: String?
    @State private var resultIsSuccess = false

    private var subject: String {
        topic == .other ? customSubject : topic.title
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !message.trimmingCharacters(in: .whitespaces).isEmpty
            && (topic != .other || !customSubject.trimmingCharacters(in: .whitespaces).isEmpty)
            && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topicBlock
                fieldBlock
                messageBlock
                submitButton
                if let resultText {
                    Text(resultText)
                        .font(.caption)
                        .foregroundStyle(resultIsSuccess ? .appSuccess : .red)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                Text("We only use your email to respond to this feedback.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topicBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subject")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach([Topic.general, .feature, .bug, .usage, .performance, .ui]) { item in
                    tile(item)
                }
            }
            tile(.other)
            if topic == .other {
                TextField("Describe your topic", text: $customSubject)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func tile(_ item: Topic) -> some View {
        Button {
            topic = item
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                Text(item.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(topic == item ? Color.appAccent : Color.appMuted)
            .foregroundStyle(topic == item ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Topic \(item.title)")
    }

    private var fieldBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your name")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            Text("Email")
                .font(.headline)
            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var messageBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message")
                    .font(.headline)
                Spacer()
                Text("\(message.count)/1000")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: $message)
                .frame(minHeight: 130)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.appMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: message) { _, newValue in
                    if newValue.count > 1000 {
                        message = String(newValue.prefix(1000))
                    }
                }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Submit")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Color.appAccent : Color.appAccent.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSubmit)
        .accessibilityLabel("Submit feedback")
    }

    private func submit() async {
        isSubmitting = true
        resultText = nil
        let payload: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "email": email.trimmingCharacters(in: .whitespaces),
            "subject": subject,
            "message": message,
            "app_name": "CramJam"
        ]
        var request = URLRequest(url: URL(string: "https://msg.calcs.top/api/feedback")!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                resultText = "Thanks! Your feedback has been sent."
                resultIsSuccess = true
                message = ""
            } else {
                resultText = "Could not send right now. Please try again later."
                resultIsSuccess = false
            }
        } catch {
            resultText = "Network error. Please try again later."
            resultIsSuccess = false
        }
        isSubmitting = false
    }
}
