import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var results: [OFFProduct] = []
    var isSearching = false

    private let store: OFFStore
    private var searchTask: Task<Void, Never>?

    init(store: OFFStore) {
        self.store = store
    }

    func onQueryChanged() {
        searchTask?.cancel()

        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            do {
                let found = try store.search(query: query)
                if !Task.isCancelled {
                    results = found
                    isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    results = []
                    isSearching = false
                }
            }
        }
    }
}
