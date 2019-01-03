//
//  RequestHelpser.swift
//  Multi Store Player
//
//  Created by Miko Kiiski on 03/01/2019.
//  Copyright © 2019 Miko Kiiski. All rights reserved.
//

import Foundation

class RequestHelpers {
    static func toJSON(data: [String: Any]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: data)
    }
    
    static func postJson(url: String, body: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: url)!)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpMethod = "POST"
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
        
        task.resume()
    }
    
    static func getJson(url: String, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: url)!)
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
        
        task.resume()
    }
}
