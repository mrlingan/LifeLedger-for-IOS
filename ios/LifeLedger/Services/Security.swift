import Foundation
import CryptoKit
import Security
import LocalAuthentication

// Uses the same LIFELED1 / PBKDF2 / AES-GCM envelope as Android backups.
enum LedgerSecurity {
    static let backupMagic = Data("LIFELED1".utf8)
    static let localMagic = Data("LLLOCAL1".utf8)
    static func random(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw LedgerError.keychain(status) }
        return data
    }
    static func derive(password: String, salt: Data) throws -> SymmetricKey {
        let bytes = Array(password.utf8)
        var key = Data(count: 32)
        let result = key.withUnsafeMutableBytes { output in
            salt.withUnsafeBytes { saltBytes in
                bytes.withUnsafeBytes { pass in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pass.baseAddress!.assumingMemoryBound(to: Int8.self), bytes.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 120_000,
                        output.baseAddress!.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        guard result == kCCSuccess else { throw LedgerError.invalidPassword }
        return SymmetricKey(data: key)
    }
    static func encryptBackup(_ data: Data, password: String) throws -> Data {
        let salt = try random(16)
        let sealed = try AES.GCM.seal(data, using: derive(password: password, salt: salt))
        guard let combined = sealed.combined else { throw LedgerError.invalidBackup }
        return backupMagic + salt + combined
    }
    static func decryptBackup(_ data: Data, password: String) throws -> Data {
        guard data.starts(with: backupMagic), data.count >= 52, !password.isEmpty else { throw LedgerError.invalidPassword }
        do {
            let salt = data.subdata(in: 8..<24)
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data.dropFirst(24)), using: derive(password: password, salt: salt))
        } catch { throw LedgerError.invalidPassword }
    }
    static func getSecret(_ account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mrlingan.lifeledger", kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw LedgerError.keychain(status) }
        return item as? Data
    }
    static func setSecret(_ data: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mrlingan.lifeledger", kSecAttrAccount as String: account]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var entry = query
            entry[kSecValueData as String] = data
            entry[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let add = SecItemAdd(entry as CFDictionary, nil)
            guard add == errSecSuccess else { throw LedgerError.keychain(add) }
        } else if status != errSecSuccess { throw LedgerError.keychain(status) }
    }
    static func deleteSecret(_ account: String) throws {
        let result = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mrlingan.lifeledger", kSecAttrAccount as String: account] as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw LedgerError.keychain(result) }
    }
    static func localKey(create: Bool) throws -> SymmetricKey {
        if let data = try getSecret("encryption-key") { return SymmetricKey(data: data) }
        guard create else { throw LedgerError.keychain(errSecItemNotFound) }
        let key = try random(32)
        try setSecret(key, account: "encryption-key")
        return SymmetricKey(data: key)
    }
    static func encryptLocal(_ data: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: localKey(create: true))
        return localMagic + sealed.combined!
    }
    static func decryptLocal(_ data: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data.dropFirst(localMagic.count)), using: localKey(create: false))
    }
    static func setPIN(_ pin: String) throws {
        guard pin.count == 6, pin.allSatisfy({ $0.isASCII && $0.isNumber }) else { throw LedgerError.invalidInput }
        let salt = try random(16)
        let key = try derive(password: pin, salt: salt)
        try setSecret(salt + key.withUnsafeBytes { Data($0) }, account: "app-pin")
    }
    static func verifyPIN(_ pin: String) throws -> Bool {
        guard !pin.isEmpty, let saved = try getSecret("app-pin"), saved.count == 48 else { return false }
        let actual = try derive(password: pin, salt: saved.prefix(16)).withUnsafeBytes { Data($0) }
        let expected = saved.suffix(32)
        return zip(actual, expected).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
    static func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LedgerError.invalidInput as NSError
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}
