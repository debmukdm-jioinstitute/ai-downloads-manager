import Foundation

struct NestAuthSession: Codable, Equatable {
    let accessToken: String
    let email: String?
    let displayName: String?
    let signedInAt: Date
}
