import Foundation

/// The stats the model predicts. Raw values match the keys in predictions.json.
enum Stat: String, CaseIterable, Identifiable {
    case pts = "PTS"
    case reb = "REB"
    case ast = "AST"
    case fg3m = "FG3M"
    case tov = "TOV"
    case stl = "STL"
    case blk = "BLK"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pts: return "Points"
        case .reb: return "Rebounds"
        case .ast: return "Assists"
        case .fg3m: return "3-Pointers Made"
        case .tov: return "Turnovers"
        case .stl: return "Steals"
        case .blk: return "Blocks"
        }
    }

    var short: String {
        switch self {
        case .fg3m: return "3PM"
        default: return rawValue
        }
    }
}

/// Predicted quantiles for one stat. p10...p90 is the 80% interval.
struct QuantileSet: Codable, Hashable {
    let p10: Double
    let p25: Double
    let p50: Double
    let p75: Double
    let p90: Double
}

struct GameLine: Codable, Identifiable, Hashable {
    let date: String          // "2026-11-18"
    let opp: String?
    let home: Bool
    let wl: String?
    let min: Double?
    let stats: [String: Double]

    var id: String { date + (opp ?? "") }

    func value(_ stat: Stat) -> Double? { stats[stat.rawValue] }

    var opponentLabel: String {
        guard let opp else { return "—" }
        return home ? "vs \(opp)" : "@ \(opp)"
    }

    var shortDate: String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withFullDate]
        guard let d = parser.date(from: date) else { return date }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let team: String
    let projection: [String: QuantileSet]
    let recent: [GameLine]          // most recent first

    func quantiles(_ stat: Stat) -> QuantileSet? { projection[stat.rawValue] }
    func median(_ stat: Stat) -> Double { projection[stat.rawValue]?.p50 ?? 0 }

    func recentAverage(_ stat: Stat) -> Double? {
        let values = recent.compactMap { $0.value(stat) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

struct PredictionFile: Codable {
    let generatedAt: Date
    let asOf: String
    let trainedThrough: String?
    let dataThrough: String?
    let assumptions: String?
    let stats: [String]
    let players: [Player]
}

func formatStat(_ value: Double) -> String {
    String(format: "%.1f", value)
}
