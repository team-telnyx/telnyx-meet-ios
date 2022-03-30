import UIKit
import TelnyxVideoSdk

class StatsViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var sizeButton: UIButton!
    @IBOutlet private var statsViewTop: NSLayoutConstraint!
    @IBOutlet private var statsViewHeight: NSLayoutConstraint!

    var room: Room!
    var participant: Participant!
    var isScreenShare = false
    var headerText: String?
    private var audioStatsStr = ""
    private var videoStatsStr = ""
    private let statsKeys = [
        // in-bound video
        "packetsLost",
        "packetsReceived",
        "bytesReceived",
        "totalDecodeTime",
        "frameWidth",
        "frameHeight",
        "framesPerSecond",
        "totalInterFrameDelay",
        "decoderImplementation",
        // out-bound video
        "packetsSent",
        "bytesSent",
        "totalEncodeTime",
        "totalPacketSendDelay",
        "encoderImplementation",
        "totalInterFrameDelay",
        // out-bound audio
        "headerBytesSent",
        "retransmittedBytesSent",
        "retransmittedPacketsSent",
        // in-bound audio
        "audioLevel",
        "jitter",
        "totalAudioEnergy",
        "totalSamplesDuration"
    ]
    private var statsTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showStats()
    }

    private func setupUI() {
        view.backgroundColor = .black.withAlphaComponent(0.5)
        statsViewTop.isActive = false
        statsViewHeight.isActive = true
        titleLabel.text = headerText ??  "Stats"
        textView.bounces = false
        textView.isEditable = false
        textView.text = ""
    }

    private func showStats() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let isLocalParticipant = self.room.isLocalParticipant(participantId: self.participant.id)
            let streamKey = self.isScreenShare ? "presentation" : "self"
            self.room.getWebRTCStatsForStream(participantId: self.participant.id, streamKey: streamKey) { stats in
                let statsKey = isLocalParticipant ? "senders" : "receivers"
                if let participantStats = stats[statsKey] as? [String: [String: Any]],
                   let audioStats = participantStats["audio"],
                   let videoStats = participantStats["video"] {

                    self.audioStatsStr = ""
                    let audioStatskey = isLocalParticipant ? "RTCOutboundRTPAudioStream" : "RTCInboundRTPAudioStream"
                    if let statsKey = audioStats.first(where: { $0.key.contains(audioStatskey) })?.key {
                        self.audioStatsStr = self.getInfo(from: audioStats, key: statsKey)
                    }

                    self.videoStatsStr = ""
                    let videoStatsKey = isLocalParticipant ? "RTCOutboundRTPVideoStream" : "RTCInboundRTPVideoStream"
                    if let statsKey = videoStats.first(where: { $0.key.contains(videoStatsKey) })?.key {
                        self.videoStatsStr = self.getInfo(from: videoStats, key: statsKey)
                    }
                }
                self.updateStats()
            }
        }
    }

    private func getInfo(from statsReport: [String: Any], key: String) -> String {
        var statsArray = [String]()
        if let stats = statsReport[key] as? [String: Any] {
            stats.forEach({ element in
                if self.statsKeys.contains(element.key) {
                    statsArray.append("\(element.key) : \(element.value)")
                }
            })
            if let codecId = stats["codecId"] as? String, let codec = statsReport[codecId] as? [String: Any], let mimeType = codec["mimeType"]  {
                statsArray.append("codec: \(mimeType)")
            }
        }
        statsArray.sort()
        statsArray.insert("📈 \(key.components(separatedBy: "_").first!):", at: 0)
        return statsArray.joined(separator: "\n\t")
    }

    private func updateStats() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textView.text  = """
                                      =====================
                                      ** \(self.participant.name)'s Stats **
                                      =====================

                                      \(self.audioStatsStr)

                                      \(self.videoStatsStr)
                                      """
        }
    }

    deinit {
        statsTimer?.invalidate()
    }

    @IBAction private func closeButtonAction() {
        dismiss(animated: true)
    }

    @IBAction private func toggleStatsViewSize() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            self.statsViewTop.isActive = !self.statsViewTop.isActive
            self.statsViewHeight.isActive = !self.statsViewHeight.isActive
            if self.statsViewTop.isActive {
                if #available(iOS 13.0, *) {
                    self.sizeButton.setImage(UIImage(systemName: "chevron.down.circle.fill"), for: .normal)
                    self.view.backgroundColor = .systemBackground
                } else {
                    self.view.backgroundColor = .white
                }
            } else {
                if #available(iOS 13.0, *) {
                    self.sizeButton.setImage(UIImage(systemName: "chevron.up.circle.fill"), for: .normal)
                }
                self.view.backgroundColor = .black.withAlphaComponent(0.5)
            }
            self.view.layoutIfNeeded()
        }
    }
}
