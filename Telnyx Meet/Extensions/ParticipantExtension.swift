import TelnyxVideoSdk

extension Participant {
    var name: String {
        if let name = context?["username"] as? String {
            return name
        } else if let external = context?["external"] as? String,
                  let dict = try? external.toJSON() as? JSONObject,
                  let name = dict["username"] as? String {
            return name
        }
        return "Unknown"
    }
}
