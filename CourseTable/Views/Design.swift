import SwiftUI

/// 全局只使用一套间距、圆角和蓝灰色阶。
enum Design {
    static let gap: CGFloat = 8
    static let inset: CGFloat = 16
    static let radius: CGFloat = 16
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)

    static func accent(dark: Bool) -> Color {
        dark ? Color(red: 0.56, green: 0.72, blue: 1.0) : Color(red: 0.18, green: 0.35, blue: 0.69)
    }

    static func ink(_ course: Course, dark: Bool) -> Color {
        Color(hue: 0.59 + Double(course.colorSeed % 3) * 0.015,
              saturation: dark ? 0.16 : 0.38, brightness: dark ? 0.96 : 0.36)
    }

    static func fill(_ course: Course, dark: Bool) -> Color {
        Color(hue: 0.59 + Double(course.colorSeed % 3) * 0.015,
              saturation: dark ? 0.25 : 0.06 + Double(course.colorSeed % 3) * 0.025,
              brightness: dark ? 0.23 + Double(course.colorSeed % 3) * 0.025 : 0.96)
    }
}

/// 冲突课程分配独立泳道，每条泳道保留可读宽度，不互相覆盖。
struct DayLayout {
    var lanes: [[Course]] = []

    init(courses: [Course]) {
        var ends: [Int] = []
        for course in courses {
            if let lane = ends.firstIndex(where: { $0 <= course.startBlock }) {
                lanes[lane].append(course)
                ends[lane] = course.startBlock + course.span
            } else {
                lanes.append([course])
                ends.append(course.startBlock + course.span)
            }
        }
        if lanes.isEmpty { lanes = [[]] }
    }
}

struct TodaySnapshot {
    let doc: TimetableDoc
    let now: Date
    var week: Int? { doc.week(containing: now) }
    var lessons: [Course] {
        guard let week else { return [] }
        return doc.lessons(day: TimetableDoc.weekday(now), week: week).sorted {
            let a = $0.minuteRange?.lowerBound ?? 0
            let b = $1.minuteRange?.lowerBound ?? 0
            return a == b ? $0.id < $1.id : a < b
        }
    }
    var minute: Int {
        let calendar = TimetableDoc.calendar
        return calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    }
    var ongoing: [Course] { lessons.filter { $0.minuteRange?.contains(minute) == true } }
    var next: Course? { lessons.first { ($0.minuteRange?.lowerBound ?? -1) > minute } }
    var focus: Course? { ongoing.first ?? next }
    var status: String {
        if !ongoing.isEmpty { return ongoing.count > 1 ? "正在上课 · \(ongoing.count) 门同时进行" : "正在上课" }
        return "下一节"
    }
    var emptyTitle: String {
        if week == nil { return now < (doc.startDate ?? now) ? "新学期，尚未开始" : "本学期已结束" }
        return lessons.isEmpty ? "今天没有课" : "今天的课程已结束"
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
