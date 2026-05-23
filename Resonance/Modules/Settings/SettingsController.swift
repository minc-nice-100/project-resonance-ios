import UIKit
import Combine

class SettingsController: UITableViewController {

    private var cancellables = Set<AnyCancellable>()
    private let viewModel = SettingsViewModel()

    private enum Section: Int, CaseIterable {
        case dns
        case network
        case about
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    private func setupUI() {
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
    }

    private func setupBindings() {
        viewModel.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .dns:
            return 3
        case .network:
            return 2
        case .about:
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }

        switch sectionType {
        case .dns:
            return "DNS Settings"
        case .network:
            return "Network"
        case .about:
            return "About"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sectionType {
        case .dns:
            return configureDNSCell(for: indexPath)
        case .network:
            return configureNetworkCell(for: indexPath)
        case .about:
            return configureAboutCell(for: indexPath)
        }
    }

    private func configureDNSCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell.reuseIdentifier,
                                                    for: indexPath) as? SwitchCell else {
                return UITableViewCell()
            }
            cell.configure(title: "DNSSEC Validation",
                         isOn: viewModel.settings.enableDNSSEC) { [weak self] isOn in
                self?.viewModel.setDNSSEC(enabled: isOn)
            }
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "DNS Server"
            cell.detailTextLabel?.text = viewModel.settings.dnsServer
            cell.accessoryType = .disclosureIndicator
            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Clear DNS Cache"
            cell.textLabel?.textColor = .systemRed
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func configureNetworkCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell.reuseIdentifier,
                                                    for: indexPath) as? SwitchCell else {
                return UITableViewCell()
            }
            cell.configure(title: "Auto Discovery",
                         isOn: viewModel.settings.autoDiscovery) { [weak self] isOn in
                self?.viewModel.setAutoDiscovery(enabled: isOn)
            }
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Endpoint"
            cell.detailTextLabel?.text = viewModel.settings.endpoint ?? "Auto"
            cell.accessoryType = .disclosureIndicator
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func configureAboutCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = viewModel.appVersion
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Source Code"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .dns:
            handleDNSSelection(indexPath.row)
        case .network:
            handleNetworkSelection(indexPath.row)
        case .about:
            handleAboutSelection(indexPath.row)
        }
    }

    private func handleDNSSelection(_ row: Int) {
        switch row {
        case 1:
            showDNSServerPicker()
        case 2:
            clearDNSCache()
        default:
            break
        }
    }

    private func handleNetworkSelection(_ row: Int) {
        switch row {
        case 1:
            showEndpointEditor()
        default:
            break
        }
    }

    private func handleAboutSelection(_ row: Int) {
        switch row {
        case 1:
            openSourceCode()
        default:
            break
        }
    }

    private func showDNSServerPicker() {
        let alert = UIAlertController(title: "DNS Server",
                                     message: "Select DNS Server",
                                     preferredStyle: .actionSheet)

        let servers: [(String, DNSServerType)] = [
            ("Cloudflare (1.1.1.1)", .cloudflare),
            ("Google (8.8.8.8)", .google),
            ("Domestic", .domestic),
            ("System Default", .system)
        ]

        for (name, server) in servers {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.viewModel.setDNSServer(server)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func clearDNSCache() {
        let alert = UIAlertController(title: "Clear DNS Cache",
                                     message: "Are you sure you want to clear the DNS cache?",
                                     preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.viewModel.clearDNSCache()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func showEndpointEditor() {
        let alert = UIAlertController(title: "Endpoint",
                                     message: "Enter API endpoint URL",
                                     preferredStyle: .alert)

        alert.addTextField { [weak self] textField in
            textField.text = self?.viewModel.settings.endpoint
            textField.placeholder = "https://api.project-resonance.net"
            textField.keyboardType = .URL
        }

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text {
                self?.viewModel.setEndpoint(text.isEmpty ? nil : text)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func openSourceCode() {
        guard let url = URL(string: "https://github.com/project-resonance/resonance-ios") else { return }
        UIApplication.shared.open(url)
    }
}

class SwitchCell: UITableViewCell {
    static let reuseIdentifier = "SwitchCell"

    private let titleLabel = UILabel()
    private let switchControl = UISwitch()
    private var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(switchControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func switchChanged() {
        onToggle?(switchControl.isOn)
    }
}
