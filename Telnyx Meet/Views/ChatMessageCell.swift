import UIKit

class ChatMessageCell: UITableViewCell {
    @IBOutlet private weak var messageContainerView: UIView!
	@IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var messageTextView: UITextView!
    @IBOutlet private var messageContainerViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private var messageContainerViewTrailingConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        messageTextView.isEditable = false
        messageTextView.isScrollEnabled = false
        messageContainerView.layer.cornerRadius = 10
        messageContainerView.clipsToBounds = true
        usernameLabel.textColor = .white
        messageTextView.textColor = .white
    }

    func display(message: MessageItem, senderName: String, isRemote: Bool) {
        if isRemote {
            messageContainerViewLeadingConstraint.isActive = true
            messageContainerViewTrailingConstraint.isActive = false
            messageContainerView.backgroundColor = .txBackground
            messageContainerView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
        } else {
            messageContainerViewTrailingConstraint.isActive = true
            messageContainerViewLeadingConstraint.isActive = false
            messageContainerView.backgroundColor = .txGreen
            messageContainerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner]
        }
        usernameLabel.text = isRemote ? senderName : "Me"
        messageTextView.text = message.message.payload
    }
}
