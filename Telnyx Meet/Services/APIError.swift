import Foundation

public enum APIError: Error {
    public enum GeneralReasons {
        case WrongURL
    }

    public enum ServerErrorReason {
        case error(message: String, code: String)
    }

    case generalFailure(reason: GeneralReasons)
    case serverError(reason: ServerErrorReason)
}

// MARK: - Underlying errors
extension APIError.GeneralReasons {
    var underlyingError: Error? {
        switch self {
            case .WrongURL:
                return nil
        }
    }
}

extension APIError.ServerErrorReason {
    var errorMessage: String? {
        switch self {
            case let .error(message: message, code: code):
                return "Message: \(message), code: \(code)"
        }
    }

    var underlyingError: Error? {
        switch self {
            case .error:
                return nil
        }
    }
}

// MARK: - Error Descriptions
extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case let .generalFailure(reason):
                return "General error \(reason.localizedDescription ?? "No description.")"
            case let .serverError(reason):
                return reason.errorMessage
        }
    }
}

extension APIError.GeneralReasons: LocalizedError {
    public var localizedDescription: String? {
        switch self {
            case .WrongURL:
                return "The URL is invalid."
        }
    }
}

extension APIError.ServerErrorReason {
    public var localizedDescription: String {
        switch self {
            case .error(message: let message, code: let code):
                return "Server error: \(message), code: \(code)"
        }
    }
}
