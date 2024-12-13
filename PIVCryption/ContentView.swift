import SwiftUI

struct ContentView: View {
    @StateObject private var cryptoManager = CryptoManager()
    @State private var message: String = ""

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter message to encrypt", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Encrypt Message") {
                cryptoManager.encryptMessage(message)
            }
            .disabled(message.isEmpty)

            if let encrypted = cryptoManager.encryptedMessage {
                Text("Encrypted Message: \(encrypted.base64EncodedString())")
            }

            Button("Decrypt Message") {
                cryptoManager.decryptMessage()
            }
            .disabled(cryptoManager.encryptedMessage == nil)

            if let decrypted = cryptoManager.decryptedMessage {
                Text("Decrypted Message: \(decrypted)")
            }
        }
        .padding()
        .onAppear {
            cryptoManager.generateKeyPair()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
