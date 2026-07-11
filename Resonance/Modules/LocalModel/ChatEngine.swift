import Foundation
import Combine

protocol ChatEngine {
    var messages: [ChatMessage] { get }
    var isLoading: Bool { get }
    var currentModel: LocalModel? { get }

    var messagesPublisher: AnyPublisher<[ChatMessage], Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }

    func setModel(_ model: LocalModel)
    func sendMessage(_ text: String)
    func clearHistory()
}

protocol ModelStore {
    var availableModels: [LocalModel] { get }
    var downloadedModels: [LocalModel] { get }
    var downloadProgress: [String: Float] { get }

    var availableModelsPublisher: AnyPublisher<[LocalModel], Never> { get }
    var downloadedModelsPublisher: AnyPublisher<[LocalModel], Never> { get }

    func downloadModel(_ model: LocalModel)
    func deleteModel(_ model: LocalModel)
    func isModelDownloaded(_ modelId: String) -> Bool
    func getModelURL(_ modelId: String) -> URL?
}