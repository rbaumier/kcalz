import SwiftUI

/// Main search screen — lets the user find food by text query, history, or barcode scan.
struct SearchView: View {
    @State private var viewModel: SearchViewModel
    let userStore: UserStore
    let onSelect: (OFFProduct) -> Void
    let onSelectRecent: (FoodEntry) -> Void
    let onScan: () -> Void
    let onCreateFood: (String) -> Void
    let onSelectCustom: (UserStore.ProductOverride) -> Void

    @State private var customFoods: [UserStore.ProductOverride] = []
    @State private var recentFoods: [FoodEntry] = []
    @State private var frequentFoods: [FoodEntry] = []
    @AppStorage("searchShowFrequent") private var showFrequent = false

    /// Creates the search view with its dependencies and navigation callbacks.
    init(store: OFFStore, userStore: UserStore, onSelect: @escaping (OFFProduct) -> Void, onSelectRecent: @escaping (FoodEntry) -> Void, onScan: @escaping () -> Void, onCreateFood: @escaping (String) -> Void, onSelectCustom: @escaping (UserStore.ProductOverride) -> Void) {
        _viewModel = State(initialValue: SearchViewModel(store: store))
        self.userStore = userStore
        self.onSelect = onSelect
        self.onSelectRecent = onSelectRecent
        self.onScan = onScan
        self.onCreateFood = onCreateFood
        self.onSelectCustom = onSelectCustom
    }

    @FocusState private var isSearchFocused: Bool

    /// Returns history entries (recent or frequent) filtered by the current query when long enough.
    private var historyFoods: [FoodEntry] {
        let source = showFrequent ? frequentFoods : recentFoods
        if viewModel.query.count < 2 { return source }
        return source.filter { $0.name.localizedCaseInsensitiveContains(viewModel.query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.kcIconMedium)
                    .foregroundStyle(Color.kcHare)

                TextField("Rechercher un aliment…", text: $viewModel.query)
                    .font(.kcBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .onChange(of: viewModel.query) {
                        viewModel.onQueryChanged()
                        customFoods = userStore.searchCustomFoods(query: viewModel.query)
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.kcIconMedium)
                            .foregroundStyle(Color.kcHare)
                    }
                }

                Button { onScan() } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcFeather)
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 12)
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Historique
                    if !historyFoods.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Historique")
                                    .font(.kcHeadline)
                                    .foregroundStyle(Color.kcEel)

                                Spacer()

                                Button {
                                    showFrequent.toggle()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: showFrequent ? "flame.fill" : "clock")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(showFrequent ? "Les plus utilisés" : "Les plus récents")
                                            .font(.kcCaption)
                                    }
                                    .foregroundStyle(Color.kcWolf)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.kcSnow)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                                        .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 3)
                                }
                            }
                            .padding(.horizontal, 4)

                            LazyVStack(spacing: 0) {
                                ForEach(Array(historyFoods.enumerated()), id: \.element.id) { i, entry in
                                    if i > 0 {
                                        Rectangle()
                                            .fill(Color.kcPolar)
                                            .frame(height: 2)
                                            .padding(.leading, Theme.cardInnerPadding)
                                    }
                                    Button { onSelectRecent(entry) } label: {
                                        FoodRow(name: entry.name, brands: entry.brands, detail: "\(Int(entry.kcalPer100g * entry.grams / 100))", detailSuffix: "kcal / \(Int(entry.grams))g")
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .kcCard()
                        }
                    }

                    // MARK: - Mes aliments
                    if !customFoods.isEmpty {
                        VStack(spacing: 8) {
                            Text("Mes aliments")
                                .font(.kcHeadline)
                                .foregroundStyle(Color.kcEel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)

                            LazyVStack(spacing: 0) {
                                ForEach(Array(customFoods.enumerated()), id: \.element.code) { i, custom in
                                    if i > 0 {
                                        Rectangle()
                                            .fill(Color.kcPolar)
                                            .frame(height: 2)
                                            .padding(.leading, Theme.cardInnerPadding)
                                    }
                                    Button { onSelectCustom(custom) } label: {
                                        FoodRow(name: custom.name ?? "", brands: nil, detail: "\(Int(custom.kcal))", detailSuffix: "kcal / 100g")
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .kcCard()
                        }
                    }

                    // MARK: - Tous les résultats
                    if viewModel.query.count >= 2 {
                        VStack(spacing: 8) {
                            Text("Tous les résultats")
                                .font(.kcHeadline)
                                .foregroundStyle(Color.kcEel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)

                            if viewModel.isSearching && viewModel.results.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(Color.kcFeather)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else if viewModel.results.isEmpty && customFoods.isEmpty {
                                VStack(spacing: 12) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "fork.knife")
                                            .font(.kcIcon)
                                            .foregroundStyle(Color.kcHare)
                                        Text("Aucun résultat")
                                            .font(.kcEmptyText)
                                            .foregroundStyle(Color.kcHare)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .kcCard()

                                    Button { onCreateFood(viewModel.query) } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.kcIconMedium)
                                            Text("Créer « \(viewModel.query) »")
                                                .font(.kcBody)
                                        }
                                        .foregroundStyle(Color.kcFeather)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .kcCard()
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { i, product in
                                        if i > 0 {
                                            Rectangle()
                                                .fill(Color.kcPolar)
                                                .frame(height: 2)
                                                .padding(.leading, Theme.cardInnerPadding)
                                        }
                                        Button { onSelect(product) } label: {
                                            FoodRow(name: product.name, brands: product.brands, detail: product.kcal.map { "\(Int($0))" } ?? "—", detailSuffix: "kcal / 100g")
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .kcCard()
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.bottom, 32)
            }
        }
        .background(Color.kcPolar)
        .navigationTitle("Ajouter un aliment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isSearchFocused = true
            recentFoods = (try? userStore.recentFoods()) ?? []
            frequentFoods = (try? userStore.frequentFoods()) ?? []
        }
    }
}

// MARK: - Rows

/// A single row displaying a food item with name, brand, and calorie summary.
private struct FoodRow: View {
    let name: String
    let brands: String?
    let detail: String
    let detailSuffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let brands, !brands.isEmpty {
                    Text(brands)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 3) {
                    Text(detail)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.kcFeather)
                    Text(detailSuffix)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                }
            }
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 10)
    }
}
