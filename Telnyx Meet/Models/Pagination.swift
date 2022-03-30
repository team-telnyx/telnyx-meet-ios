import Foundation

struct Pagination: Codable {
	let pageNumber: Int?
	let pageSize: Int?
	let totalPages: Int?
	let totalResults: Int?
	
	enum CodingKeys: String, CodingKey {
		case pageNumber = "page_number"
		case pageSize = "page_size"
		case totalPages = "total_pages"
		case totalResults = "total_results"
	}
}
