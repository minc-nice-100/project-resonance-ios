import UIKit
import Combine

class LocalModelController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let chatView = ChatView()
    private var cancellables = Set<AnyCancellable>()

    private let modelManager = ModelManager.shared
    private let viewModel = ChatViewModel()

    private var isChatMode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    private func setupUI() {
        title = "Local Models"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        let segmentedControl = UISegmentedControl(items: ["Models", "Chat"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl

        setupTableView()
        setupChatView()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ModelCell.self, forCellReuseIdentifier: ModelCell.reuseIdentifier)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.isHidden = false
    }

    private func setupChatView() {
        chatView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chatView)

        NSLayoutConstraint.activate([
            chatView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            chatView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        chatView.delegate = self
        chatView.isHidden = true
    }

    private func setupBindings() {
        modelManager.$availableModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        modelManager.$downloadedModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.chatView.updateMessages(messages)
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.chatView.setLoading(isLoading)
            }
            .store(in: &cancellables)
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        isChatMode = sender.selectedSegmentIndex == 1
        tableView.isHidden = isChatMode
        chatView.isHidden = !isChatMode

        if isChatMode {
            chatView.focusInput()
        }
    }
}

extension LocalModelController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return modelManager.availableModels.count
        case 1:
            return modelManager.downloadedModels.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Available Models"
        case 1:
            return "Downloaded Models"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ModelCell.reuseIdentifier,
                                                  for: indexPath) as! ModelCell

        switch indexPath.section {
        case 0:
            let model = modelManager.availableModels[indexPath.row]
            cell.configure(with: model, isDownloaded: false, downloadProgress: nil)
        case 1:
            let model = modelManager.downloadedModels[indexPath.row]
            cell.configure(with: model, isDownloaded: true, downloadProgress: nil)
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            let model = modelManager.availableModels[indexPath.row]
            modelManager.downloadModel(model)
        case 1:
            let model = modelManager.downloadedModels[indexPath.row]
            viewModel.setModel(model)
        default:
            break
        }
    }
}

extension LocalModelController: ChatViewDelegate {
    func chatView(_ chatView: ChatView, didSendMessage message: String) {
        viewModel.sendMessage(message)
    }
}

class ModelCell: UITableViewCell {
    static let reuseIdentifier = "ModelCell"

    private let nameLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = .secondaryLabel

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true

        let stackView = UIStackView(arrangedSubviews: [nameLabel, statusLabel, progressView])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with model: LocalModel, isDownloaded: Bool, downloadProgress: Float?) {
        nameLabel.text = model.name

        if isDownloaded {
            statusLabel.text = "Downloaded"
            accessoryType = .checkmark
            progressView.isHidden = true
        } else if let progress = downloadProgress {
            statusLabel.text = "Downloading..."
            accessoryType = .none
            progressView.isHidden = false
            progressView.progress = progress
        } else {
            statusLabel.text = "Tap to download"
            accessoryType = .disclosureIndicator
            progressView.isHidden = true
        }
    }
}

protocol ChatViewDelegate: AnyObject {
    func chatView(_ chatView: ChatView, didSendMessage message: String)
}

class ChatView: UIView {
    weak var delegate: ChatViewDelegate?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let inputTextField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var messages: [ChatMessage] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .systemBackground

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseIdentifier)
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        inputContainer.backgroundColor = .systemBackground
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(inputContainer)

        inputTextField.placeholder = "Type a message..."
        inputTextField.borderStyle = .roundedRect
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputTextField)

        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(sendButton)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 60),

            inputTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44),

            loadingIndicator.centerXAnchor.constraint(equalTo: inputContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor)
        ])

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        inputTextField.inputAccessoryView = toolbar

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flexSpace, doneButton]
    }

    @objc private func sendTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        delegate?.chatView(self, didSendMessage: text)
        inputTextField.text = ""
    }

    @objc private func dismissKeyboard() {
        inputTextField.resignFirstResponder()
    }

    func focusInput() {
        inputTextField.becomeFirstResponder()
    }

    func updateMessages(_ messages: [ChatMessage]) {
        self.messages = messages
        tableView.reloadData()

        if !messages.isEmpty {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    func setLoading(_ isLoading: Bool) {
        if isLoading {
            loadingIndicator.startAnimating()
            sendButton.isHidden = true
        } else {
            loadingIndicator.stopAnimating()
            sendButton.isHidden = false
        }
    }
}

extension ChatView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseIdentifier,
                                                  for: indexPath) as! ChatMessageCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

class ChatMessageCell: UITableViewCell {
    static let reuseIdentifier = "ChatMessageCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.layer.cornerRadius = 12
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with message: ChatMessage) {
        messageLabel.text = message.content

        if message.isUser {
            bubbleView.backgroundColor = UIColor(hex: "#007AFF")
            messageLabel.textColor = .white

            NSLayoutConstraint.activate([
                bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
            ])
        } else {
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label

            NSLayoutConstraint.activate([
                bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)
            ])
        }
    }
}
