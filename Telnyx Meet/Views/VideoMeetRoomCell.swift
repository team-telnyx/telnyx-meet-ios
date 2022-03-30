import UIKit

class VideoMeetRoomCell : UITableViewCell {
    @IBOutlet weak var roomName: UILabel!
    @IBOutlet weak var roomId: UILabel!
    @IBOutlet weak var roomMaxParticipants: UILabel!

    func setMaxParticipants(participants: Int) {
        self.roomMaxParticipants.text = "Max Participants: \(participants)"
    }

    func setRoomId(roomId: String) {
        self.roomId.text = "RoomID: \(roomId)"
    }
}
