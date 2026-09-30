import SwiftUI

extension Color {
    static let appAccent = Color(red: 1.0, green: 0.42, blue: 0.21)
    static let appSuccess = Color(red: 0.0, green: 0.78, blue: 0.55)
    static let appMuted = Color(.secondarySystemBackground)
}

extension ShapeStyle where Self == Color {
    static var appAccent: Color { .appAccent }
    static var appSuccess: Color { .appSuccess }
    static var appMuted: Color { .appMuted }
}

enum AppTheme {
    static func courseColor(_ hex: String) -> Color {
        var value: UInt64 = 0
        let clean = hex.replacingOccurrences(of: "#", with: "")
        Scanner(string: clean).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    static let coursePalette = ["#FF6B35", "#00C78C", "#4C9AFF", "#B37FEB", "#FFD43B", "#FF7782"]
}

enum AppVersion {
    static var display: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(version) (\(build))"
    }
}
