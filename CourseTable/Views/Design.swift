import SwiftUI

/// 交互使用单一主色，课程使用低饱和背景与同色系深浅文字。
enum Design {
    static let gap: CGFloat = 8
    static let inset: CGFloat = 16
    static let radius: CGFloat = 16
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)

    static func accent(dark: Bool) -> Color {
        dark ? Color(red: 0.56, green: 0.72, blue: 1.0) : Color(red: 0.18, green: 0.35, blue: 0.69)
    }

    struct CourseColors {
        let lightFill: Color
        let lightInk: Color
        let darkFill: Color
        let darkInk: Color
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
              blue: Double(hex & 255) / 255)
    }

    private static let palette: [CourseColors] = [
        (0xE5EFFA, 0x24466B, 0x203247, 0xBED8F4),
        (0xEBE7F6, 0x504272, 0x302A44, 0xD5C8F0),
        (0xE0F0E7, 0x285844, 0x203A30, 0xB9E4CF),
        (0xF6EFD6, 0x655123, 0x3E3621, 0xEBDDAD),
        (0xF7E7EC, 0x743D51, 0x432C35, 0xF0C4D3),
        (0xF8E9DC, 0x754B2D, 0x423124, 0xEFCEAF),
        (0xDFEFED, 0x285954, 0x203A38, 0xB4DFDA),
        (0xF0E6F4, 0x634077, 0x3A2942, 0xE0C4ED)
    ].map { value in
        CourseColors(lightFill: color(UInt32(value.0)), lightInk: color(UInt32(value.1)),
                     darkFill: color(UInt32(value.2)), darkInk: color(UInt32(value.3)))
    }

    static func fill(_ index: Int, dark: Bool) -> Color {
        dark ? palette[index % palette.count].darkFill : palette[index % palette.count].lightFill
    }

    static func ink(_ index: Int, dark: Bool) -> Color {
        dark ? palette[index % palette.count].darkInk : palette[index % palette.count].lightInk
    }
}

/// 每分钟只计算一遍今日状态，不解析文件，不重新建立周课表。
struct TodaySnapshot {
    let week: Int?
    let lessons: [Course]
    let minute: Int
    let ongoing: [Course]
    let next: Course?
    let emptyTitle: String
    var focus: Course? { ongoing.first ?? next }
    var status: String {
        ongoing.isEmpty ? "下一节" : (ongoing.count > 1 ? "\(ongoing.count) 门正在上课" : "正在上课")
    }

    init(schedule: TodaySchedule, now: Date) {
        week = schedule.week
        lessons = schedule.lessons.map(\.course)
        let calendar = TimetableDoc.calendar
        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        minute = currentMinute
        ongoing = schedule.lessons.filter { $0.minutes?.contains(currentMinute) == true }.map(\.course)
        next = schedule.lessons.first { ($0.minutes?.lowerBound ?? -1) > currentMinute }?.course
        if schedule.week == nil {
            emptyTitle = schedule.beforeTerm ? "新学期，尚未开始" : "本学期已结束"
        } else {
            emptyTitle = schedule.lessons.isEmpty ? "今天没有课" : "今天的课程已结束"
        }
    }
}

@MainActor
extension View {
    func timetableAlert(_ store: TimetableStore, enabled: Bool = true) -> some View {
        alert("课表提示", isPresented: Binding(
            get: { enabled && store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("好", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }
}
