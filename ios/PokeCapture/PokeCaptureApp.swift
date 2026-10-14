import SwiftUI

@main
@MainActor
struct PokeCaptureApp: App {
    @StateObject private var library = PokemonLibrary()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { PokemonListView() }
                    .tabItem { Label("Pokémon", systemImage: "list.bullet") }
                CaptureView()
                    .tabItem { Label("Scan", systemImage: "record.circle") }
            }
            .environmentObject(library)
            .task {
                while !Task.isCancelled {
                    if scenePhase == .active { library.refresh() }
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                    catch { break }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { library.refresh() }
            }
        }
    }
}
