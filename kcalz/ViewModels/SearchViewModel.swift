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
        let currentQuery = query
        let store = store
        searchTask = Task.detached {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            // Barcode lookup first if query is all digits
            if currentQuery.allSatisfy(\.isNumber), currentQuery.count >= 8 {
                if let product = store.findByBarcode(currentQuery) {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.results = [product]
                        self.isSearching = false
                    }
                    return
                }
            }

            do {
                let found = try store.search(query: currentQuery)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = found
                    self.isSearching = false
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.error = error
                    self.results = []
                    self.isSearching = false
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
