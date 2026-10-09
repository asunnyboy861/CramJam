import SwiftUI
import SwiftData

@main
struct CramJamApp: App {
    @StateObject private var purchases = PurchaseManager.shared
    @StateObject private var pipelineMonitor = PipelineMonitor.shared
    @StateObject private var glm = GLMService.shared
    @StateObject private var cloudConsent = CloudConsentCenter.shared

    private let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Course.self,
            Lecture.self,
            Sentence.self,
            Flashcard.self,
            GlossaryTerm.self,
            ExamPlan.self,
            QuizItem.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [memoryConfig]))!
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .environmentObject(purchases)
                .environmentObject(pipelineMonitor)
                .environmentObject(glm)
                .environmentObject(cloudConsent)
                .sheet(isPresented: $cloudConsent.showConsentSheet) {
                    CloudConsentSheet()
                }
                .tint(.appAccent)
                .preferredColorScheme(.dark)
        }
    }
}
