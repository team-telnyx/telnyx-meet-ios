import UIKit

extension UIViewController {

    func showToast(message: String, seconds: Double) {
        var style = UIAlertController.Style.actionSheet
        if UIDevice.current.userInterfaceIdiom == .pad {
            // ipad doesn't support actionSheet
            style = .alert
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: style)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            alert.dismiss(animated: true)
        }
    }
}
