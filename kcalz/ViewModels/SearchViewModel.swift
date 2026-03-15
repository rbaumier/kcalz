import Foundation

/// Drives the product search screen: debounced text search + barcode lookup.
@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    private(set) var results: [OFFProduct] = []
    private(set) var isSearching = false
    private(set) var error: Error?

    private static let debounceMs = 150
    /// EAN-8 is the shortest standard barcode format.
    nonisolated(unsafe) private static let minBarcodeLength = 8

    private let store: OFFStore
    private var searchTask: Task<Void, Never>?

    /// Creates a view model backed by the given OFF store.
    init(store: OFFStore) {
        self.store = store
    }

    /// Debounces the current query, then performs a barcode lookup or full-text search.
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
            try? await Task.sleep(for: .milliseconds(Self.debounceMs))
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

    /// Runs barcode lookup first (if input looks numeric), then falls back to FTS.
    nonisolated private func performSearch(query: String, store: OFFStore) async throws -> [OFFProduct] {
        // All-digit string with >= 8 chars → likely a barcode (EAN-8 is the shortest standard).
        if query.allSatisfy(\.isNumber), query.count >= Self.minBarcodeLength {
            if let product = store.findByBarcode(query) {
                return [product]
            }
        }
        return try store.search(query: query)
    }

    /// Resets the search state and clears results.
    func clearSearch() {
        searchTask?.cancel()
        query = ""
        results = []
        error = nil
        isSearching = false
    }
}
