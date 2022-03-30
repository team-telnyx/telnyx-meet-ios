import TelnyxVideoSdk

extension Participant {
    var name: String {
        if let name = context?["username"]?.value as? String {
            return name
        } else if let external = context?["external"]?.value as? String,
                  let dict = external.dictionary,
                  let name = dict["username"]?.value as? String {
            return name
        }
        return "Unknown"
    }
}
