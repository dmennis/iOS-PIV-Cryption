//
//  Untitled.swift
//  PIVCryption
//
//  Created by Dennis Hills on 1/9/25.
//
import SwiftUI
import Security
import Foundation

class CryptoManager: ObservableObject {
    @Published var encryptedMessage: Data? = nil
    @Published var decryptedMessage: String? = nil
    @Published var tokens: [[String: Any]] = []
//    let PRIVATE_KEY_TAG = "com.example.privatekey".data(using: .utf8)!
//    let YUBICO_AUTHENTICATOR_TOKEN = "com.yubico.Authenticator.TokenExtension:972BC027C9E349CFA63856C2A2968F16ABDDE71564A94570EE131DEA92E9BB0F".data(using: .utf8)!
//    
    func encryptMessage(_ message: String) {
        guard let privateKey = getPrivateKey() else {
            print("Private key unavailable.")
            return
        }

        do {
            guard let messageData = message.data(using: .utf8) else {
                print("Invalid message encoding.")
                return
            }

            let publicKey = SecKeyCopyPublicKey(privateKey)
            if let encryptedData = SecKeyCreateEncryptedData(publicKey!, .rsaEncryptionOAEPSHA256, messageData as CFData, nil) as Data? {
                self.encryptedMessage = encryptedData
            } else {
                throw NSError(domain: "EncryptionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt data."])
            }
        } catch {
            print("Encryption error: \(error)")
        }
    }
    
    func decryptMessage() {
        guard let privateKey = getPrivateKey() else {
            print("Decryption failed: Private key not found.")
            return
        }

        guard let encryptedMessage = encryptedMessage else {
            print("Decryption failed: Encrypted message is nil.")
            return
        }

        do {
            print("Encrypted (ciphertext) Message (base64Encoded): \(encryptedMessage.base64EncodedString())")

            if let decryptedData = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA256, encryptedMessage as CFData, nil) as Data? {
                
                print("Decrypted raw data bytes: \(decryptedData.map { String(format: "%02x", $0) }.joined())")
                
                // Attempt to decode as UTF-8
                if let decryptedString = String(data: decryptedData, encoding: .utf8) {
                    self.decryptedMessage = decryptedString
                    print("Decryption succeeded with message: \(decryptedString)")
                } else {
                    print("Decryption succeeded but data is not a UTF-8 string.")
                }
            } else {
                print("Decryption failed: SecKeyCreateDecryptedData returned nil.")
                if let error = SecCopyErrorMessageString(errSecParam, nil) {
                    print("Error: \(error)")
                }
            }
        } catch {
            print("Decryption error: \(error)")
        }
    }
    
    // Returns only the private key reference
    private func getPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: PRIVATE_KEY_TAG,
            //kSecAttrApplicationTag as String: YUBICO_AUTHENTICATOR_TOKEN,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            let privateKey = item as! SecKey
            return privateKey
        } else {
            print("Private key not found or error: \(status)")
            return nil
        }
    }

    // TODO: Remove after testing
    // This generates a new keypair in the local iOS keychain but only available/visible to this application?
    func generateKeyPair() -> (SecKey?, SecKey?) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: PRIVATE_KEY_TAG
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let err = error?.takeRetainedValue() {
                print("Error generating key pair: \(err.localizedDescription)")
            }
            return (nil, nil)
        }
        
        let publicKey = SecKeyCopyPublicKey(privateKey)
        
        print("Key pair generated successfully")
        return (privateKey, publicKey)
    }
    
    // TODO: Testing export of this generated pk to share with another user
    // So they can send encrypted messages (encrypted with this pk) and then decrypted with the private key that only exists on this device.
    private func exportPublicKey() -> String? {
        guard let privateKey = getPrivateKey() else {
            print("Private key not found.")
            return nil
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            print("Public key could not be retrieved.")
            return nil
        }
        
        var error: Unmanaged<CFError>?
        if let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? {
            return publicKeyData.base64EncodedString()
        } else {
            print("Error exporting public key: \(error?.takeRetainedValue().localizedDescription ?? "Unknown error")")
            return nil
        }
    }
    
    func getPublicKey(certificate: SecCertificate) -> SecKey? {
        let publicKey = SecCertificateCopyKey(certificate)
        return publicKey
    }
    
    // Tokens/Certificates
    // Fetch tokens from iOS Keychain
    func fetchTokens() {
        let query: [String: Any] = [
            kSecAttrAccessGroup as String: kSecAttrAccessGroupToken,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecClass as String: kSecClassIdentity,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecReturnRef as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnPersistentRef as String: kCFBooleanTrue as Any
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            DispatchQueue.main.async {
                print("Found [\(items.count)] token(s) in the keychain")
                self.tokens = items
                self.parseTokens(tokens: items)
            }
        } else {
            let errorDescription = SecCopyErrorMessageString(status, nil)
            print("Error fetching tokens: \(errorDescription ?? "Unknown error" as CFString)")
            DispatchQueue.main.async {
                self.tokens = []
            }
        }
    }
    
    func parseTokens(tokens: [[String: Any]]) {
        print("Parsing tokens...")
        
        var tokenCount = 0
        tokens.forEach { item in
            tokenCount+=1
            guard let certData = item["certdata"] as? Data else { return }
            guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else { return }
            print("\nToken \(tokenCount) of \(tokens.count)")
            print("Name: \(certificate.commonName)")
            print("TokenObjectId: \(certificate.tokenObjectId())")
            print(item)
            //let secIdentity = item["v_Ref"] as! SecIdentity
        }
    }
    
    func getCertDetails(item: [String: Any]) -> SecCertificate? {
        guard let certData = item["certdata"] as? Data else { return nil }
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else { return nil }
        return certificate
    }
}
