import SwiftUI

struct SettingsView: View {
    @Environment(PredictionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PredictionStore.remoteURLKey) private var remoteURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/predictions.json", text: $remoteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Refresh now") { Task { await store.refresh() } }
                        .disabled(remoteURL.isEmpty || store.isRefreshing)
                    if let message = store.statusMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Update URL")
                } footer: {
                    Text("Optional. Host the file produced by `python -m src.export` anywhere (GitHub Pages, S3, …) and the app will download newer projections.")
                }

                if let file = store.file {
                    Section("Current data") {
                        LabeledContent("Generated", value: file.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Projection date", value: file.asOf)
                        if let through = file.dataThrough {
                            LabeledContent("Game data through", value: through)
                        }
                        if let trained = file.trainedThrough {
                            LabeledContent("Model trained through", value: trained)
                        }
                        LabeledContent("Players", value: "\(file.players.count)")
                    }
                    if let assumptions = file.assumptions {
                        Section("About the numbers") {
                            Text(assumptions).font(.footnote)
                            Text("These are statistical estimates, not guarantees.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
