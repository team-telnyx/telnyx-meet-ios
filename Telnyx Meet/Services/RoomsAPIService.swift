import Foundation

class RoomsAPIService : APIService {

    private lazy var baseURL: String =  {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let apiKey = plist["apiUrl"] as? String else {
                  return ""
              }
        return apiKey
    }()

    private lazy var API_KEY: String = {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let apiKey = plist["apiKey"] as? String else {
                  return ""
              }
        return apiKey
    }()

    func getAllRooms(completion: @escaping  ([RoomInfo]?, APIError?) -> Void) {
        var header = [String: String]()
        header["Authorization"] = API_KEY

        // Recommendation for the consumers to implement paging for a better performance
        // If you
        let endpoint = baseURL + "rooms?page[size]=200"

        self.request(url: endpoint,
                     method: .get,
                     headers: header) { (data: Data?, response: HTTPURLResponse?, error: Error?) in
            if let error = error {
                completion(nil, APIError.serverError(reason: .error(message: error.localizedDescription, code: error.localizedDescription)))
                return
            }

            let jsonDecoder = JSONDecoder()
            var getRoomsResponse: GetAllRoomsResponse? = nil
            if let data = data {
                do {
                    getRoomsResponse = try jsonDecoder.decode(GetAllRoomsResponse.self, from: data)
                } catch {
                    let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data)
                    if let errorData =  errorResponse?.errors.first {
                        let serverError = APIError.serverError(reason: .error(message: "\(errorData.title). \(errorData.detail)", code: "\(errorData.code)"))
                        completion(nil, serverError)
                        return
                    }
                }
            }

            completion(getRoomsResponse?.data, nil)
        }
    }

    func getRoom(roomID: String, completion: @escaping  (RoomInfo?, APIError?) -> Void) {
        var header = [String: String]()
        header["Authorization"] = API_KEY

        let endpoint = baseURL + "rooms" + "/\(roomID)"
        self.request(url: endpoint,
                     method: .get,
                     headers: header) { (data: Data?, response: HTTPURLResponse?, error: Error?) in
            if let error = error {
                completion(nil, APIError.serverError(reason: .error(message: error.localizedDescription, code: error.localizedDescription)))
                return
            }

            let jsonDecoder = JSONDecoder()
            var roomData: RoomData? = nil
            if let data = data {
                do {
                    roomData = try jsonDecoder.decode(RoomData.self, from: data)
                } catch {
                    let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data)
                    if let errorData =  errorResponse?.errors.first {
                        let serverError = APIError.serverError(reason: .error(message: "\(errorData.title). \(errorData.detail)", code: "\(errorData.code)"))
                        completion(nil, serverError)
                        return
                    }
                }
            }

            completion(roomData?.data, nil)
        }
    }

    func createClientToken(roomID: String, completion: @escaping  (UserTokens?, APIError?) -> Void) {
        var header = [String: String]()
        header["Authorization"] = API_KEY
        header["Content-Type"] = "application/json"
        header["Accept"] = "application/json"

        let endpoint = baseURL + "rooms/" + "\(roomID)" + "/actions/generate_join_client_token"
        var body = [String: Any]()
        body["refresh_token_ttl_secs"] = 3600
        body["token_ttl_secs"] = 600

        self.request(url: endpoint,
                     method: .post,
                     headers: header,
                     body: body) { (data: Data?, response: HTTPURLResponse?, error: Error?) in
            if let error = error {
                completion(nil, APIError.serverError(reason: .error(message: error.localizedDescription, code: error.localizedDescription)))
                return
            }

            let jsonDecoder = JSONDecoder()
            var userTokens: UserTokens? = nil
            if let data = data {
                userTokens = try? jsonDecoder.decode(TokenData.self, from: data).userTokens
                let expiresInSeconds = self.calculateExpirationTimeSeconds(expirationDate: userTokens?.tokenExpiresAt)
                userTokens?.expiresInSeconds = expiresInSeconds
            }

            completion(userTokens, nil)
        }
    }

    func refreshClientToken(roomID: String,
                            refreshToken: String,
                            completion: @escaping  (UserTokens?, APIError?) -> Void) {
        var header = [String: String]()
        header["Authorization"] = API_KEY
        header["Content-Type"] = "application/json"
        header["Accept"] = "application/json"

        let endpoint = baseURL + "rooms/" + "\(roomID)" + "/actions/refresh_client_token"

        var body: [String: Any] = [String: Any]()
        body["refresh_token"] = refreshToken
        body["token_ttl_secs"] = 600

        self.request(url: endpoint,
                     method: .post,
                     headers: header,
                     body: body) { (data: Data?, response: HTTPURLResponse?, error: Error?) in
            if let error = error {
                completion(nil, APIError.serverError(reason: .error(message: error.localizedDescription, code: error.localizedDescription)))
                return
            }

            let jsonDecoder = JSONDecoder()
            var userTokens: UserTokens? = nil
            if let data = data {
                let tokenData = try? jsonDecoder.decode(TokenData.self, from: data)
                userTokens = tokenData?.userTokens
                let expiresInSeconds = self.calculateExpirationTimeSeconds(expirationDate: userTokens?.tokenExpiresAt)
                userTokens?.expiresInSeconds = expiresInSeconds
            }

            completion(userTokens, nil)
        }
    }

    private func calculateExpirationTimeSeconds(expirationDate: String?) -> Int {
        if let expirationDate = expirationDate {
            let dfmatter = DateFormatter()
            //2021-04-22T12:24:55Z"
            dfmatter.dateFormat="yyyy-MM-dd'T'HH:mm:ss'Z'"
            dfmatter.timeZone = TimeZone(abbreviation: "UTC")
            let date = dfmatter.date(from: expirationDate)
            let delta = Int(date?.timeIntervalSinceNow ?? 600 )
            return delta
        }
        return 600
    }
}
