import UIKit
import TelnyxVideoSdk
import WebRTC

class VideoMeetRoomViewController: UIViewController {

    // MARK: - Variables

    private let apiService = RoomsAPIService()
    private let mediaDevices = MediaDevices.shared()
    private var localStream: RTCMediaStream?
    private var room: Room!
    var roomInfo: RoomInfo!
    var participantName = ""
    private var userToken: UserTokens?
    private var participantScreenSharing: Participant?
    private var visibleParticipants = [String]()
    private var participantsList = [Participant]()
    private var allParticipantsList = [Participant]()
    private let NUMBER_OF_COLUMNS: CGFloat = 2
    private var NUMBER_OF_ROWS: CGFloat {
        return isScreenShareOn ? 3 : 4
    }
    private let collectionViewSpacing: CGFloat = 5
    private var itemCellSize: CGSize = .zero
    private var cellIDs = [String]()
    private let layout = UICollectionViewFlowLayout()
    private var isScreenShareOn = false
    private var maxVisibleParticipants: Int {
        return isScreenShareOn ? 6 : 8
    }
    private var audioEnabled = false
    private var videoEnabled = false
    private var refreshTokenTimer: Timer? = nil
    private var localParticipantId: String {
        return room.getState().localParticipantId
    }

    // MARK: - IBOutlets

    @IBOutlet private weak var participantsColletionView: UICollectionView!

    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var cameraButton: UIButton!
    @IBOutlet private weak var cameraSwitchButton: UIButton!
    @IBOutlet private weak var fullScreenButton: UIButton!
    @IBOutlet private weak var screenShareStatsButton: UIButton!

