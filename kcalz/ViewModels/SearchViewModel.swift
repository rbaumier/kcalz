import Foundation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var results: [OFFProduct] = []
    private(set) var isSearching = false
    private(set) var error: Error?

    private let store: OFFStore
    private var searchTask: Task<Void, Never>?

    init(store: OFFStore) {
        self.store = store
    }

    func onQueryChanged() {
        searchTask?.cancel()
        error = nil

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
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    self.error = error
                    results = []
                    isSearching = false
                }
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        error = nil
        isSearching = false
    }
}
