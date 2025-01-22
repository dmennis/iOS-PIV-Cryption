//
//  Untitled.swift
//  PIVCryption
//
//  Created by Dennis Hills on 1/9/25.
//
import SwiftUI
import Security
import Foundation
import Combine

class CryptoManager: ObservableObject {
    @Published var encryptedMessage: Data? = nil
    @Published var decryptedMessage: String? = nil
    @Published var tokens: [[String: Any]] = []
    let PRIVATE_KEY_TAG = "com.yubikit.pivcryption.privatekey".data(using: .utf8)!
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
    
    // Encrypt using CryptoTokenKit token
    func encryptMessageUsingToken(_ message: String) {
        guard let privateKey = getPrivateKeyFromToken() else {
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
    
    // Decrypt cipher data using CryptoTokenKit token
    // We can find the private key reference from YA but when calling SecKeyCreateDecryptedData, the YA is not called
    // If we change SecKeyCreateDecryptedData --> SecKeyCreateSignature it calls YA app. Currently, the YA app has been modified
    // to handle decryption inside create signature 'handleTokenRequest' function in the TokenRequestViewModel in the YA app project
    func decryptMessageUsingToken() {
        
        guard let privateKey = getPrivateKeyFromToken() else {
            print("Decryption failed: Private key not found.")
            return
        }
        
        guard let encryptedMessage = encryptedMessage else {
            print("Decryption failed: Encrypted message is nil.")
            return
        }
        
        do {
            print("Encrypted (ciphertext) Message (base64Encoded): \(encryptedMessage.base64EncodedString())")
            
            //if let decryptedData = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionOAEPSHA256, encryptedMessage as CFData, nil) as Data? {
            if let decryptedData = SecKeyCreateSignature(privateKey, .rsaEncryptionOAEPSHA256, encryptedMessage as CFData, nil) as Data? {
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
    
    // Returns only the private key reference based on PRIVATE KEY TAG
    private func getPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: PRIVATE_KEY_TAG,
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
    
    // Returns the correct private key - HARDCODED
    private func getPrivateKeyFromToken() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrTokenID as String: "com.yubico.Authenticator.TokenExtension:972BC027C9E349CFA63856C2A2968F16ABDDE71564A94570EE131DEA92E9BB0F",
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
    
    func getPublicKeyFromToken() -> SecKey? {
        //var publicKey: SecKey? = nil
        
        guard let privateKey = getPrivateKeyFromToken() else {
            print("Private key not found.")
            return nil
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            print("Public key could not be retrieved.")
            return nil
        }
        // If we ever want to export the publicKey as base64encoded string
//        var error: Unmanaged<CFError>?
//        if let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? {
//            return publicKeyData.base64EncodedString()
//        } else {
//            print("Error exporting public key: \(error?.takeRetainedValue().localizedDescription ?? "Unknown error exporting public key")")
//            return nil
//        }
        return publicKey
    }
    
    func getPublicKeyFromCertificate(certificate: SecCertificate) -> SecKey? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }
        return publicKey
    }
    
    // Tokens/Certificates
    // Fetch all com.apple.token tokens saved to the iOS Keychain by any 3rd party app
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
    
    // Parse the token response
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
