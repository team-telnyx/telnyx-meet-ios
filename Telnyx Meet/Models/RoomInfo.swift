import Foundation

struct RoomInfo: Codable {
    let id: String
    let maxParticipants: Int?
    let recordType: String?
    let uniqueName: String?
    let updatedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case maxParticipants = "max_participants"
        case recordType = "record_type"
        case uniqueName = "unique_name"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

struct RoomData: Decodable {
    let data: RoomInfo
}
