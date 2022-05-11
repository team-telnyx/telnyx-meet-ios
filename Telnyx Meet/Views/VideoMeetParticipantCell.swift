import UIKit
import WebRTC
import TelnyxVideoSdk

class VideoMeetParticipantCell : UICollectionViewCell {

    @IBOutlet private weak var streamingView: UIView!
    @IBOutlet private weak var userName: UILabel!
    @IBOutlet private weak var bigUserName: UILabel!
    @IBOutlet private weak var userId: UILabel!
    @IBOutlet private weak var microphoneView: UIImageView!
    @IBOutlet private weak var audioCensoredView: UIImageView!

    private lazy var videoRendererView: UIView = {
        #if arch(arm64)
        let renderer = MTLVideoView()
        renderer.videoContentMode = .scaleAspectFit
        return renderer
        #else
        return GLVideoView()
        #endif
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        addVideoRendererView()
    }

    private func addVideoRendererView() {
        if videoRendererView.superview != nil { return } // Already added.

        streamingView.addSubview(videoRendererView)
        videoRendererView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoRendererView.leadingAnchor.constraint(equalTo: streamingView.leadingAnchor),
            videoRendererView.topAnchor.constraint(equalTo: streamingView.topAnchor),
            videoRendererView.trailingAnchor.constraint(equalTo: streamingView.trailingAnchor),
            videoRendererView.bottomAnchor.constraint(equalTo: streamingView.bottomAnchor)
        ])
        streamingView.layoutIfNeeded()
    }

    private func startRenderingVideo(videoTrack: RTCVideoTrack?) {
        if videoRendererView.superview == nil {
            addVideoRendererView()
        }
        if var renderer = videoRendererView as? VideoRenderer {
            renderer.videoTrack = videoTrack
        }
    }

    private func setMicrophoneActive(isAudioEnabled: Bool) {
        self.microphoneView.isHidden = isAudioEnabled
    }

    private func setVideoActive(isVideoActive: Bool) {
        if !isVideoActive {
            for view in self.streamingView.subviews {
                view.removeFromSuperview()
            }
        }
        bigUserName.isHidden = isVideoActive
        userName.isHidden = !isVideoActive
    }

    func displayParticipant(participant: Participant, stream: TelnyxVideoSdk.Stream?, mirrorVideo: Bool = false) {
        userId.isHidden = true
        userName.text = participant.name
        bigUserName.text = participant.name

        startRenderingVideo(videoTrack: stream?.videoTrack)
        streamingView.transform = mirrorVideo ? CGAffineTransform(scaleX: -1, y: 1) : CGAffineTransform.identity

        setVideoActive(isVideoActive: stream?.isVideoEnabled ?? false)
        setMicrophoneActive(isAudioEnabled: stream?.isAudioEnabled ?? false)
        setAudioCensored(isAudioCensored: stream?.isAudioCensored ?? false)
    }

    func flipCamera(mirror: Bool) {
        self.streamingView.transform = mirror ? CGAffineTransform(scaleX: -1, y: 1) : CGAffineTransform.identity
        UIView.transition(with: streamingView, duration: 0.7, options: mirror ? .transitionFlipFromRight : .transitionFlipFromLeft) {
        } completion: { _ in
        }
    }

    func setTalking() {
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.yellow.cgColor

        DispatchQueue.main.asyncAfter(deadline: .now()+1) { [weak self] in
            self?.layer.borderWidth = 0
            self?.layer.borderColor = .none
        }
    }
    
    private func setAudioCensored(isAudioCensored: Bool) {
        self.audioCensoredView.isHidden = !isAudioCensored
    }

    override func prepareForReuse() {
        if var renderer = videoRendererView as? VideoRenderer {
            renderer.videoTrack = nil
        }
        super.prepareForReuse()
    }
}
