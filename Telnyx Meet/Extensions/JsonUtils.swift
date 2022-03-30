import Foundation
import TelnyxVideoSdk

extension Encodable {
	var dictionary: [String: Any]? {
		guard let data = try? JSONEncoder().encode(self) else { return nil }
		return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
	}
}

extension String {
    var dictionary: [String: AnyCodable]? {
        if let data = data(using: .utf8) {
            return try? JSONDecoder().decode([String: AnyCodable].self, from: data)
        }
        return nil
    }
}
