import UIKit
import TelnyxVideoSdk
import WebRTC

class JoinRoomViewController: UIViewController {

    @IBOutlet private weak var roomUUIDField: UITextField!
    @IBOutlet private weak var nameField: UITextField!
    @IBOutlet private weak var joinButton: UIButton!
    @IBOutlet private weak var availableRoomsButton: UIButton!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private let apiService = RoomsAPIService()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.stopAnimating()

        setupNavigationBar(title: "Telnyx Meet")

        roomUUIDField.delegate = self
        nameField.delegate = self
        nameField.autocapitalizationType = .words

        joinButton.layer.cornerRadius = 5
        joinButton.backgroundColor = .txGreen

        availableRoomsButton.setTitleColor(.txGreen, for: .normal)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }

    private func showErrorAlert(errorMessage: String) {
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func goToRoom(room: RoomInfo, participantName: String) {
        guard let vc = storyboard?.viewController(of: VideoMeetRoomViewController.self) else {
            return
        }
        vc.participantName = participantName
        vc.roomInfo = room
        navigationController?.pushViewController(vc, animated: true)
    }

    private func fetchAndJoinRoom(participantName: String, roomUUID: String) {
        activityIndicator.startAnimating()
        joinButton.isEnabled = false
        availableRoomsButton.isEnabled = false
        apiService.getRoom(roomID: roomUUID) { [weak self] room, error in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.joinButton.isEnabled = true
            self.availableRoomsButton.isEnabled = true
            if let room = room {
                self.goToRoom(room: room, participantName: participantName)
            } else {
                self.showErrorAlert(errorMessage: error?.localizedDescription ?? "Invalid Room UUID")
            }
        }
    }

    @IBAction private func joinButtonAction() {
        guard let roomUUID = roomUUIDField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !roomUUID.isEmpty, !name.isEmpty else {
                  showErrorAlert(errorMessage: "Please enter a valid Room UUID and name to join the room.")
                  return
              }
        view.endEditing(true)
        self.fetchAndJoinRoom(participantName: name, roomUUID: roomUUID)
    }

}

extension JoinRoomViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == roomUUIDField {
            nameField.becomeFirstResponder()
        } else {
            joinButtonAction()
        }
        return true
    }
}
