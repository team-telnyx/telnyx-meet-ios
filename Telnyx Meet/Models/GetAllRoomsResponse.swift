import Foundation

struct GetAllRoomsResponse : Codable {
    let data: [RoomInfo]
    let meta: Pagination?
}
