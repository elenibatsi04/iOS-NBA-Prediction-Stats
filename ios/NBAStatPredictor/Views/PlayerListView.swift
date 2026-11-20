import SwiftUI

struct PlayerListView: View {
    @Environment(PredictionStore.self) private var store
    @State private var search = ""
    @State private var sortStat: Stat? = nil     // nil = sort by name
    @State private var showSettings = false

    private var players: [Player] {
        let all = store.file?.players ?? []
        let filtered = search.isEmpty ? all : all.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.team.localizedCaseInsensitiveContains(search)
        }
        if let stat = sortStat {
            return filtered.sorted { $0.median(stat) > $1.median(stat) }
        }
        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.file == nil {
                    ContentUnavailableView(
                        "No projections yet",
                        systemImage: "sportscourt",
                        description: Text("Run `python -m src.export` and rebuild the app, or set an update URL in Settings.")
                    )
                } else {
                    List(players) { player in
                        NavigationLink(value: player) {
                            PlayerRow(player: player, highlight: sortStat)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Stat Predictor")
            .navigationDestination(for: Player.self) { PlayerDetailView(player: $0) }
            .searchable(text: $search, prompt: "Search players or teams")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Name") { sortStat = nil }
                        Divider()
                        ForEach(Stat.allCases) { stat in
                            Button("Projected \(stat.title)") { sortStat = stat }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environment(store)
            }
            .refreshable { await store.refresh() }
            .overlay(alignment: .top) {
                if store.isRefreshing { ProgressView().padding(.top, 8) }
            }
        }
    }
}

private struct PlayerRow: View {
    let player: Player
    let highlight: Stat?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.headline)
                Text(player.team).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                ForEach([Stat.pts, .reb, .ast], id: \.self) { stat in
                    VStack(spacing: 0) {
                        Text(formatStat(player.median(stat)))
                            .font(.subheadline.monospacedDigit().weight(stat == highlight ? .bold : .regular))
                        Text(stat.short).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
