import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        appCoordinator = AppCoordinator(window: window)
        appCoordinator?.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "resonance" else { return }

        if url.host == "local" {
            appCoordinator?.switchToLocalTab()
        } else if url.host == "settings" {
            appCoordinator?.switchToSettingsTab()
        }
    }
}

class AppCoordinator {
    private let window: UIWindow
    private var tabBarController: UITabBarController?

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let tabBarController = UITabBarController()
        self.tabBarController = tabBarController

        let webViewController = MainWebViewController()
        webViewController.tabBarItem = UITabBarItem(title: "Web",
                                                     image: UIImage(systemName: "globe"),
                                                     selectedImage: UIImage(systemName: "globe.fill"))

        let localModelController = LocalModelController()
        localModelController.tabBarItem = UITabBarItem(title: "Local",
                                                       image: UIImage(systemName: "cpu"),
                                                       selectedImage: UIImage(systemName: "cpu.fill"))

        let settingsController = SettingsController()
        settingsController.tabBarItem = UITabBarItem(title: "Settings",
                                                     image: UIImage(systemName: "gear"),
                                                     selectedImage: UIImage(systemName: "gear.circle.fill"))

        let webNav = UINavigationController(rootViewController: webViewController)
        let localNav = UINavigationController(rootViewController: localModelController)
        let settingsNav = UINavigationController(rootViewController: settingsController)

        tabBarController.viewControllers = [webNav, localNav, settingsNav]
        tabBarController.selectedIndex = 0

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }

    func switchToLocalTab() {
        tabBarController?.selectedIndex = 1
    }

    func switchToSettingsTab() {
        tabBarController?.selectedIndex = 2
    }
}
