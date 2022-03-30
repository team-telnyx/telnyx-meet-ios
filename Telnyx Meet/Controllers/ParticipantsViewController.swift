import UIKit
import TelnyxVideoSdk

class ParticipantsViewController: UIViewController {

    @IBOutlet private weak var table: UITableView!

    private var participants = [Participant]()
    weak var room: Room?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar(title: "Participants")
        setupTableView()
        updateParticipants()
    }

    private func updateParticipantsCount() {
        title = "Participants(\(participants.count))"
    }

    private func setupTableView() {
        table.tableFooterView = UIView()
        table.dataSource = self
        table.delegate = self
    }

    private func isMe(id: String) -> Bool {
        return room?.getState().localParticipantId == id
    }

    func updateParticipants() {
        self.participants = room?.state.participants.compactMap( {
            return !self.isMe(id: $1.id) ? $1 : nil
        }) ?? []
        if let localParticipant = try? room?.getLocalParticipant() {
            self.participants.insert(localParticipant, at: 0)
        }
        updateParticipantsCount()
        table.reloadData()
    }

    @IBAction private func closeButtonAction() {
        dismiss(animated: true, completion: nil)
    }
}

extension ParticipantsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return participants.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "participantCell") as? ParticipantListCell else {
            return UITableViewCell()
        }
        let participant = participants[indexPath.row]
        cell.configure(with: participant,
                       stream: room?.getParticipantStream(participantId: participant.id, key: "self"),
                       isMe: isMe(id: participant.id),
                       isSharingScreen: room?.isParticipantSharingScreen(participantId: participant.id) ?? false)
        return cell
    }
}

extension ParticipantsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
