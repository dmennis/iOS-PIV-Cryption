import SwiftUI
import Security

let PRIVATE_KEY_TAG = "com.yubikit.pivcryption.privatekey".data(using: .utf8)!
//let ENCRYPTION_ALGORITHM: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256
let ENCRYPTION_ALGORITHM: SecKeyAlgorithm = .rsaEncryptionOAEPSHA256AESGCM // Not working

struct ContentView: View {
    @State private var message: String = ""
    @State private var encryptedMessage: Data? = nil
    @State private var decryptedMessage: String? = nil
    @State private var tokens: [[String: Any]] = []
    @State private var tokenID: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter message to encrypt", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Encrypt Message") {
                encryptMessage()
            }
            .disabled(message.isEmpty)

            if let encrypted = encryptedMessage {
                Text("Encrypted Message: \(encrypted.base64EncodedString())")
            }

            Button("Decrypt Message") {
                decryptMessage()
            }
            .disabled(encryptedMessage == nil)

            if let decrypted = decryptedMessage {
                Text("Decrypted Message: \(decrypted)")
            }
        }
        .padding()
        .onAppear {
            generateKeyPair() // TODO: Just for testing
            fetchTokens()
        }
    }

    private func encryptMessage() {
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
            if let encryptedData = SecKeyCreateEncryptedData(publicKey!, ENCRYPTION_ALGORITHM, messageData as CFData, nil) as Data? {
                self.encryptedMessage = encryptedData
            } else {
                throw NSError(domain: "EncryptionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encrypt data."])
            }
        } catch {
            print("Encryption error: \(error)")
        }
    }

    private func decryptMessage() {
        guard let privateKey = getPrivateKey(), let encryptedMessage = encryptedMessage else {
            print("Private key or encrypted message not available.")
            return
        }

        do {
            if let decryptedData = SecKeyCreateDecryptedData(privateKey, ENCRYPTION_ALGORITHM, encryptedMessage as CFData, nil) as Data? {
                self.decryptedMessage = String(data: decryptedData, encoding: .utf8)
            } else {
                throw NSError(domain: "DecryptionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decrypt data."])
            }
        } catch {
            print("Decryption error: \(error)")
        }
    }

    private func getPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: PRIVATE_KEY_TAG,
            //kSecAttrTokenID as String: self.tokenID!,
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
    private func generateKeyPair() -> (SecKey?, SecKey?) {
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
    
    // Tokens/Certificates
    // Fetch all com.apple.token tokens saved to the iOS Keychain by any 3rd party app
    private func fetchTokens() {
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
            print("Found [\(items.count)] token(s) in the keychain")
            tokens = items
            parseTokens(tokens: items)
            
        } else {
            let errorDescription = SecCopyErrorMessageString(status, nil)
            print("Error fetching tokens: \(errorDescription ?? "Unknown error" as CFString)")
            self.tokens = []
        }
    }
    
    // Parse the token response
    private func parseTokens(tokens: [[String: Any]]) {
        print("Parsing tokens...")
        var tokenCount = 0
        tokens.forEach { item in
            tokenCount+=1
            
            let tokenMetaData = Token(from: item)
            self.tokenID = tokenMetaData.tokenID!
            print("TokenID: \(tokenMetaData.tokenID!)")
            print("Label: \(tokenMetaData.label!)")
            print("CanSign: \(tokenMetaData.canSign!)")
            print("CanDecrypt: \(tokenMetaData.canDecrypt!)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
