import SwiftUI
import SwiftData

struct CoursesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var showAdd = false
    @State private var newCourseName = ""
    @State private var newCourseColor = "#FF6B35"

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(courses) { course in
                            NavigationLink {
                                CourseDetailView(course: course)
                            } label: {
                                courseRow(course)
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets {
                                modelContext.delete(courses[offset])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Courses")
            .toolbar {
                Button {
                    newCourseName = ""
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add course")
            }
            .alert("New course", isPresented: $showAdd) {
                TextField("Course name", text: $newCourseName)
                Button("Create") {
                    let name = newCourseName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    modelContext.insert(Course(name: name, colorHex: newCourseColor))
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                HStack {
                    ForEach(AppTheme.coursePalette, id: \.self) { hex in
                        Button {
                            newCourseColor = hex
                        } label: {
                            Circle().fill(AppTheme.courseColor(hex)).frame(width: 22, height: 22)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No courses yet")
                .font(.headline)
            Text("Tap + to add your first course.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func courseRow(_ course: Course) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.courseColor(course.colorHex))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.headline)
                Text("\(course.lectures.count) lectures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
