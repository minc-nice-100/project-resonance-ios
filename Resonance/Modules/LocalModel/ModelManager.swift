import Foundation
import Combine

struct LocalModel: Identifiable, Codable {
    let id: String
    let name: String
    let size: Int64
    let description: String
    let url: String
}

class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var availableModels: [LocalModel] = []
    @Published var downloadedModels: [LocalModel] = []
    @Published var downloadProgress: [String: Float] = [:]
    @Published var currentModel: LocalModel?

    private let fileManager = FileManager.default
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]

    private var modelsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let modelsPath = paths[0].appendingPathComponent("Models")

        if !fileManager.fileExists(atPath: modelsPath.path) {
            try? fileManager.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }

        return modelsPath
    }

    init() {
        loadDownloadedModels()
        loadAvailableModels()
    }

    private func loadAvailableModels() {
        availableModels = [
            LocalModel(id: "resonance-3b",
                      name: "Resonance 3B",
                      size: 2_000_000_000,
                      description: "Small model for fast inference",
                      url: "https://models.project-resonance.net/resonance-3b.bin"),
            LocalModel(id: "resonance-7b",
                      name: "Resonance 7B",
                      size: 4_000_000_000,
                      description: "Medium model for balanced performance",
                      url: "https://models.project-resonance.net/resonance-7b.bin"),
            LocalModel(id: "resonance-13b",
                      name: "Resonance 13B",
                      size: 8_000_000_000,
                      description: "Large model for high quality",
                      url: "https://models.project-resonance.net/resonance-13b.bin")
        ]
    }

    private func loadDownloadedModels() {
        guard let contents = try? fileManager.contentsOfDirectory(at: modelsDirectory,
                                                                  includingPropertiesForKeys: nil) else {
            return
        }

        downloadedModels = contents.compactMap { url -> LocalModel? in
            guard url.pathExtension == "bin" else { return nil }

            let name = url.deletingPathExtension().lastPathComponent
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            let size = attributes?[.size] as? Int64 ?? 0

            return LocalModel(id: name,
                             name: name.replacingOccurrences(of: "-", with: " ").capitalized,
                             size: size,
                             description: "Downloaded model",
                             url: url.absoluteString)
        }
    }

    func downloadModel(_ model: LocalModel) {
        guard downloadTasks[model.id] == nil else { return }

        guard let url = URL(string: model.url) else { return }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            guard let self = self else { return }

            self.downloadTasks.removeValue(forKey: model.id)
            self.downloadProgress.removeValue(forKey: model.id)

            if let error = error {
                print("Download failed: \(error)")
                return
            }

            guard let tempURL = tempURL else { return }

            let destinationURL = self.modelsDirectory.appendingPathComponent("\(model.id).bin")

            do {
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }

                try self.fileManager.moveItem(at: tempURL, to: destinationURL)

                DispatchQueue.main.async {
                    self.loadDownloadedModels()
                }
            } catch {
                print("Failed to save model: \(error)")
            }
        }

        downloadTasks[model.id] = task

        let observation = task.progress.publisher(for: \.fractionCompleted)
            .sink { [weak self] fraction in
                DispatchQueue.main.async {
                    self?.downloadProgress[model.id] = Float(fraction)
                }
            }

        task.resume()
    }

    func deleteModel(_ model: LocalModel) {
        let modelURL = modelsDirectory.appendingPathComponent("\(model.id).bin")

        do {
            try fileManager.removeItem(at: modelURL)
            loadDownloadedModels()
        } catch {
            print("Failed to delete model: \(error)")
        }
    }

    func isModelDownloaded(_ modelId: String) -> Bool {
        return downloadedModels.contains { $0.id == modelId }
    }

    func getModelURL(_ modelId: String) -> URL? {
        let modelURL = modelsDirectory.appendingPathComponent("\(modelId).bin")
        return fileManager.fileExists(atPath: modelURL.path) ? modelURL : nil
    }
}
