import SwiftUI
import SwiftData

struct GlossaryView: View {
    let courseName: String

    @Environment(\.modelContext) private var modelContext
    @Query private var terms: [GlossaryTerm]
    @State private var newTerm = ""
    @State private var newDefinition = ""
    @State private var editingTerm: GlossaryTerm?
    @State private var editValue = ""

    init(courseName: String) {
        self.courseName = courseName
        _terms = Query(
            filter: #Predicate<GlossaryTerm> { $0.courseName == courseName },
            sort: [SortDescriptor(\GlossaryTerm.term)]
        )
    }

    var body: some View {
        List {
            Section("Add term") {
                TextField("Term", text: $newTerm)
                TextField("Definition", text: $newDefinition)
                Button("Add to glossary") {
                    let term = newTerm.trimmingCharacters(in: .whitespaces)
                    guard !term.isEmpty else { return }
                    modelContext.insert(GlossaryTerm(term: term, definition: newDefinition.trimmingCharacters(in: .whitespaces), courseName: courseName))
                    newTerm = ""
                    newDefinition = ""
                }
                .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Terms (\(terms.count))") {
                if terms.isEmpty {
                    Text("Add course-specific terms so CramJam can fix mis-heard words in transcripts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(terms) { term in
                    Button {
                        editValue = term.definition
                        editingTerm = term
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(term.term)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(term.hits) hits")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if !term.definition.isEmpty {
                                Text(term.definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(terms[offset])
                    }
                }
            }
        }
        .navigationTitle("Glossary")
        .sheet(item: $editingTerm) { term in
            NavigationStack {
                Form {
                    TextField("Definition", text: $editValue)
                    Button("Save") {
                        term.definition = editValue
                        editingTerm = nil
                    }
                }
                .navigationTitle(term.term)
                .toolbar {
                    Button("Done") { editingTerm = nil }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
