import SwiftUI

struct ContentView: View {
    @StateObject private var cryptoManager = CryptoManager()
    @State private var message: String = ""
    @State private var isShowingTokenDialog = false
    @State private var selectedItem: [String: Any]? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let selected = selectedItem {
                        // Display selected token
                        Text("Selected Certificate:")
                            .font(.headline)
                        Text(selected.description)
                            .padding()
                            .lineLimit(3)
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
                TokenListView(tokens: cryptoManager.tokens) { selected in
                    self.selectedItem = selected
                    isShowingTokenDialog = false
                }
            }
            .padding()
    //        .onAppear {
    //            cryptoManager.generateKeyPair()
    //        }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
