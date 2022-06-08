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
    private lazy var screenShareVideoView: UIView = {
        #if arch(arm64)
        // Using metal
        let renderer = MTLVideoView()
        renderer.videoContentMode = .scaleAspectFit
        return renderer
        #else
        // Using OpenGLES for the rest
        return GLVideoView()
        #endif
    }()
    private var messages = [MessageItem]()
    private var unreadMessagesCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.messagesCountLabel.isHidden = self.unreadMessagesCount == 0
                self.messagesCountLabel.text = "\(self.unreadMessagesCount)"
                // animate new messages count
                if self.unreadMessagesCount > 0 {
                    self.animateNewMessagesCount()
                }
            }
        }
    }
    /// This map is used to keep a track of subscription status for visible participant's streams.
    private var visibleParticipantsSubscriptions = [ParticipantId: [StreamKey: Bool]]()

    private var loadingView: UIAlertController = UIAlertController(title: nil, message: "Joining...", preferredStyle: .alert)
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
    @IBOutlet private weak var messagesCountLabel: UILabel!

    @IBOutlet private weak var bgFiltersBtn: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestTokenForRoom()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionViewLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateCollectionViewLayout()
    }

    private func updateCollectionViewLayout() {
        calculateCellSize()
        layout.itemSize = itemCellSize
        layout.invalidateLayout()
    }

    deinit {
        refreshTokenTimer?.invalidate()
        refreshTokenTimer = nil
        screenShareViewController = nil
        participantsViewController = nil
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

        screenShareView.addSubview(screenShareVideoView)
        screenShareVideoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            screenShareVideoView.leadingAnchor.constraint(equalTo: screenShareView.leadingAnchor),
            screenShareVideoView.topAnchor.constraint(equalTo: screenShareView.topAnchor),
            screenShareVideoView.trailingAnchor.constraint(equalTo: screenShareView.trailingAnchor),
            screenShareVideoView.bottomAnchor.constraint(equalTo: screenShareView.bottomAnchor)
        ])
        screenShareView.layoutIfNeeded()

        messagesCountLabel.text = nil
        messagesCountLabel.isHidden = true
        messagesCountLabel.clipsToBounds = true
        messagesCountLabel.textAlignment = .center
        messagesCountLabel.layer.cornerRadius = 6

        setupBackgroundFiltersMenu()
        updateMicButton()
        updateCameraButton()
        #if targetEnvironment(simulator)
        // `cameraSwitchButton ` is enabled only for a real device.
        // For simulator, this button remains disabled.
        cameraSwitchButton.isEnabled = false
        // Disable background filters menu for simulator
        bgFiltersBtn.isEnabled = false
        #endif
        setupCollectionView()
        updateScreenShareView()
    }

    private func setupBackgroundFiltersMenu() {
        let noFilter = UIAction(title: "No Filter", subtitle: "Removes the background filter.", image: nil) { (action) in
            self.mediaDevices.cameraFilter = nil
        }
        let blurFilter = UIAction(title: "Blur", subtitle: "Blurs the background.", image: nil) { (action) in
            self.setBGBlurFilter()
        }
        let abstractFilter = UIAction(title: "Abstract", subtitle: "Applies abstract background.", image: nil) { (action) in
            self.setVirtualBGFilter(imageName: "abstract")
        }
        let wolverineFilter = UIAction(title: "Wolverine", subtitle: "Applies Wolverine background.", image: nil) { (action) in
            self.setVirtualBGFilter(imageName: "wolverine")
        }
        let eiffelTowerFilter = UIAction(title: "Eiffel Tower", subtitle: "Applies Eiffel Tower background.", image: nil) { (action) in
            self.setVirtualBGFilter(imageName: "eiffel tower")
        }
        let children = [
            noFilter,
            blurFilter,
            abstractFilter,
            wolverineFilter,
            eiffelTowerFilter
        ]
        bgFiltersBtn.menu = UIMenu(title: "Background Filters", subtitle: "Choose a background filter for your video.", image: nil, identifier: .none, options: .displayInline, children: children)
    }

    private func setBGBlurFilter() {
        var backgroundFilter = self.mediaDevices.cameraFilter as? BackgroundFilter
        if backgroundFilter == nil {
            backgroundFilter = BackgroundFilter()
        }
        backgroundFilter?.filterType = .blur(radius: 9)
        self.mediaDevices.cameraFilter = backgroundFilter
    }

    private func setVirtualBGFilter(imageName: String) {
        guard let backgroundImage = UIImage(named: imageName) else {
            return
        }
        var backgroundFilter = self.mediaDevices.cameraFilter as? BackgroundFilter
        if backgroundFilter == nil {
            backgroundFilter = BackgroundFilter()
        }
        backgroundFilter?.filterType = .virtualBackground(image: backgroundImage)
        self.mediaDevices.cameraFilter = backgroundFilter
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
        let context: JSONObject = ["id": "429759", "username": username]

        Room.createRoom(id: roomInfo.id, clientToken: clientToken, context: context, enableMessages: true) { [weak self] room in
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
                // We need to keep a track of subscriptions for visible participants.
                self.visibleParticipantsSubscriptions[participantId] = [:]
            }
            self.participantJoined(participantId: participantId)
        }

        room.onParticipantLeaving = { [weak self] participantId, reason in
            guard let self = self else { return }

            if reason == .kicked {
                DispatchQueue.main.async {
                    if participantId == self.localParticipantId {
                        self.showErrorAlert(title:"Oops! 😮" ,errorMessage: "You have been kicked out! 🦶")
                    } else {
                        if let participant = self.room.state.participants[participantId] {
                            self.showToast(message: "⚠️ \(participant.name) has been kicked out! 🦶", seconds: 3.0)
                        }
                    }
                }
            }
        }

        room.onParticipantLeft = { [weak self] participantId in
            guard let self = self else { return }
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

        room.onAudioActivity = { [weak self] participantId, streamKey in
            guard let self = self else { return }
            self.updateParticipantTalking(participantId: participantId, streamKey: streamKey ?? "")
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

            // Update subscription status for subscription
            self.visibleParticipantsSubscriptions[participantId]?[streamKey] = true
            self.publishIfSubscriptionsCompleted()
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

        // Triggered by Moderator API - mute action
        room.onTrackCensored = { [weak self] participantId, streamKey, kind in
            guard let self = self else { return }
            self.showAudioModeratorAlert(participantId: participantId, streamKey: streamKey, kind: kind, isCensored: true)
            self.updateParticipant(participantId: participantId)
        }

        // Triggered by Moderator API - unmute action
        room.onTrackUncensored = { [weak self] participantId, streamKey, kind in
            guard let self = self else { return }
            self.showAudioModeratorAlert(participantId: participantId, streamKey: streamKey, kind: kind, isCensored: false)
            self.updateParticipant(participantId: participantId)
        }

        room.onMessageReceived = { [weak self] participantId, message, _ in
            guard let self = self else { return }
            let messageItem = MessageItem(sender: participantId, message: message)
            self.messages.append(messageItem)
            self.newMessageReceived(message: messageItem)
        }
        self.showLoading()
        
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
                    self.hideLoading()
                }
                self.publishIfSubscriptionsCompleted()
            }
        }
    }
    
    private func showLoading() {
        self.participantsColletionView.isHidden = true
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();
        
        self.loadingView.view.addSubview(loadingIndicator)
        present(self.loadingView, animated: true, completion: nil)
    }
    
    private func hideLoading() {
        self.participantsColletionView.isHidden = false
        self.loadingView.dismiss(animated: false, completion: nil)
    }

    
    private func newMessageReceived(message: MessageItem) {
        DispatchQueue.main.async {
            self.chatViewController?.addMessage(message)
            if self.chatViewController != nil {
                // User is on chat screen
                return
            }
            // User is not on the chat screen
            // so we need to update the count of unread messages
            self.unreadMessagesCount += 1
        }
    }

    private func animateNewMessagesCount() {
        let layer = messagesCountLabel.layer

        // remove previous animation
        layer.removeAnimation(forKey: "scale")

        CATransaction.begin()
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.3
        scaleAnimation.toValue = 1.5
        scaleAnimation.autoreverses = true

        // add scale animation
        layer.add(scaleAnimation, forKey: "scale")

        CATransaction.commit()
    }

    private func showErrorAlert(title: String = "Error", errorMessage: String) {
        let alert = UIAlertController(title: title, message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in
            self.onLeaveButton()
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showAudioModeratorAlert(participantId: ParticipantId, streamKey: StreamKey, kind: String, isCensored: Bool) {
        DispatchQueue.main.async {
            if participantId == self.localParticipantId {
                self.showToast(message: "⚠️ Your \(kind) from \"\(streamKey)\" stream has been \(isCensored ? "censored" : "uncensored") by the moderator", seconds: 5.0)
            } else {
                if let participant = self.room.state.participants[participantId] {
                    self.showToast(message: "⚠️ \(participant.name)'s \(kind) from \"\(streamKey)\" stream has been \(isCensored ? "censored" : "uncensored") by the moderator", seconds: 5.0)
                }
            }
        }
    }

    /// This function publishes local stream if all the subscriptions for visible participants are completed.
    /// Local stream is also published If there are no remote participants or no remote participants are sharing video.
    private func publishIfSubscriptionsCompleted() {
        if self.localStream != nil {
            // Already published local stream.
            return
        }

        let totalParticipants = self.room.state.participants.count
        let totalVideoStreams = self.room.state.participants.reduce(0) { result, pair in
            return result + pair.value.streams.count
        }

        if totalParticipants == 1 || totalVideoStreams == 0 {
            // There are no participants or no remote participant is sharing their video.
            self.publishLocalStream(audio: true, video: true)
            return
        }

        // There are remote participants with video on.
        // Wait till all the subscriptions for only the visible participants is completed.
        let subscriptionsCompleted = self.visibleParticipantsSubscriptions.reduce(0) { result, item in
            let subscriptions = item.value.filter({ $0.value == true }).count
            return result + subscriptions
        }

        if subscriptionsCompleted == totalVideoStreams {
            // All the subscriptions for visible participants are completed.
            self.publishLocalStream(audio: true, video: true)
        }
    }

    private func publishLocalStream(audio: Bool, video: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.mediaDevices.simulatorVideoFileName = "telnyx.mp4"
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
    }

    private func updateLocalStream(audio: Bool, video: Bool) {
        if let localStreams = try? room.getLocalStreams(),
           localStreams.count != 0 {
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
        // Keep a track of subscription
        self.visibleParticipantsSubscriptions[participantId]?[key] = false
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
            self.visibleParticipants.removeAll(where: { $0 == participantId })
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
                if let cell = self.participantsColletionView.cellForItem(at: IndexPath(item: index, section: 0)) as? VideoMeetParticipantCell {
                    cell.setTalking()
                }
            }
        }
    }

    private func updateParticipant(participantId: String) {
        DispatchQueue.main.async {
            if let index = self.participantsList.firstIndex(where: { $0.id == participantId }) {
                if let cell = self.participantsColletionView.cellForItem(at: IndexPath(item: index, section: 0)) as? VideoMeetParticipantCell {
                    let participant = self.participantsList[index]
                    let stream = self.room.getParticipantStream(participantId: participantId, key: "self")
                    let mirror = participantId == self.localParticipantId
                    cell.displayParticipant(participant: participant, stream: stream, mirrorVideo: mirror)
                }
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

            if self.isScreenShareOn {
                if self.visibleParticipants.count > 6 {
                    // there are more than 6 visible participants
                    // keep only 6 visible participants as we need to show screen share
                    self.participantsColletionView.performBatchUpdates {
                        let rangeToRemove = (6..<self.visibleParticipants.count)//.reversed()
                        let indexPathsToRemove = rangeToRemove.map({ IndexPath(item: $0, section: 0) })
                        /*for i in rangeToRemove {
                         self.visibleParticipants.remove(at: i)
                         self.participantsList.remove(at: i)
                         }*/
                        self.visibleParticipants.removeSubrange(rangeToRemove)
                        self.participantsList.removeSubrange(rangeToRemove)
                        self.participantsColletionView.deleteItems(at: indexPathsToRemove)

                        // TODO: - Unsubscribe/pause video stream
                    } completion: { _ in
                    }
                }
            } else {
                if self.visibleParticipants.count < 8 && self.allParticipantsList.count > self.visibleParticipants.count {
                    // screen share is turned off
                    // there is still more space to display visible participants
                    let lastIndex = self.allParticipantsList.count > 8 ? 8 : self.allParticipantsList.count
                    let rangeToAdd = (self.visibleParticipants.count..<lastIndex)
                    let indexPathsToAdd = rangeToAdd.map({ IndexPath(item: $0, section: 0) })
                    for i in rangeToAdd {
                        self.visibleParticipants.append(self.allParticipantsList[i].id)
                        self.participantsList.append(self.allParticipantsList[i])
                    }
                    self.participantsColletionView.insertItems(at: indexPathsToAdd)

                    // TODO: - Re-subscribe/resume video stream
                }
            }

            if self.isScreenShareOn {
                // Show screen share video
                if let participantId = self.participantScreenSharing?.id,
                   let stream = self.room.getParticipantStream(participantId: participantId, key: "presentation"),
                   var renderer = self.screenShareVideoView as? VideoRenderer {
                    renderer.videoTrack = stream.videoTrack
                }

                self.screenShareParticipantNameLabel.text = self.participantScreenSharing?.name
            } else {
                // Dismiss full screen screen share vc if presented
                self.screenShareViewController?.dismiss(animated: true, completion: {
                    self.screenShareViewController = nil
                })
                // Remove screen share video
                if var renderer = self.screenShareVideoView as? VideoRenderer {
                    renderer.videoTrack = nil
                }
                self.screenShareParticipantNameLabel.text = nil
            }

            UIView.animate(withDuration: 0.5) {
                let height = self.itemCellSize.height + self.collectionViewSpacing
                self.pinnedContainerViewHeightConstraint.constant = self.isScreenShareOn ? height : 0
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.layout.invalidateLayout()
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

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onReportIssueButton()
        }
    }

    // MARK: - IBActions

    @IBAction private func onReportIssueButton() {
        guard let vc = storyboard?.viewController(of: ReportIssueViewController.self) else {
            return
        }
        vc.room = room
        vc.modalTransitionStyle = .crossDissolve
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
    
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

    private weak var chatViewController: ChatViewController?
    @IBAction private func openChat() {
        guard let vc = storyboard?.viewController(of: ChatViewController.self) else {
            return
        }
        vc.room = room
        vc.setMessages(messages: self.messages)
        let nc = UINavigationController(rootViewController: vc)
        nc.modalPresentationStyle = .fullScreen
        present(nc, animated: true, completion: nil)
        chatViewController = vc
        // User is opening chat screen, clear unread messages count
        unreadMessagesCount = 0
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
            if var renderer = vc.videoRendererView as? VideoRenderer {
                renderer.videoTrack = videoTrack
            }
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
