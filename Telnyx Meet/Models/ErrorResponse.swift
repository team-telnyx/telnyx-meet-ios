import Foundation

struct ErrorResponse: Codable {
    let errors: [ErrorData]
}

struct ErrorData: Codable {
    let code: String
    let title:  String
    let detail: String
    let meta: Meta
}

struct Meta: Codable {
    let url: String
}
