import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.tasks) { task in
                    HStack {
                        Button {
                            store.toggle(task)
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(task.title)
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                    }
                }
                .onDelete(perform: store.delete)
            }
            .navigationTitle("待办清单")
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    TextField("添加新任务，回车确认", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit(submit)

                    Button("添加", action: submit)
                        .buttonStyle(.borderedProminent)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func submit() {
        store.add(title: newTitle)
        newTitle = ""
    }
}