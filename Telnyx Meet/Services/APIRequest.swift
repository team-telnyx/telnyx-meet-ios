import Foundation

public enum HTTPMethod : String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

class APIRequest {
    public fileprivate(set) var url: URL
    public fileprivate(set) var method: HTTPMethod
    public fileprivate(set) var headers: [String: String]?
    public fileprivate(set) var params: [String: Any]?
    public fileprivate(set) var body: [String: Any]?

    init(url: URL, method: HTTPMethod) {
        self.url = url
        self.method = method
    }
}


class APIRequestBuilder {
    private var apiRequest: APIRequest

    init(url: URL, method: HTTPMethod) {
        self.apiRequest = APIRequest(url: url, method: method)
    }

    public func addHeaders(header: [String: String]?) -> APIRequestBuilder {
        self.apiRequest.headers = header
        return self
    }

    public func addQueryParams(params: [String: Any]?) -> APIRequestBuilder {
        self.apiRequest.params = params
        return self
    }

    public func addBody(body: [String: Any]?) -> APIRequestBuilder {
        self.apiRequest.body = body
        return self
    }

    public func build() -> URLRequest {
        var request = URLRequest(url: self.apiRequest.url)
        request.httpMethod = self.apiRequest.method.rawValue

        // Add headers if required
        if let headers = self.apiRequest.headers {
            headers.forEach { (key, value) in
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add query params if required
        if let params = self.apiRequest.params {
            var queryItems = [URLQueryItem]()
            params.forEach { (key, value) in
                let strValue = (value as? String) ?? "\(value)"
                queryItems.append(URLQueryItem(name: key, value: strValue))
            }
            var urlComponents = URLComponents(string: self.apiRequest.url.absoluteString)
            urlComponents?.queryItems = queryItems
            request.url = urlComponents?.url
        }

        // Add body if required
        if let body = self.apiRequest.body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        }

        return request
    }
}
