import Foundation
import Observation


@Observable
@MainActor
final class PredictionStore {
    private(set) var file: PredictionFile?
    private(set) var isRefreshing = false
    private(set) var statusMessage: String?

    static let remoteURLKey = "remoteURL"

    init() {
        loadLocal()
    }

    // MARK: - Local loading

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("predictions.json")
    }

    private static func decode(_ data: Data) throws -> PredictionFile {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PredictionFile.self, from: data)
    }

    func loadLocal() {
        var candidates: [PredictionFile] = []

        if let data = try? Data(contentsOf: Self.cacheURL),
           let cached = try? Self.decode(data) {
            candidates.append(cached)
        }
        if let url = Bundle.main.url(forResource: "predictions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? Self.decode(data) {
            candidates.append(bundled)
        }
        file = candidates.max(by: { $0.generatedAt < $1.generatedAt })
    }

    // MARK: - Remote refresh

    func refresh() async {
        let text = (UserDefaults.standard.string(forKey: Self.remoteURLKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = nil
            return
        }
        guard let url = URL(string: text), url.scheme?.hasPrefix("http") == true else {
            statusMessage = "That update URL isn't valid."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                statusMessage = "Server returned an error."
                return
            }
            let downloaded = try Self.decode(data)
            try data.write(to: Self.cacheURL, options: .atomic)
            if downloaded.generatedAt >= (file?.generatedAt ?? .distantPast) {
                file = downloaded
            }
            statusMessage = "Updated \(downloaded.generatedAt.formatted(date: .abbreviated, time: .shortened))"
        } catch {
            statusMessage = "Couldn't update: \(error.localizedDescription)"
        }
    }
}