    @IBOutlet private weak var pinnedContainerView: UIView!
    @IBOutlet private weak var screenShareView: UIView!
    @IBOutlet private weak var pinnedContainerViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet private weak var screenShareParticipantNameLabel: UILabel!
    @IBOutlet private weak var participantsCountLabel: UILabel!
    @IBOutlet private weak var roomId: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestTokenForRoom()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Re-draw collectionview if the device orientation has changed.
        calculateCellSize()
        layout.itemSize = itemCellSize
        layout.invalidateLayout()
        participantsColletionView.reloadData()
    }

    deinit {
        refreshTokenTimer?.invalidate()
        refreshTokenTimer = nil
        screenShareViewController = nil
        participantsViewController = nil
        VideoRenderer.shared().dispose()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Private methods

    private func setupUI() {
        navigationItem.setHidesBackButton(true, animated: false)
        title = roomInfo?.uniqueName ?? "Unknown room"
        roomId.text = roomInfo?.id ?? ""
        fullScreenButton.layer.cornerRadius = 17.5
        fullScreenButton.clipsToBounds = true
        screenShareStatsButton.layer.cornerRadius = 17.5
        screenShareStatsButton.clipsToBounds = true
        updateMicButton()
        updateCameraButton()
        #if targetEnvironment(simulator)
        // `cameraSwitchButton ` is enabled only for a real device.
        // For simulator, this button remains disabled.
        cameraSwitchButton.isEnabled = false
        #endif
        setupCollectionView()
        updateScreenShareView()
    }

    private func updateMicButton() {
        DispatchQueue.main.async {
            var image: UIImage?
            if self.audioEnabled {
                if #available(iOS 13.0, *) {
                    image = UIImage(systemName: "mic.fill")
                } else {
                    // Fallback on earlier versions
                }
            } else {
                if #available(iOS 13.0, *) {
                    image = UIImage(systemName: "mic.slash.fill")
                } else {
                    // Fallback on earlier versions
                }
            }
            self.micButton.setImage(image, for: .normal)
        }
    }

    private func updateCameraButton() {
        DispatchQueue.main.async {
            var image: UIImage?
            if self.videoEnabled {
                if #available(iOS 13.0, *) {
                    image = UIImage(systemName: "video.fill")
                } else {
                    // Fallback on earlier versions
                }
            } else {
                if #available(iOS 13.0, *) {
                    image = UIImage(systemName: "video.slash.fill")
                } else {
                    // Fallback on earlier versions
                }
            }
            self.cameraButton.setImage(image, for: .normal)
            #if !targetEnvironment(simulator)
            // Update `cameraSwitchButton` only for a real device.
            // For simulator, this button remains disabled.
            self.cameraSwitchButton.isEnabled = self.videoEnabled
            #endif
        }
    }

    private func setupCollectionView() {
        layout.minimumInteritemSpacing = collectionViewSpacing
        layout.minimumLineSpacing = collectionViewSpacing
        layout.itemSize = itemCellSize

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.calculateCellSize()
            self.layout.itemSize = self.itemCellSize
            self.layout.invalidateLayout()
        }

        participantsColletionView.delegate = self
        participantsColletionView.dataSource = self
        participantsColletionView.contentInset = UIEdgeInsets(top: collectionViewSpacing,
                                                              left: collectionViewSpacing,
                                                              bottom: collectionViewSpacing,
                                                              right: collectionViewSpacing)
        participantsColletionView.showsHorizontalScrollIndicator = false
        participantsColletionView.decelerationRate = .fast
        participantsColletionView.isPagingEnabled = false
        participantsColletionView.collectionViewLayout = layout
        // By disabling prefetching we are only creating the views that are actually displayed + 1 extra.
        participantsColletionView.isPrefetchingEnabled = false
        registerCollectionViewCellsIDs()
    }

    private func registerCollectionViewCellsIDs() {
        let nib = UINib(nibName: String(describing: VideoMeetParticipantCell.self), bundle: nil)
        for i in 0...8 {
            cellIDs.append(String(i))
            participantsColletionView.register(nib, forCellWithReuseIdentifier: cellIDs[i])
        }
    }

    private func calculateCellSize() {
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalInterItemSpacing = CGFloat((NUMBER_OF_COLUMNS - 1) * collectionViewSpacing)
        let availableWidth = screenWidth - totalHorizontalInterItemSpacing - participantsColletionView.contentInset.left - participantsColletionView.contentInset.right
        let itemWidth = availableWidth / NUMBER_OF_COLUMNS

        let collectionViewHeight = participantsColletionView.bounds.height
        let totalVerticalInterItemSpacing = CGFloat(NUMBER_OF_ROWS - 1) * collectionViewSpacing
        let availableHeight = collectionViewHeight - totalVerticalInterItemSpacing - participantsColletionView.contentInset.top - participantsColletionView.contentInset.bottom
        let itemHeight = availableHeight / CGFloat(NUMBER_OF_ROWS)

        itemCellSize =  CGSize(width: itemWidth, height: itemHeight)
    }

    private func requestTokenForRoom() {
        guard let room = self.roomInfo else { return }

        self.apiService.createClientToken(roomID: room.id) { userTokens, error in
            if let error = error {
                self.showErrorAlert(errorMessage: "There was an error requesting the user token: \(error.localizedDescription)")
                return
            }
            guard let userTokens = userTokens else {
                self.showErrorAlert(errorMessage: "User token is invalid.")
                return
            }
            self.userToken = userTokens

            // Connect to video room
            self.connectToRoom()

            // Start refresh token timer
            guard let refreshInterval = self.userToken?.expiresInSeconds else { return }
            let expiresIn = Double(refreshInterval) * 0.8
            self.refreshToken(interval: Int(expiresIn))
        }
    }

    private func refreshToken(interval: Int) {
        refreshTokenTimer?.invalidate()
        refreshTokenTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: false) { [weak self] _ in
            guard let roomId = self?.roomInfo?.id,
                  let refreshToken = self?.userToken?.refreshToken else { return }
            self?.apiService.refreshClientToken(roomID: roomId, refreshToken: refreshToken, completion: { userTokens, error in
                // Refresh token
                if let userTokens = userTokens {
                    self?.userToken?.token = userTokens.token
                    self?.userToken?.tokenExpiresAt = userTokens.tokenExpiresAt
                    self?.userToken?.expiresInSeconds = userTokens.expiresInSeconds

                    let expiresIn = Double(userTokens.expiresInSeconds) * 0.8
                    self?.refreshToken(interval: Int(expiresIn))

                    self?.room.updateClientToken(clientToken: userTokens.token, completion: {
                    })
                }
            })
        }
    }

    private func connectToRoom() {
        guard let clientToken = userToken?.token else {
            return
        }
        let username = participantName.isEmpty ? "User from iOS" : participantName
        let context: [String: AnyCodable] = ["id": "429759", "username": AnyCodable(username)]

        Room.createRoom(id: roomInfo.id, clientToken: clientToken, context: context) { [weak self] room in
            guard let self = self else { return }
            self.room = room
        }

        room.onError = { error in
            // Triggered when there’s an error processing incoming events from the server.
        }

        room.onStateChanged = { state in
            // Triggered each time the `room.state` is updated.
        }

        room.onParticipantJoined = { [weak self] participantId, participant in
            guard let self = self else { return }
            if self.room.isLocalParticipant(participantId: participantId) {
                // We are already adding local participant in the `participantsList` on connecting to the room.
                return
            }
            if self.visibleParticipants.count < self.maxVisibleParticipants {
                self.visibleParticipants.append(participantId)
            }
            self.participantJoined(participantId: participantId)
        }

        room.onParticipantLeft = { [weak self] participantId in
            guard let self = self else { return }
            self.visibleParticipants.removeAll(where: { $0 == participantId })
            self.participantLeft(participantId: participantId)
        }

        room.onStreamPublished = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            // Subscribe to a stream only if it is for one of the visible participant or a screen share
            let isScreenShare = streamKey == "presentation"
            let shouldSubscribe = isScreenShare || self.isParticipantVisible(participantId: participantId)

            if participantId != self.localParticipantId,
               let stream = self.room.getParticipantStream(participantId: participantId, key: streamKey),
               stream.isVideoEnabled, shouldSubscribe {
                self.subscribeToRemoteStream(participantId: participantId, key: streamKey, audio: stream.isAudioEnabled, video: stream.isVideoEnabled) {
                }
            }

            DispatchQueue.main.async {
                self.participantsViewController?.updateParticipants()
            }
        }

        room.onTrackEnabled = { [weak self] participantId, streamKey, kind in
            guard let self = self else { return }
            if participantId != self.localParticipantId,
               self.isParticipantVisible(participantId: participantId), streamKey == "self",
               let stream = self.room.getParticipantStream(participantId: participantId, key: streamKey) {
                if self.room.isSubscribedTo(streamKey: streamKey, participantId: participantId) {
                    self.updateParticipant(participantId: participantId)
                } else {
                    self.subscribeToRemoteStream(participantId: participantId, key: streamKey, audio: stream.isAudioEnabled, video: stream.isVideoEnabled) {
                    }
                }
            }
        }

        room.onTrackDisabled = { [weak self] participantId, streamKey, kind in
            guard let self = self else { return }
            if self.isParticipantVisible(participantId: participantId),
               self.room.isSubscribedTo(streamKey: streamKey, participantId: participantId),
               streamKey == "self" {
                self.updateParticipant(participantId: participantId)
            }
        }

        room.onStreamUnpublished = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            if self.isParticipantVisible(participantId: participantId), streamKey == "self" {
                self.updateParticipant(participantId: participantId)
            } else if streamKey == "presentation" {
                self.participantScreenSharing = nil
                self.updateScreenShareView()
            }

            DispatchQueue.main.async {
                self.participantsViewController?.updateParticipants()
            }
        }

        room.onStreamAudioActivity = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            self.updateParticipantTalking(participantId: participantId, streamKey: streamKey ?? "")
        }

        room.onParticipantAudioActivity = { [weak self] participantId in
            guard let self = self else { return }
            self.updateParticipantTalking(participantId: participantId, streamKey: "")
        }

        room.onSubscriptionStarted = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            if streamKey == "presentation" {
                // This is a screen share
                self.participantScreenSharing = self.room.state.participants[participantId]
                self.updateScreenShareView()
            } else {
                self.updateParticipant(participantId: participantId)
            }
        }

        room.onSubscriptionPaused = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            if streamKey == "presentation" {
                self.participantScreenSharing = nil
                self.updateScreenShareView()
            } else {
                self.updateParticipant(participantId: participantId)
            }
        }

        room.onSubscriptionResumed = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            if streamKey == "presentation" {
                self.participantScreenSharing = self.room.state.participants[participantId]
                self.updateScreenShareView()
            } else {
                self.updateParticipant(participantId: participantId)
            }
        }

        room.onSubscriptionReconfigured = { participantId, streamKey in
            // Triggered when the subscription is reconfigured.
        }

        room.onSubscriptionEnded = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            if streamKey == "presentation" {
                self.participantScreenSharing = nil
                self.updateScreenShareView()
            } else {
                self.updateParticipant(participantId: participantId)
            }
        }

        room.connect { [weak self] status in
            guard let self = self else { return }
            if status == .connected, let localParticipant = try? self.room.getLocalParticipant() {
                self.visibleParticipants.insert(self.localParticipantId, at: 0)
                DispatchQueue.main.async {
                    if !self.participantsList.contains(where: { $0.id == localParticipant.id }) {
                        self.participantsList.insert(localParticipant, at: 0)
                        self.allParticipantsList.insert(localParticipant, at: 0)
                    }
                    self.participantsColletionView.reloadData()
                    self.updateAllParticipantsUI()
                }
                self.publishLocalStream(audio: true, video: true)
            }
        }
    }

    private func showErrorAlert(errorMessage: String) {
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in
            self.onLeaveButton()
        }))
        present(alert, animated: true, completion: nil)
    }

    private func publishLocalStream(audio: Bool, video: Bool) {
        mediaDevices.simulatorVideoFileName = "telnyx.mp4"
        self.mediaDevices.getUserMedia(audio: true, video: true, cameraPosition: .front, onSuccess: { mediaStream in

            self.localStream = mediaStream
            let audioTrack = audio ? self.localStream?.audioTracks.first : nil
            let videoTrack = video ? self.localStream?.videoTracks.first : nil

            self.room.addStream(key: "self", audio: audioTrack, video: videoTrack) { [weak self] in
                guard let self = self else { return }
                self.audioEnabled = audio
                self.videoEnabled = video
                self.updateMicButton()
                self.updateCameraButton()
                self.updateParticipant(participantId: self.localParticipantId)
            }
        }, onFailed: { error in
            // handle error
        })
    }

    private func updateLocalStream(audio: Bool, video: Bool) {
        if ((try? room.getLocalStreams()) != nil) {
            let audioTrack = audio ? localStream?.audioTracks.first : nil
            let videoTrack = video ? localStream?.videoTracks.first : nil
            
            room.updateStream(key: "self", audio: audioTrack, video: videoTrack) { [weak self] in
                guard let self = self else { return }
                self.audioEnabled = audio
                self.videoEnabled = video
                self.updateMicButton()
                self.updateCameraButton()
                self.updateParticipant(participantId: self.localParticipantId)
            }
        } else {
            publishLocalStream(audio: audio, video: video)
        }
    }

    private func unpublishLocalStream() {
        room.removeStream(key: "self") { [weak self] in
            guard let self = self else { return }
            self.audioEnabled = false
            self.videoEnabled = false
            self.updateMicButton()
            self.updateCameraButton()
            self.updateParticipant(participantId: self.localParticipantId)
        }
    }

    private func subscribeToRemoteStream(participantId: String,
                                         key: String,
                                         audio: Bool,
                                         video: Bool,
                                         completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.room.addSubscription(participantId: participantId, key: key, audio: audio, video: video) {
                completion()
            }
        }
    }

    private func unsubscribe(participantId: String, key: String = "self", completion: @escaping () -> Void) {
        room.removeSubscription(participantId: participantId, key: key) {
            completion()
        }
    }

    private func participantJoined(participantId: String) {
        DispatchQueue.main.async {
            if let participant = self.room.state.participants[participantId] {
                // Update visible participants
                if self.visibleParticipants.contains(participantId) {
                    self.participantsColletionView.performBatchUpdates {
                        self.participantsList.append(participant)
                        self.participantsColletionView.insertItems(at: [
                            IndexPath(item: self.participantsList.count-1, section: 0)
                        ])
                    } completion: { _ in
                    }
                }
                // Update other participants
                self.allParticipantsList.append(participant)
            }
            self.updateAllParticipantsUI()
        }
    }

    private func participantLeft(participantId: String) {
        DispatchQueue.main.async {
            if self.isScreenShareOn, self.participantScreenSharing?.id == participantId {
                self.participantScreenSharing = nil
                self.updateScreenShareView()
            }
            // Update visible participants
            if let index = self.participantsList.firstIndex(where: { $0.id == participantId }) {
                self.participantsColletionView.performBatchUpdates {
                    self.participantsList.remove(at: index)
                    self.participantsColletionView.deleteItems(at: [
                        IndexPath(item: index, section: 0)
                    ])
                } completion: { _ in
                    // Added participant if there is space
                    self.addVisibleParticipantIfAvailable()
                }
            }
            // Update other participants
            if let index = self.allParticipantsList.firstIndex(where: { $0.id == participantId }) {
                self.allParticipantsList.remove(at: index)
            }
            self.updateAllParticipantsUI()
        }
    }

    private func addVisibleParticipantIfAvailable() {
        DispatchQueue.main.async {
            if self.participantsList.count < self.maxVisibleParticipants,
               self.participantsList.count < self.allParticipantsList.count {
                self.participantsColletionView.performBatchUpdates {
                    self.participantsList.append(self.allParticipantsList[self.participantsList.count])
                    self.participantsColletionView.insertItems(at: [
                        IndexPath(item: self.participantsList.count-1, section: 0)
                    ])
                    if let participantId = self.participantsList.last?.id {
                        self.visibleParticipants.append(participantId)
                    }
                } completion: { _ in
                }
            }
        }
    }

    private func updateParticipantTalking(participantId: String, streamKey: String) {
        DispatchQueue.main.async {
            if self.room.isSubscribedTo(streamKey: streamKey, participantId: participantId) {
                if streamKey == "presentation", self.isScreenShareOn {
                    // This is audio activity from screen share. Highlight screen share
                    self.screenShareView.layer.borderWidth = 2
                    self.screenShareView.layer.borderColor = UIColor.yellow.cgColor

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.screenShareView.layer.borderWidth = 0
                        self.screenShareView.layer.borderColor = .none
                    }

                } else if self.isParticipantVisible(participantId: participantId),
                          let index = self.participantsList.firstIndex(where: { $0.id == participantId }) {
                    self.participantsColletionView.reloadItems(at: [
                        IndexPath(item: index, section: 0)
                    ])
                    if let cell = self.participantsColletionView.cellForItem(at: IndexPath(item: index, section: 0)) as? VideoMeetParticipantCell {
                        cell.setTalking()
                    }
                }
            }
        }
    }

    private func updateParticipant(participantId: String) {
        DispatchQueue.main.async {
            if let index = self.participantsList.firstIndex(where: { $0.id == participantId }) {
                self.participantsColletionView.reloadItems(at: [
                    IndexPath(item: index, section: 0)
                ])
            }
        }
    }

    private func updateAllParticipantsUI() {
        DispatchQueue.main.async {
            self.participantsCountLabel.text = "\(self.allParticipantsList.count)"
            self.participantsViewController?.updateParticipants()
        }
    }

    private func isParticipantVisible(participantId: String) -> Bool {
        return visibleParticipants.contains(participantId)
    }

    private func getVideoTrack(for participantId: String) -> RTCVideoTrack? {
        if participantId == self.localParticipantId {
            let localStreams = try? room.getLocalStreams()
            return localStreams?["self"]?.videoTrack
        } else if let streamId = room.state.participants[participantId]?.streams["self"],
                  let stream = room.state.streams[streamId] {
            return stream.videoTrack
        }
        return nil
    }

    private func isMe(id: String) -> Bool {
        return self.localParticipantId == id
    }

    private func updateScreenShareView() {
        DispatchQueue.main.async {
            self.isScreenShareOn = self.participantScreenSharing != nil

            self.participantsList.removeAll()
            self.visibleParticipants.removeAll()

            if self.allParticipantsList.count > self.maxVisibleParticipants {
                self.participantsList.append(contentsOf: self.allParticipantsList[0...self.maxVisibleParticipants-1])
            } else {
                self.participantsList.append(contentsOf: self.allParticipantsList)
            }

            self.visibleParticipants.append(contentsOf: self.participantsList.map({ $0.id }))
            self.participantsColletionView.reloadData()

            if self.isScreenShareOn {
                // Show screen share video
                if let participantId = self.participantScreenSharing?.id,
                   let stream = self.room.getParticipantStream(participantId: participantId, key: "presentation"),
                   let videoTrack = stream.videoTrack {
                    VideoRenderer.shared().renderVideoTrack(videoTrack, in: self.screenShareView)
                }
                self.screenShareParticipantNameLabel.text = self.participantScreenSharing?.name
            } else {
                // Dismiss full screen screen share vc if presented
                self.screenShareViewController?.dismiss(animated: true, completion: {
                    self.screenShareViewController = nil
                })
                // Remove screen share video
                for view in self.screenShareView.subviews {
                    view.removeFromSuperview()
                }
                self.screenShareParticipantNameLabel.text = nil
            }

            UIView.animate(withDuration: 0.5) {
                let height = self.itemCellSize.height + self.collectionViewSpacing
                self.pinnedContainerViewHeightConstraint.constant = self.isScreenShareOn ? height : 0
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.layout.invalidateLayout()
                self.participantsColletionView.reloadData()
            }
        }
    }

    private func showStats(for participant: Participant) {
        guard let vc = storyboard?.viewController(of: StatsViewController.self) else {
            return
        }
        vc.room = room
        vc.participant = participant
        vc.headerText = "\(participant.name)'s Stats"
        vc.isScreenShare = isScreenShareOn
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true, completion: nil)
    }

    // MARK: - IBActions

    @IBAction private func onLeaveButton() {
        if self.room.status == .connected {
            self.room.disconnect { [weak self] in
                guard let self = self else { return }
                self.mediaDevices.stopCapturingCameraVideo()
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            return
        } else {
            self.mediaDevices.stopCapturingCameraVideo()
            self.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction private func toggleMicrophone() {
        audioEnabled.toggle()
        updateLocalStream(audio: audioEnabled, video: videoEnabled)
    }

    @IBAction private func toggleVideo() {
        videoEnabled.toggle()
        updateLocalStream(audio: audioEnabled, video: videoEnabled)
    }

    @IBAction private func switchCamera() {
        mediaDevices.toggleCamera()
        DispatchQueue.main.async {
            if let index = self.participantsList.firstIndex(where: { $0.id == self.localParticipantId }),
                let cell = self.participantsColletionView.cellForItem(at: IndexPath(item: index, section: 0)) as? VideoMeetParticipantCell {
                let mirror = self.mediaDevices.cameraPosition == .front
                cell.flipCamera(mirror: mirror)
            }
        }
    }

    private weak var participantsViewController: ParticipantsViewController?
    @IBAction private func showAllParticipants() {
        guard let vc = storyboard?.viewController(of: ParticipantsViewController.self) else {
            return
        }
        vc.room = room
        present(UINavigationController(rootViewController: vc), animated: true, completion: nil)
        participantsViewController = vc
    }

    private weak var screenShareViewController: ScreenShareViewController?
    @IBAction private func showScreenShareInFullScreen() {
        guard let vc = storyboard?.viewController(of: ScreenShareViewController.self),
              let participant = participantScreenSharing,
              let stream = room.getParticipantStream(participantId: participant.id, key: "presentation"),
              let videoTrack = stream.videoTrack else {
                  return
              }
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.screenShareParticipantName = participant.name
        present(vc, animated: true, completion: {
            VideoRenderer.shared().renderVideoTrack(videoTrack, in: vc.streamingView)
        })
        screenShareViewController = vc
    }

    @IBAction private func showScreenShareStats() {
        guard isScreenShareOn, let participant = participantScreenSharing else {
            return
        }
        showStats(for: participant)
    }
}

extension VideoMeetRoomViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return participantsList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let participant = participantsList[indexPath.row]
        let mirror = (room.isLocalParticipant(participantId: participant.id) && mediaDevices.cameraPosition == .front) ? true : false
        let cell = participantsColletionView.dequeueReusableCell(withReuseIdentifier: cellIDs[indexPath.item], for: indexPath) as! VideoMeetParticipantCell
        cell.displayParticipant(participant: participant, stream: room.getParticipantStream(participantId: participant.id, key: "self"), mirrorVideo: mirror)
        return cell
    }
}

extension VideoMeetRoomViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showStats(for: participantsList[indexPath.item])
    }
}
