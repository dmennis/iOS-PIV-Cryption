//
//  TokenListView.swift
//  PIVCryption
//
//  Created by Dennis Hills on 12/17/24.
//
import SwiftUI

struct TokenListView: View {
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
                            Text(getCertLabel(items: [tokens[index]])!)
                                .font(.headline)
                                .lineLimit(2)
                            Text(getCertTokenId(items: [tokens[index]])!)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("Select a Certificate")
            .navigationBarItems(trailing: Button("Cancel") {
                onSelect([:]) // Cancel and clear selection
            })
        }
    }
    
    func getCertLabel(items: [[String: Any]]) -> String? {
        // Preprocess the raw response
        let cryptoMgr = CryptoManager()
        let preprocessedResponse = cryptoMgr.preprocessTokenResponse(items)
        let tokens = cryptoMgr.parseTokens(from: preprocessedResponse)
        return tokens[0].label
    }
    
    func getCertTokenId(items: [[String: Any]]) -> String? {
        // Preprocess the raw response
        let cryptoMgr = CryptoManager()
        let preprocessedResponse = cryptoMgr.preprocessTokenResponse(items)
        let tokens = cryptoMgr.parseTokens(from: preprocessedResponse)
        return tokens[0].tkid
    }
}
