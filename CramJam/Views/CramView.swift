import SwiftUI
import SwiftData

struct CramView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchases: PurchaseManager
    @Query(sort: \ExamPlan.examDate) private var plans: [ExamPlan]
    @Query private var courses: [Course]

    @State private var selectedCourse = ""
    @State private var examDate = Date().addingTimeInterval(10 * 86400)
    @State private var dailyQuota = 20
    @State private var showPaywall = false
    @State private var showPlanReview = false
    @State private var sprintCardIDs: [UUID] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    countdownHeader
                    plannerForm
                    ForEach(plans) { plan in
                        planCard(plan)
                    }
                }
                .padding()
            }
            .navigationTitle("Cram")
            .sheet(isPresented: $showPaywall) {
                NavigationStack { PaywallView() }
            }
            .fullScreenCover(isPresented: $showPlanReview) {
                NavigationStack { ReviewView(limitIDs: sprintCardIDs) }
            }
        }
    }

    private var daysUntilExam: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: examDate)).day ?? 0
    }

    private var countdownHeader: some View {
        VStack(spacing: 6) {
            Text(daysUntilExam > 0 ? "Exam in \(daysUntilExam) days" : "Exam day is here")
                .font(.title.weight(.bold))
            Text("AI plans your cramming — weak cards first")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var plannerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New exam plan")
                .font(.headline)
            Picker("Course", selection: $selectedCourse) {
                Text("Choose course").tag("")
                ForEach(courses) { course in
                    Text(course.name).tag(course.name)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker("Exam date", selection: $examDate, displayedComponents: .date)
            Stepper("Daily quota: \(dailyQuota) cards", value: $dailyQuota, in: 5...60, step: 5)
            Button {
                generatePlan()
            } label: {
                Text("Generate plan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCourse.isEmpty)
            .accessibilityLabel("Generate cram plan")
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func planCard(_ plan: ExamPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.courseName)
                        .font(.headline)
                    Text("Exam \(plan.examDate.formatted(date: .abbreviated, time: .omitted)) · \(plan.dailyQuota) cards/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    modelContext.delete(plan)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .accessibilityLabel("Delete plan")
            }
            if let cramPlan = CramPlanner.decode(plan.planJSON) {
                ForEach(cramPlan.days) { day in
                    dayRow(day)
                }
            }
        }
        .padding()
        .background(Color.appMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func dayRow(_ day: CramPlanDay) -> some View {
        Button {
            sprintCardIDs = day.cardIDs
            showPlanReview = true
        } label: {
            HStack {
                Image(systemName: day.isSprint ? "bolt.fill" : "calendar")
                    .foregroundStyle(day.isSprint ? .appAccent : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.isSprint ? "48h Sprint Pack" : day.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(day.cardIDs.count) cards · \(day.weakCount) weak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if day.isSprint {
                    Text("High yield")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.appAccent.opacity(0.18))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(day.cardIDs.isEmpty)
        .accessibilityLabel("Study \(day.cardIDs.count) cards for \(day.date.formatted(date: .abbreviated, time: .omitted))")
    }

    private func generatePlan() {
        guard !selectedCourse.isEmpty else { return }
        if !purchases.isPro {
            showPaywall = true
            return
        }
        let all = (try? modelContext.fetch(FetchDescriptor<Flashcard>())) ?? []
        let cards = all.filter { $0.lecture?.course?.name == selectedCourse }
        let wrongLectureDates: Set<Date> = Set(
            ((try? modelContext.fetch(FetchDescriptor<QuizItem>())) ?? [])
                .filter { $0.isWrong }
                .compactMap { $0.lecture?.date }
        )
        let plan = CramPlanner.generate(courseName: selectedCourse, examDate: examDate, dailyQuota: dailyQuota, cards: cards, priorityLectureDates: wrongLectureDates)
        let examPlan = ExamPlan(courseName: selectedCourse, examDate: examDate, dailyQuota: plan.dailyQuota)
        examPlan.planJSON = CramPlanner.encode(plan)
        modelContext.insert(examPlan)
        try? modelContext.save()
    }
}
