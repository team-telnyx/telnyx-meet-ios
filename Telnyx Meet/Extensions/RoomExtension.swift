import TelnyxVideoSdk

extension Room {
    func isLocalParticipant(participantId: String) -> Bool {
        return participantId == state.localParticipantId
    }

    func isSubscribedTo(streamKey: String, participantId: String) -> Bool {
        return state.subscriptions[participantId]?[streamKey] != nil
    }

    func isParticipantSharingScreen(participantId: String) -> Bool {
        guard let stream = getParticipantStream(participantId: participantId, key: "presentation") else {
            return false
        }
        return stream.isVideoEnabled
    }

    func getParticipant(participantId: String) -> Participant? {
        return state.participants[participantId]
    }
}
