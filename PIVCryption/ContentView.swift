import SwiftUI
import Security

struct ContentView: View {
    @StateObject private var cryptoManager = CryptoManager()
    @State private var message: String = ""
    @State private var encryptedMessage: Data? = nil
    
    // Token/Certificate dialog
    @State private var isShowingTokenDialog = false
    @State private var selectedItem: [String: Any]? = nil
    
    func clearMessage() {
        self.message = ""
    }

    var body: some View {
        VStack(spacing: 15) {
            Button("Select Certificate/Token") {
                cryptoManager.fetchTokens()
                isShowingTokenDialog = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .padding()
            
            if let selected = selectedItem {
                if !selected.isEmpty {
                    // Display details of selected token
                    Text("Selected Certificate:")
                        .font(.headline)
                    Text("Name:")
                        .font(.headline)
                    var commonNameText: String {
                        cryptoManager.getCertDetails(item: selected)?.commonName ?? "n/a"
                    }
                    Text(commonNameText)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text("TokenId:")
                        .font(.headline)
                    var tokenObjIdText: String {
                        cryptoManager.getCertDetails(item: selected)?.tokenObjectId() ?? "n/a"
                    }
                    Text(tokenObjIdText)
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    Text("No Certificate Selected")
                }
            }
            TextField("Enter message to encrypt", text: $message)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(4)
                .padding()
            Button("Encrypt") {
                cryptoManager.encryptMessageUsingToken(message)
                UIApplication.shared.endEditing() // Call to dismiss keyboard
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .disabled(message.isEmpty)

            if let encrypted = cryptoManager.encryptedMessage {
                Text("Message (plaintext):")
                    .font(Font.system(size: 16.0))
                Text(message)
                    .font(Font.system(size: 12.0).bold())
                    .padding(5)
                    .border(.gray)
                    .padding([.leading, .trailing], 20)
                Text("Encrypted (cipher text) Message:")
                    .font(Font.system(size: 16.0))
                Text(encrypted.base64EncodedString())
                    .font(Font.system(size: 7.0))
                    .padding(5)
                    .border(.gray)
                    .padding([.leading, .trailing], 20)
            }
            
            Button("Decrypt") {
                cryptoManager.decryptMessageUsingToken()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding()
            .disabled(cryptoManager.encryptedMessage == nil)

            if let decrypted = cryptoManager.decryptedMessage {
                Text("Decrypted Message:")
                    .font(Font.system(size: 16.0))
                Text(decrypted)
                    .font(Font.system(size: 16.0))
                    .background(.yellow)
                    .foregroundStyle(.blue.gradient)
                    .padding(5)
                    .border(.gray)
                    .padding([.leading, .trailing], 20)
            }
        }
        .navigationTitle("Yubico Developer Program")
        .sheet(isPresented: $isShowingTokenDialog) {
            TokenPickerView(tokens: cryptoManager.tokens) { selected in
                self.selectedItem = selected
                isShowingTokenDialog = false
            }
        }
    }
}

struct TokenPickerView: View {
    let tokens: [[String: Any]]
    var onSelect: ([String: Any]) -> Void
    @StateObject private var cryptoManager = CryptoManager()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(tokens.indices, id: \.self) { index in
                    Button(action: {
                        onSelect(tokens[index])
                    }) {
                        VStack(alignment: .leading) {
                            Text("\(cryptoManager.getCertDetails(item: tokens[index])!.commonName)")
                                .font(.headline)
                                .padding(1)
                            Text("\(cryptoManager.getCertDetails(item: tokens[index])!.tokenObjectId())")
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
}

// extension for keyboard to dismiss
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
