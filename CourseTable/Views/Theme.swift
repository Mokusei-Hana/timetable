import SwiftUI

extension Color {
    /// 用 0xRRGGBB 这种写法建颜色，比 Color(red:green:blue:) 好认
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

/// 课块的颜色。用的是学校网页上那套柔和的颜色，看起来眼熟。
enum Palette {
    static let fills: [Color] = [
        Color(hex: 0xFFBE80), // 橙
        Color(hex: 0x86B5FF), // 蓝
        Color(hex: 0xFF9FC2), // 粉
        Color(hex: 0x89D6A0), // 绿
        Color(hex: 0xB9B4FE), // 紫
        Color(hex: 0xFF8282), // 珊瑚红
        Color(hex: 0x55D7C7), // 青
        Color(hex: 0xEE7BFF)  // 品红
    ]

    /// 同一门课永远给同一个颜色（靠 course.colorSeed，跟启动次数无关）
    static func fill(for course: Course) -> Color {
        guard !fills.isEmpty else { return Color.gray }
        return fills[course.colorSeed % fills.count]
    }

    /// 课块上的字色
    static let blockText = Color(hex: 0x2E2A28).opacity(0.85)
}
