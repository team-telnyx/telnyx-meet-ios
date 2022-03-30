import UIKit
import TelnyxVideoSdk

class ParticipantListCell: UITableViewCell {

    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var screenShareButton: UIButton!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var videoButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with participant: Participant, stream: TelnyxVideoSdk.Stream?, isMe: Bool, isSharingScreen: Bool) {
        nameLabel.text = participant.name
        
        let audioEnabled = stream?.isAudioEnabled ?? false
        let videoEnabled = stream?.isVideoEnabled ?? false
        screenShareButton.isHidden = !isSharingScreen

        if #available(iOS 13.0, *) {
            micButton.setImage(UIImage(systemName: audioEnabled ? "mic.fill" : "mic.slash.fill"), for: .normal)
            micButton.tintColor = audioEnabled ? .systemGreen : .systemRed

            videoButton.setImage(UIImage(systemName: videoEnabled ? "video.fill" : "video.slash.fill"), for: .normal)
            videoButton.tintColor = videoEnabled ? .systemGreen : .systemRed
        }
    }

}
