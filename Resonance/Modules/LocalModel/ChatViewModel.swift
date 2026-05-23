import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date

    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentModel: LocalModel?

    private let modelManager = ModelManager.shared

    init() {
        setupDefaultMessages()
    }

    private func setupDefaultMessages() {
        messages = [
            ChatMessage(content: "Welcome! I can run locally on your device. Select a model from the Models tab to get started.",
                       isUser: false)
        ]
    }

    func setModel(_ model: LocalModel) {
        currentModel = model
    }

    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(content: text, isUser: true)
        messages.append(userMessage)

        isLoading = true

        guard let model = currentModel else {
            let response = ChatMessage(content: "Please select a model first from the Models tab.", isUser: false)
            messages.append(response)
            isLoading = false
            return
        }

        processWithLocalModel(prompt: text, model: model)
    }

    private func processWithLocalModel(prompt: String, model: LocalModel) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let response = self.runInference(prompt: prompt, model: model)

            DispatchQueue.main.async {
                self.isLoading = false
                self.messages.append(ChatMessage(content: response, isUser: false))
            }
        }
    }

    private func runInference(prompt: String, model: LocalModel) -> String {
        guard let modelURL = modelManager.getModelURL(model.id) else {
            return "Model file not found. Please download it again."
        }

        do {
            let modelData = try Data(contentsOf: modelURL)
            return generateResponse(prompt: prompt, modelData: modelData)
        } catch {
            return "Failed to load model: \(error.localizedDescription)"
        }
    }

    private func generateResponse(prompt: String, modelData: Data) -> String {
        Thread.sleep(forTimeInterval: 1.0)

        let truncatedPrompt = String(prompt.prefix(100))
        let modelName = currentModel?.name ?? "Unknown"
        let modelSize = currentModel?.size ?? 0

        return """
        This is a simulated response from the local model.

        You sent: "\(truncatedPrompt)..."

        Model: \(modelName)
        Model size: \(modelSize / 1_000_000_000)GB

        Note: Actual local inference would require integrating with CoreML,
        Metal Performance Shaders, or a WASM-based runtime like Transformers.js.

        The app architecture supports:
        - CoreML models for Apple Neural Engine acceleration
        - Metal Performance Shaders for GPU inference
        - Transformers.js for WebAssembly-based inference

        To implement real local inference, you would need to:
        1. Convert a model to CoreML format
        2. Use CoreML framework for inference
        3. Or integrate transformers.js with a compatible model
        """
    }

    func clearHistory() {
        messages = []
        setupDefaultMessages()
    }
}
