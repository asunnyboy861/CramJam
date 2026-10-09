import SwiftUI

/// Explicit permission sheet (Guideline 5.1.2(i)): discloses WHAT data is sent,
/// WHO receives it, and asks for permission BEFORE any cloud request is made.
struct CloudConsentSheet: View {
    @ObservedObject var consent = CloudConsentCenter.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Cloud Generation Permission", systemImage: "icloud.and.arrow.up")
                        .font(.title3.bold())

                    Text("To create richer notes, flashcards and quizzes, CramJam can use cloud AI. Nothing is sent until you allow it below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    disclosureRow(icon: "doc.text",
                                 title: "What is sent",
                                 detail: "The text of your class transcript. When you import slides, the slide images. When you fix a typo, the single sentence involved.")

                    disclosureRow(icon: "server.rack",
                                  title: "Who receives it",
                                  detail: "CramJam's secure cloud relay (cramjam-api.calcs.top), which forwards it to the GLM model operated by Z.ai. If you add your own API key in Settings, your content is sent directly to the provider you chose instead.")

                    disclosureRow(icon: "target",
                                  title: "What it is used for",
                                  detail: "Only to generate your study materials. It is never sold and never used for advertising.")

                    disclosureRow(icon: "iphone.gen3",
                                  title: "On-device alternative",
                                  detail: "You can decline. On-device generation (Apple Intelligence) stays free, private, and works offline — nothing leaves your device.")

                    HStack(spacing: 8) {
                        Link(destination: URL(string: "https://asunnyboy861.github.io/CramJam/privacy.html")!) {
                            Label("Privacy Policy", systemImage: "lock.shield")
                                .font(.footnote)
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("Details also in Settings → AI Data & Privacy")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(spacing: 10) {
                        Button {
                            consent.grant()
                        } label: {
                            Text("Allow Cloud Generation")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            consent.deny()
                        } label: {
                            Text("Use On-Device Only")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .interactiveDismissDisabled()
        }
    }

    private func disclosureRow(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

/// In-app data-handling disclosure (Settings → AI Data & Privacy).
struct AIPrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How CramJam handles your data")
                    .font(.title3.bold())

                section("Stays on your device (free, private)",
                        "Recording, transcription, flashcard review, FSRS scheduling, streaks and course management all run locally. When generation uses on-device Apple Intelligence, your content never leaves the device.")

                section("Cloud generation (optional, needs your permission)",
                        "When you allow cloud generation, CramJam sends the text of your class transcript — or slide images you import, or the single sentence you are fixing — to CramJam's secure cloud relay (cramjam-api.calcs.top). The relay forwards it to the GLM model operated by Z.ai solely to produce your notes, flashcards and quizzes. It is never sold and never used for advertising.")

                section("Bring your own API key",
                        "If you add your own API key in Settings, cloud requests are sent directly from your device to the provider you selected (for example Z.ai, OpenAI, Google Gemini, DeepSeek or Anthropic). Your key is stored in the device Keychain and is never sent to CramJam's relay.")

                section("What CramJam collects",
                        "CramJam's relay does not store your transcripts or slides. The relay keeps only minimal operational records needed to run the service: your anonymous user identifier and credit balance for subscription and purchase validation. See the full Privacy Policy for the complete list.")

                section("Your control",
                        "You can turn cloud generation off at any time in Settings → AI Data & Privacy. When it is off, all generation falls back to on-device AI. You can also delete recordings and their transcripts on the lecture page at any time.")

                Link("Read the full Privacy Policy",
                     destination: URL(string: "https://asunnyboy861.github.io/CramJam/privacy.html")!)
                    .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle("AI Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold())
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
