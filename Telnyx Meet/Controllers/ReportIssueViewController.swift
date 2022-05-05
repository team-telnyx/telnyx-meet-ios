import UIKit
import TelnyxVideoSdk
import WebRTC

class ReportIssueViewController: UIViewController {

    @IBOutlet private weak var container: UIView!
    @IBOutlet private weak var textView: UITextView!

    weak var room: Room?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayStateData()
    }

    private func setupUI() {
        view.backgroundColor = .black.withAlphaComponent(0.5)
        container.layer.cornerRadius = 10
        container.layer.cornerCurve = .continuous
        textView.layer.cornerRadius = 5
        textView.layer.cornerCurve = .continuous
        textView.contentInset = UIEdgeInsets(top: 15, left: 10, bottom: 15, right: 10)
    }

    private func displayStateData() {
        guard let state = room?.state else {
            return
        }

        var stateJson: JSONObject = [:]

        let children = Mirror(reflecting: state).children
        for child in children {
            if let property = child.label {
                stateJson[property] = child.value
            }
        }

        textView.text = "\(Dictionary(uniqueKeysWithValues: stateJson.sorted(by: { $0.0 < $1.0 }))))"
    }

    @IBAction private func closeButtonAction() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func copyButtonAction() {
        UIPasteboard.general.string = textView.text
    }

    @IBAction private func shareButtonAction() {
        let activityViewController = UIActivityViewController(activityItems: [textView.text ?? ""], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = textView
        activityViewController.excludedActivityTypes = [
            .postToFacebook,
            .postToVimeo,
            .postToWeibo,
            .postToFlickr,
            .postToTencentWeibo,
            .postToTwitter,
            .assignToContact
        ]
        present(activityViewController, animated: true, completion: nil)
    }

}
