import UIKit

class VideoMeetRoomsListViewController: UIViewController {

    @IBOutlet private weak var roomsTable: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var emptyStateView: UIView!

    private let apiService = RoomsAPIService()
    private var rooms = [RoomInfo]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar(title: "Rooms")
        setupRoomsTable()
        getAllRooms()
    }

    private func setupRoomsTable() {
        roomsTable.dataSource = self
        roomsTable.delegate = self
        roomsTable.register(UINib(nibName: String(describing: VideoMeetRoomCell.self), bundle: nil),
                            forCellReuseIdentifier: String(describing: VideoMeetRoomCell.self))
        roomsTable.separatorStyle = .none
        roomsTable.estimatedRowHeight = 82
        roomsTable.rowHeight = UITableView.automaticDimension
    }

    private func getAllRooms() {
        activityIndicator.startAnimating()
        apiService.getAllRooms { [weak self] rooms, error in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            if let rooms = rooms {
                self.rooms = rooms.sorted { ($0.uniqueName ?? "") < ($1.uniqueName ?? "") }
                DispatchQueue.main.async {
                    self.roomsTable.reloadData()
                    self.emptyStateView.isHidden = !self.rooms.isEmpty
                }
            } else {
                self.showErrorAlert(errorMessage: error?.localizedDescription ?? "Some error occurred. Please try again later.")
            }
        }
    }

    private func showErrorAlert(errorMessage: String) {
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDelegate UITableViewDataSource
extension VideoMeetRoomsListViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rooms.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: VideoMeetRoomCell.self))
                as? VideoMeetRoomCell else {
                    return UITableViewCell()
                }
        let room = rooms[indexPath.row]
        cell.roomName.text = room.uniqueName
        cell.setRoomId(roomId: room.id)
        cell.setMaxParticipants(participants: room.maxParticipants ?? 0)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        joinRoomWithParticipantName(rooms[indexPath.row])
    }

    private func goToRoom(room: RoomInfo, participantName: String) {
        guard let vc = storyboard?.viewController(of: VideoMeetRoomViewController.self) else {
            return
        }
        vc.participantName = participantName
        vc.roomInfo = room
        navigationController?.pushViewController(vc, animated: true)
    }

    private func joinRoomWithParticipantName(_ room: RoomInfo) {
        let alert = UIAlertController(title: "Join '\(room.uniqueName ?? "Room")'", message: "Please enter your name", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.autocapitalizationType = .words
            textField.textContentType = .name
            textField.returnKeyType = .join
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        }
        let join = UIAlertAction(title: "Join", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            self?.goToRoom(room: room, participantName: name)
        }
        alert.addAction(cancel)
        alert.addAction(join)
        present(alert, animated: true, completion: nil)
    }
}
