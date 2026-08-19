import Foundation

struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone = false
}

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] {
        didSet { save() }
    }

    private static let storageKey = "tasks"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = saved
        } else {
            tasks = []
        }
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(TaskItem(title: trimmed), at: 0)
    }

    func toggle(_ item: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        tasks[index].isDone.toggle()
    }

    func delete(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}