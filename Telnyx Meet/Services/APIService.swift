import Foundation

class APIService {
    private let session: URLSession = URLSession.shared

    public func request(url: String,
                        method: HTTPMethod,
                        headers: [String: String],
                        params: [String: Any]? = nil,
                        body: [String: Any]? = nil,
                        completion: @escaping ((_ data: Data?, _ response: HTTPURLResponse?, _ error: Error?) -> Void)) {

        guard let url = URL(string: url) else {
            completion(nil, nil, APIError.generalFailure(reason: .WrongURL))
            return
        }

        let request = APIRequestBuilder(url: url, method: method)
            .addHeaders(header: headers)
            .addBody(body: body)
            .addQueryParams(params: params)
            .build()

        session.dataTask(with: request) { (data, response, error) in
            let response = response as? HTTPURLResponse

            var serverError: APIError? = nil
            if let error = error {
                serverError = APIError.serverError(reason: .error(message: error.localizedDescription,
                                                                  code: "\(response?.statusCode ?? -1)"))
            }
            DispatchQueue.main.async {
                completion(data, response, serverError)
            }
        }.resume()
    }
}
