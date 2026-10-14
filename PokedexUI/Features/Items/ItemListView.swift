import SwiftUI
import SwiftData

/// Items tab showing a paginated list of every PokeAPI item.
struct ItemListView<ViewModel: ItemListViewModelProtocol>: View {
    @State var viewModel: ViewModel
    @State private var selectedItem: ItemData?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.items, id: \.title, content: itemRow)
                }
            }
            .font(.pixel14)
            .foregroundStyle(.white)
            .scrollIndicators(.hidden)
            .background {
                if viewModel.isLoading {
                    PixelSpinner(text: "Loading items")
                }
            }
            .task { await viewModel.loadItems() }
            .applyPokedexStyling(title: Tabs.items.title)
            .navigationDestination(item: $selectedItem) { item in
                ItemDetailView(viewModel: ItemDetailViewModel(item: item))
            }
        }
    }
}

// MARK: - Private
private extension ItemListView {
    func itemRow(for item: ItemData) -> some View {
        Button {
            selectedItem = item
        } label: {
            ItemRowView(item: item)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable
    @Environment(\.modelContext) var modelContext
    ItemListView(viewModel: ItemListViewModel(modelContext: modelContext, container: .live))
}
