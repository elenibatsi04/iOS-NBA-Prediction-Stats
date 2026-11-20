import SwiftUI

struct PlayerDetailView: View {
    let player: Player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next-game projection")
                    .font(.headline)
                Text("Number = median. Bar = 80% range (light) and middle 50% (dark). Dots = last games.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Stat.allCases) { stat in
                    if let q = player.quantiles(stat) {
                        StatCard(
                            stat: stat,
                            q: q,
                            recent: player.recent.compactMap { $0.value(stat) },
                            recentAverage: player.recentAverage(stat)
                        )
                    }
                }

                RecentGamesTable(games: player.recent)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatCard: View {
    let stat: Stat
    let q: QuantileSet
    let recent: [Double]
    let recentAverage: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(stat.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatStat(q.p50))
                    .font(.title.bold().monospacedDigit())
            }
            RangeBar(q: q, recent: recent)
                .frame(height: 22)
            HStack {
                Text("80% range: \(formatStat(q.p10)) – \(formatStat(q.p90))")
                Spacer()
                if let avg = recentAverage {
                    Text("Recent avg \(formatStat(avg))")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}


struct RangeBar: View {
    let q: QuantileSet
    let recent: [Double]

    private func xPos(_ value: Double, maxValue: Double, width: CGFloat) -> CGFloat {
        CGFloat(min(max(value / maxValue, 0), 1)) * width
    }

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(q.p90, recent.max() ?? 0, 1) * 1.1
            let width = geo.size.width
            let x10 = xPos(q.p10, maxValue: maxValue, width: width)
            let x25 = xPos(q.p25, maxValue: maxValue, width: width)
            let x50 = xPos(q.p50, maxValue: maxValue, width: width)
            let x75 = xPos(q.p75, maxValue: maxValue, width: width)
            let x90 = xPos(q.p90, maxValue: maxValue, width: width)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))

                Capsule().fill(Color.orange.opacity(0.35))
                    .frame(width: max(x90 - x10, 6))
                    .offset(x: x10)

                Capsule().fill(Color.orange)
                    .frame(width: max(x75 - x25, 6))
                    .offset(x: x25)

                Rectangle().fill(Color.primary)
                    .frame(width: 3, height: geo.size.height)
                    .offset(x: x50 - 1.5)

                ForEach(recent.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .offset(x: xPos(recent[i], maxValue: maxValue, width: width) - 3.5)
                }
            }
        }
    }
}

private struct RecentGamesTable: View {
    let games: [GameLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent games").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("Date").gridColumnAlignment(.leading)
                        Text("Opp").gridColumnAlignment(.leading)
                        Text("MIN")
                        ForEach(Stat.allCases) { Text($0.short) }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                    Divider().gridCellUnsizedAxes(.horizontal)

                    ForEach(games) { game in
                        GridRow {
                            Text(game.shortDate)
                            Text(game.opponentLabel)
                            Text(game.min.map { String(format: "%.0f", $0) } ?? "–")
                            ForEach(Stat.allCases) { stat in
                                Text(game.value(stat).map { String(format: "%.0f", $0) } ?? "–")
                            }
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
            }
        }
    }
}
