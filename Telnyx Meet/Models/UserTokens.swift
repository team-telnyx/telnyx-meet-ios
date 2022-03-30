import Foundation

struct TokenData : Codable {
    let userTokens: UserTokens?

    enum CodingKeys: String, CodingKey {
        case userTokens = "data"
    }
}

struct UserTokens : Codable {
    let refreshToken: String?
    let refreshTokenExpiresAt: String?
    var token: String
    var tokenExpiresAt: String
    var expiresInSeconds: Int = 600 // Default in 10 minutes

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case refreshTokenExpiresAt = "refresh_token_expires_at"
        case token = "token"
        case tokenExpiresAt = "token_expires_at"
    }
}
