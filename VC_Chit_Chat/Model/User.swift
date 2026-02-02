import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    
    static func createMe(name: String) -> User {
        return User(id: UUID().uuidString, name: name)
    }
}
