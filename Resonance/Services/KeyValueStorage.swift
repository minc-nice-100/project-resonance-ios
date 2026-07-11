import Foundation

protocol KeyValueStorage {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func remove(forKey key: String)
}

class UserDefaultsStorage: KeyValueStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func data(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }

    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

class InMemoryStorage: KeyValueStorage {
    private var storage: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        return storage[key]
    }

    func set(_ data: Data, forKey key: String) {
        storage[key] = data
    }

    func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}