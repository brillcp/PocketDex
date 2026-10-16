import SwiftUI

/// Every item in one category, with its effect text.
struct ItemDetailView<ViewModel: ItemDetailViewModelProtocol>: View {
    @State var viewModel: ViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignKit.Spacing.Primitive.s2) {
                ForEach(viewModel.items, id: \.id, content: ItemDetailRowView.init)
            }
        }
        .font(.pixel14)
        .foregroundStyle(.white)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .applyPokedexStyling(title: viewModel.title)
    }
}
