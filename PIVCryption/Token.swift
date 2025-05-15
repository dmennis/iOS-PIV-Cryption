//
//  Token.swift
//  PIVCryption
//
//  Created by Dennis Hills on 5/14/25.
//
import Foundation

class Token {
    var label: String?
    var uuid: UUID?
    var creationDate: Date?
    var tokenID: String?
    var canSign: Bool?
    var canDecrypt: Bool?
    
    init(from dict: [String: Any]) {
        self.label = dict["labl"] as? String
        
        if let uuidString = dict["UUID"] as? String {
            self.uuid = UUID(uuidString: uuidString)
        }
        
        if let date = dict["mdat"] as? Date {
            self.creationDate = date
        } else if let dateString = dict["mdat"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            self.creationDate = formatter.date(from: dateString)
        }
        self.canSign = dict["sign"] as? Bool
        self.canDecrypt = dict["decr"] as? Bool
        self.tokenID = dict["tkid"] as? String
    }
}

