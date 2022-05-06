import UIKit
import TelnyxVideoSdk

protocol ChatViewControllerDelegate: AnyObject {
    func onSendMessage(message: String)
}

class ChatViewController: UIViewController {

    weak var room: Room?
    private var messages = [MessageItem]()

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var inputBar: UIView!
    @IBOutlet private weak var inputField: UITextView!
    @IBOutlet private weak var inputFieldPlaceHolder: UILabel!
    @IBOutlet private weak var sendButton: UIButton!
    @IBOutlet private weak var inputFieldHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var sendButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var sendButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var inputViewBottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar(title: "Chat")
        setupInputView()
        setupTableView()
        subscribeKeyboardEvents()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.scrollToBottom()
        }
    }

    func setMessages(messages: [MessageItem]) {
        self.messages = messages
    }

    func addMessage(_ message: MessageItem) {
        let newIndex = messages.isEmpty ? 0 : messages.count
        let indexPath = IndexPath(row: newIndex, section: 0)

        tableView.beginUpdates()
        messages.append(message)
        tableView.insertRows(at: [indexPath], with: .bottom)
        tableView.endUpdates()

        scrollToBottom()
    }

    private func setupInputView() {
        sendButton.isEnabled = false
        sendButtonWidthConstraint.constant = 0
        sendButtonTrailingConstraint.constant = 0

        inputField.delegate = self
        inputField.layer.cornerRadius = 16.5
        inputField.layer.borderWidth = 1
        if #available(iOS 13.0, *) {
            inputField.layer.borderColor = UIColor.tertiaryLabel.cgColor
        } else {
            // Fallback on earlier versions
        }
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(UINib(nibName: String(describing: ChatMessageCell.self), bundle: nil), forCellReuseIdentifier: String(describing: ChatMessageCell.self))
    }

    private func resetInputView() {
        inputField.text = nil
        updateInputBarHeight()
        sendButton.isEnabled = false
        inputFieldPlaceHolder.isHidden = false
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.sendButtonWidthConstraint.constant = 0
            self.sendButtonTrailingConstraint.constant = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
        }
    }

    private func subscribeKeyboardEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardWillChange(notification: NSNotification) {
        if notification.name == UIResponder.keyboardWillHideNotification {
            inputViewBottomConstraint.constant = 0
            UIView.animate(withDuration: 0.25) {
                self.view.layoutIfNeeded()
            }
            return
        }
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        inputViewBottomConstraint.constant = -(keyboardFrame.size.height - view.safeAreaInsets.bottom)
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateInputBarHeight() {
        let fixedWidth = inputField.frame.size.width - 46
        inputField.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        let newSize = inputField.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        var newFrame = inputField.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        var height = newFrame.height
        if height > 100 {
            height = 100
        }
        inputFieldHeightConstraint.constant = height
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count-1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    private func isMe(sender: String?) -> Bool {
        return sender == room?.getState().localParticipantId
    }

    private func getParticipantName(sender: String) -> String {
        guard let participant = room?.getParticipant(participantId: sender) else {
            return "Unknown"
        }
        return participant.name
    }

    @IBAction private func closeBtnAction() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func sendMessage() {
        let newMessage = inputField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newMessage.isEmpty {
            let message = Message(messageType: .text, payload: newMessage, meta: nil)
            room?.sendMessage(message, recipients: nil, onSuccess: {
            })
            resetInputView()
        }
    }
}

extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        inputFieldPlaceHolder.isHidden = !textView.text.isEmpty
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !text.isEmpty
        sendButton.isEnabled = hasContent
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.sendButtonWidthConstraint.constant = hasContent ? 30 : 0
            self.sendButtonTrailingConstraint.constant = hasContent ? 8 : 0
            self.view.layoutIfNeeded()
        } completion: { _ in
        }
        updateInputBarHeight()
    }
}

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let senderName = getParticipantName(sender: message.sender)

        if let messageCell = tableView.dequeueReusableCell(withIdentifier: String(describing: ChatMessageCell.self)) as? ChatMessageCell {
            messageCell.display(message: message, senderName: senderName, isRemote: !isMe(sender: message.sender))
            return messageCell
        }

        return UITableViewCell()
    }
}
