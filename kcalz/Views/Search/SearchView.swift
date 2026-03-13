import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    let onSelect: (OFFProduct) -> Void

    init(store: OFFStore, onSelect: @escaping (OFFProduct) -> Void) {
        _viewModel = State(initialValue: SearchViewModel(store: store))
        self.onSelect = onSelect
    }

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.kcHare)

                TextField("Rechercher un aliment…", text: $viewModel.query)
                    .font(.kcBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFocused)
                    .onChange(of: viewModel.query) {
                        viewModel.onQueryChanged()
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.kcHare)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Results
            if viewModel.query.count < 2 {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.kcSwan)
                    Text("Tape au moins 2 lettres")
                        .font(.kcBody)
                        .foregroundStyle(Color.kcHare)
                }
                Spacer()
            } else if viewModel.isSearching && viewModel.results.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.kcFeather)
                Spacer()
            } else if viewModel.results.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.kcSwan)
                    Text("Aucun résultat")
                        .font(.kcBody)
                        .foregroundStyle(Color.kcHare)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.results) { product in
                            Button { onSelect(product) } label: {
                                SearchResultRow(product: product)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.kcSnow)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color.kcPolar)
        .navigationTitle("Ajouter un aliment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isSearchFocused = true }
    }
}

private struct SearchResultRow: View {
    let product: OFFProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let brands = product.brands, !brands.isEmpty {
                    Text(brands)
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcWolf)
                        .lineLimit(1)
                }

                Spacer()

                if let kcal = product.kcal {
                    Text("\(Int(kcal)) kcal/100g")
                        .font(.kcCaption)
                        .foregroundStyle(Color.kcFeather)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.kcPolar)
                .frame(height: 2)
                .padding(.leading, 20)
        }
    }
}
