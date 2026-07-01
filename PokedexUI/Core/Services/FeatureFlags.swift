import Foundation

@Observable
final class FeatureFlags {
    private(set) var silhouetteEnabled: Bool = true
    private(set) var nameSortEnabled: Bool = false

    @MainActor
    func fetch() async {
        guard let url = URL(string: "https://gidlof.dev/wp-json/pokedex/v1/flags"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let payload = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        silhouetteEnabled = payload["silhouette"] == 1
        nameSortEnabled = payload["sortByName"] == 1            
    }
}
