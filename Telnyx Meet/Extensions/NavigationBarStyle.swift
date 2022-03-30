import UIKit

extension UIViewController {
    func setupNavigationBar(title: String?) {
        let titleTextAttributes = [
            NSAttributedString.Key.foregroundColor : UIColor.txText
        ]
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .txBackground
            appearance.titleTextAttributes = titleTextAttributes
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.barTintColor = .txBackground
        navigationController?.navigationBar.tintColor = .txText
        navigationController?.navigationBar.titleTextAttributes = titleTextAttributes
        self.title = title
    }
}
