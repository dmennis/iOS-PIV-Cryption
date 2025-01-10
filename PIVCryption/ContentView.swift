import SwiftUI
import Security

let PRIVATE_KEY_TAG = "com.yubikit.pivcryption.privatekey".data(using: .utf8)!

struct ContentView: View {
    @StateObject private var cryptoManager = CryptoManager()
    @State private var message: String = ""
    @State private var encryptedMessage: Data? = nil
    @State private var decryptedMessage: String? = nil
    
    // Token/Certificate dialog
    @State private var isShowingTokenDialog = false
    @State private var selectedItem: [String: Any]? = nil


    var body: some View {
        VStack(spacing: 20) {
            if let selected = selectedItem {
                // Display selected token
                Text("Selected Certificate:")
                    .font(.headline)
                Text("Name:")
                    .font(.headline)
                Text("\(cryptoManager.getCertDetails(item: selectedItem!)!.commonName)")
                    .font(.subheadline)
                    .lineLimit(1)
                Text("TokenId:")
                    .font(.headline)
                Text("\(cryptoManager.getCertDetails(item: selectedItem!)!.tokenObjectId())")
                    .font(.subheadline)
                    .lineLimit(2)
                } else {
                    Text("No token selected")
                        .padding()
                }
            
            Button("Select Certificate/Token") {
                cryptoManager.fetchTokens()
                isShowingTokenDialog = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
                            
            TextField("Enter message to encrypt", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Encrypt Message") {
                cryptoManager.encryptMessage(message)
            }
            .disabled(message.isEmpty)

            if let encrypted = cryptoManager.encryptedMessage {
                Text("Encrypted Message: \(encrypted.base64EncodedString())")
                    .font(Font.system(size: 10.0))
            }

            Button("Decrypt Message") {
                cryptoManager.decryptMessage()
            }
            .disabled(cryptoManager.encryptedMessage == nil)

            if let decrypted = cryptoManager.decryptedMessage {
                Text("Decrypted Message: \(decrypted)")
            }
        }
        .navigationTitle("")
        .sheet(isPresented: $isShowingTokenDialog) {
            TokenPickerView(tokens: cryptoManager.tokens) { selected in
                self.selectedItem = selected
                isShowingTokenDialog = false
            }
        }
        .padding()
        .onAppear {
            generateKeyPair() // TODO: Just for testing
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
            if let encryptedData = SecKeyCreateEncryptedData(publicKey!, .rsaEncryptionPKCS1, messageData as CFData, nil) as Data? {
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
            if let decryptedData = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionPKCS1, encryptedMessage as CFData, nil) as Data? {
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
}

struct TokenPickerView: View {
    let tokens: [[String: Any]]
    var onSelect: ([String: Any]) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tokens.indices, id: \.self) { index in
                    Button(action: {
                        onSelect(tokens[index])
                    }) {
                        VStack(alignment: .leading) {
                            Text("\(getCertDetails(item: tokens[index])!.commonName)")
                                .font(.headline)
                                .padding(1)
                            Text("\(getCertDetails(item: tokens[index])!.tokenObjectId())")
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .padding(10)
                    }
                }
            }
            .navigationTitle("Choose a Token")
            .navigationBarItems(trailing: Button("Cancel") {
                onSelect([:]) // Cancel and clear selection
            })
        }
    }
    
    func getCertDetails(item: [String: Any]) -> SecCertificate? {
        guard let certData = item["certdata"] as? Data else { return nil }
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else { return nil }
        return certificate
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
