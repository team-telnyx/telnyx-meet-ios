import UIKit
import WebRTC
import TelnyxVideoSdk

class VideoMeetParticipantCell : UICollectionViewCell {

    @IBOutlet private weak var streamingView: UIView!
    @IBOutlet private weak var userName: UILabel!
    @IBOutlet private weak var bigUserName: UILabel!
    @IBOutlet private weak var userId: UILabel!
    @IBOutlet private weak var microphoneView: UIImageView!

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
        if let videoTrack = stream?.videoTrack {
            VideoRenderer.shared().renderVideoTrack(videoTrack, in: streamingView)
            streamingView.transform = mirrorVideo ? CGAffineTransform.identity : CGAffineTransform(scaleX: -1, y: 1)
        }
        setVideoActive(isVideoActive: stream?.isVideoEnabled ?? false)
        setMicrophoneActive(isAudioEnabled: stream?.isAudioEnabled ?? false)
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

    override func prepareForReuse() {
    }
}
