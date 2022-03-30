import UIKit

extension UIStoryboard {
    /// Get UIViewController instance with the identifier
    ///
    /// - parameter identifier: id of the view controller given in storyboard
    /// - returns: new instance of UIViewController with the provided id
    func viewController(for identifier: String) -> UIViewController {
        return instantiateViewController(withIdentifier: identifier)
    }

    /// Get type casted UIViewController instance with the identifier
    ///
    /// - parameter type:       type of the UIViewController
    /// - parameter identifier: id of the view controller given in storyboard (make sure the view controller has the identifier set in the storyboard)
    /// - returns: new instance of UIViewController with the provided id
    func viewController<T: UIViewController>(of type: T.Type, for identifier: String? = nil) -> T? {
        return self.instantiateViewController(withIdentifier: identifier ?? String(describing: T.self)) as? T
    }
}
