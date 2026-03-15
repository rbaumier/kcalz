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
        isSearching = false
        error = nil

        guard query.count >= 2 else {
            results = []
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            let currentQuery = query
            let store = store

            do {
                let found = try await performSearch(query: currentQuery, store: store)
                guard currentQuery == self.query, !Task.isCancelled else { return }
                results = found
                isSearching = false
            } catch is CancellationError {
                return
            } catch {
                guard currentQuery == self.query, !Task.isCancelled else { return }
                self.error = error
                results = []
                isSearching = false
            }
        }
    }

    nonisolated private func performSearch(query: String, store: OFFStore) async throws -> [OFFProduct] {
        if query.allSatisfy(\.isNumber), query.count >= 8 {
            if let product = store.findByBarcode(query) {
                return [product]
            }
        }
        return try store.search(query: query)
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        error = nil
        isSearching = false
    }
}
