import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            CoursesView()
                .tabItem { Label("Courses", systemImage: "books.vertical.fill") }
                .tag(1)
            CramView()
                .tabItem { Label("Cram", systemImage: "timer") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .frame(maxWidth: 720)
        .fullScreenCover(isPresented: Binding(
            get: { !hasOnboarded },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetBridge.updateDueCount(Flashcard.dueCount(modelContext))
            }
        }
    }
}
