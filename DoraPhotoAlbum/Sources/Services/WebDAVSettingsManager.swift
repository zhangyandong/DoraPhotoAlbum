import Foundation

/// WebDAV settings sync layer:
/// - Writes to `NSUbiquitousKeyValueStore` (iCloud KVS) for restore after reinstall + cross-device sync
/// - Mirrors values into `UserDefaults` as a local cache / offline fallback
final class WebDAVSettingsManager {
    static let shared = WebDAVSettingsManager()
    
    private let defaults: UserDefaults
    private let kvs: NSUbiquitousKeyValueStore
    
    /// Keys that should be synced to iCloud.
    private let syncedKeys: Set<String> = [
        AppConstants.Keys.kWebDAVEnabled,
        AppConstants.Keys.kWebDAVHost,
        AppConstants.Keys.kWebDAVUser,
        AppConstants.Keys.kWebDAVPassword,
        AppConstants.Keys.kWebDAVSelectedPaths
    ]
    
    private init(defaults: UserDefaults = .standard, kvs: NSUbiquitousKeyValueStore = .default) {
        self.defaults = defaults
        self.kvs = kvs
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Sync
    
    /// Pull latest values from iCloud KVS into local `UserDefaults`.
    /// Call this at app launch to restore settings after reinstall.
    func syncFromiCloud(changedKeys: [String]? = nil, notify: Bool = true) {
        kvs.synchronize()
        
        let keysToSync: [String] = (changedKeys ?? Array(syncedKeys)).filter { syncedKeys.contains($0) }
        guard !keysToSync.isEmpty else { return }
        
        var didAffectWebDAV = false
        for key in keysToSync {
            if let value = kvs.object(forKey: key) {
                defaults.set(value, forKey: key)
                didAffectWebDAV = true
            }
        }
        defaults.synchronize()
        
        // If another device changed WebDAV settings, reload media source.
        if notify && didAffectWebDAV {
            NotificationCenter.default.post(name: .mediaSourceChanged, object: nil)
        }
    }

    /// Push local cached values (`UserDefaults`) to iCloud KVS.
    /// Useful for manual "upload" when iCloud KVS seems out of date or after first-time setup.
    func syncToiCloud() {
        for key in syncedKeys {
            if let value = defaults.object(forKey: key) {
                kvs.set(value, forKey: key)
            } else {
                kvs.removeObject(forKey: key)
            }
        }
        kvs.synchronize()
    }
    
    @objc private func handleUbiquitousStoreChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            syncFromiCloud()
            return
        }
        
        let changed = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        // Note: this notification only fires for *external* changes (server/account/initial sync).
        // There's no public "local change" reason constant in Swift.
        syncFromiCloud(changedKeys: changed, notify: true)
    }
    
    // MARK: - Getters
    
    func bool(forKey key: String) -> Bool {
        if kvs.object(forKey: key) != nil {
            return kvs.bool(forKey: key)
        }
        return defaults.bool(forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        if kvs.object(forKey: key) != nil {
            return kvs.string(forKey: key)
        }
        return defaults.string(forKey: key)
    }

    func stringArray(forKey key: String) -> [String]? {
        if kvs.object(forKey: key) != nil, let arr = kvs.array(forKey: key) as? [String] {
            return arr
        }
        return defaults.stringArray(forKey: key)
    }
    
    func object(forKey key: String) -> Any? {
        kvs.object(forKey: key) ?? defaults.object(forKey: key)
    }
    
    // MARK: - Setters
    
    func set(_ value: Any?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        
        if syncedKeys.contains(key) {
            if let value {
                kvs.set(value, forKey: key)
            } else {
                kvs.removeObject(forKey: key)
            }
            kvs.synchronize()
        }
        
        defaults.synchronize()
    }
    
    // MARK: - WebDAV Convenience
    
    func webDAVConfigIfComplete() -> WebDAVConfig? {
        guard let host = string(forKey: AppConstants.Keys.kWebDAVHost), !host.isEmpty,
              let user = string(forKey: AppConstants.Keys.kWebDAVUser),
              let pass = string(forKey: AppConstants.Keys.kWebDAVPassword) else {
            return nil
        }
        return WebDAVConfig(host: host, username: user, password: pass)
    }
}


