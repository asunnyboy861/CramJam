import Foundation
import Security

enum KeychainHelper {
    static let service = "com.zzoutuo.CramJam"
    static let byoKeyAccount = "glm_byo_key"
    static let userUUIDAccount = "user_uuid"

    static func set(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var glmKey: String {
        get { get(account: byoKeyAccount) ?? "" }
        set { set(newValue, account: byoKeyAccount) }
    }

    static var hasBYOKey: Bool {
        !glmKey.isEmpty
    }

    static var userUUID: String {
        if let existing = get(account: userUUIDAccount), !existing.isEmpty { return existing }
        let fresh = UUID().uuidString
        set(fresh, account: userUUIDAccount)
        return fresh
    }
}
