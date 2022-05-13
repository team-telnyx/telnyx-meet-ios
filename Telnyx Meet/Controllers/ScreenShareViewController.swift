import UIKit
import TelnyxVideoSdk

class ScreenShareViewController: UIViewController {

    @IBOutlet weak var screenShareParticipantNameLabel: UILabel!
    @IBOutlet weak var streamingView: UIView!
    @IBOutlet private weak var closeButton: UIButton!

    lazy var videoRendererView: UIView = {
        #if arch(arm64)
        let renderer = MTLVideoView()
        renderer.videoContentMode = .scaleAspectFit
        return renderer
        #else
        return GLVideoView()
        #endif
    }()

    var screenShareParticipantName = ""
    private var currentOrientation = UIDevice.current.orientation

    override func viewDidLoad() {
        super.viewDidLoad()

        streamingView.addSubview(videoRendererView)
        videoRendererView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoRendererView.leadingAnchor.constraint(equalTo: streamingView.leadingAnchor),
            videoRendererView.topAnchor.constraint(equalTo: streamingView.topAnchor),
            videoRendererView.trailingAnchor.constraint(equalTo: streamingView.trailingAnchor),
            videoRendererView.bottomAnchor.constraint(equalTo: streamingView.bottomAnchor)
        ])
        streamingView.layoutIfNeeded()

        screenShareParticipantNameLabel.text = screenShareParticipantName
        closeButton.layer.cornerRadius = 17.5
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    /// Called when auto rotate is on
    @objc private func orientationChanged() {
        currentOrientation = UIDevice.current.orientation
        if currentOrientation.isLandscape {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    @IBAction private func closeButtonAction() {
        dismiss(animated: true, completion: nil)
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if currentOrientation == .landscapeRight {
            return .landscapeLeft
        }
        return .landscapeRight
    }
}
