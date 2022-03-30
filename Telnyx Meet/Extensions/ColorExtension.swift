import UIKit

extension UIColor {
    static func getColorFromHex(hexString: String) -> UIColor {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hex.hasPrefix("#") {
            hex.remove(at: hexString.startIndex)
        }

        if hex.count != 6 {
            return UIColor.black
        }

        var rgb : UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let red   = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let blue  = CGFloat((rgb & 0x0000FF)) / 255
        let alpha = CGFloat(1.0)

        return UIColor.init(displayP3Red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - TelnyxColors
extension UIColor {
    static var txBackground: UIColor {
        return .getColorFromHex(hexString: "#1D2341")
    }

    static var txGreen: UIColor {
        return .getColorFromHex(hexString: "#00C08B")
    }

    static var txText: UIColor {
        return .white
    }
}
