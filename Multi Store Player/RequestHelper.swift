import Foundation

class RequestHelpers {
    static func toJSON(data: [String: Any]) -> Data? {
        return try? JSONSerialization.data(withJSONObject: data)
    }
    
    static func postJson(url: String, idToken: String, body: Data, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: url)!)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        request.httpMethod = "POST"
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
        
        task.resume()
    }
    
    static func getJson(url: String, idToken: String, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: url)!)
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completionHandler)
        
        task.resume()
    }
}
