import Foundation

/// 一个大节对应课表中的一行，位置从零开始。
struct ClassBlock: Codable, Hashable, Identifiable, Sendable {
    var index: Int
    var label: String
    var sections: String
    var id: Int { index }
}

struct Course: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var teacher: String
    var location: String
    var day: Int
    var startBlock: Int
    var span: Int
    var weeks: [Int]
    var weeksText: String
    var time: String
    var className: String
    var examType: String
    var hours: Int?
    var courseCode: String

    func isActive(inWeek week: Int) -> Bool { weeks.contains(week) }

    var shortLocation: String {
        let end = location.firstIndex { $0 == "(" || $0 == "（" } ?? location.endIndex
        let value = location[..<end].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? location : value
    }

    /// 学校课程编号跨星期、跨周次一致；排课记录 id 则可能不同，因此不用于配色。
    var colorSeed: Int {
        var hash: UInt32 = 2166136261
        let code = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = code.isEmpty ? "name:" + name.trimmingCharacters(in: .whitespacesAndNewlines) + "|" + teacher : "code:" + code
        for byte in key.precomposedStringWithCanonicalMapping.utf8 { hash = (hash ^ UInt32(byte)) &* 16777619 }
        return Int(hash & 0x7FFF_FFFF)
    }

    /// 时间字符串只负责钟点；周次和日期仍由学期起点决定。
    var minuteRange: Range<Int>? {
        let parts = time.split(separator: "-", omittingEmptySubsequences: false)
        func minutes(_ part: Substring) -> Int? {
            let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: ":")
            guard pieces.count == 2, let h = Int(pieces[0]), let m = Int(pieces[1]),
                  (0...23).contains(h), (0...59).contains(m) else { return nil }
            return h * 60 + m
        }
        guard parts.count == 2, let start = minutes(parts[0]), let end = minutes(parts[1]),
              end > start else { return nil }
        return start..<end
    }
}

struct TimetableDoc: Codable, Sendable {
    var schemaVersion: Int
    var exportedAt: String
    var term: String
    var termStartDate: String
    var totalWeeks: Int
    var blocks: [ClassBlock]
    var courses: [Course]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    /// 每次使用当前时区，避免跨时区后沿用旧格式器的设置。
    static func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else { return nil }
        return date
    }

    var startDate: Date? { Self.parseDate(termStartDate) }

    func monday(ofWeek week: Int) -> Date? {
        guard (1...max(1, totalWeeks)).contains(week), let start = startDate else { return nil }
        return Self.calendar.date(byAdding: .day, value: (week - 1) * 7, to: start)
    }

    func date(day: Int, week: Int) -> Date? {
        guard (1...7).contains(day), let monday = monday(ofWeek: week) else { return nil }
        return Self.calendar.date(byAdding: .day, value: day - 1, to: monday)
    }

    func week(containing date: Date) -> Int? {
        guard let start = startDate else { return nil }
        let calendar = Self.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? -1
        guard days >= 0 else { return nil }
        let week = days / 7 + 1
        return week <= totalWeeks ? week : nil
    }

    static func weekday(_ date: Date) -> Int { (calendar.component(.weekday, from: date) + 5) % 7 + 1 }
    static func dayName(_ day: Int) -> String { ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][min(7, max(1, day)) - 1] }

    func lessons(day: Int, week: Int) -> [Course] {
        courses.filter { $0.day == day && $0.isActive(inWeek: week) }.sorted {
            if $0.startBlock != $1.startBlock { return $0.startBlock < $1.startBlock }
            return $0.id < $1.id
        }
    }

    func hasWeekendCourse(week: Int) -> Bool {
        courses.contains { $0.day >= 6 && $0.isActive(inWeek: week) }
    }

    /// 在改变当前数据之前检查结构和布局边界，错误文件不会覆盖原课表。
    func validated() throws -> TimetableDoc {
        func require(_ condition: Bool, _ reason: String) throws {
            if !condition { throw TimetableError.invalid(reason) }
        }
        try require(schemaVersion == 1, "仅支持 schemaVersion 为 1 的课表。")
        try require(totalWeeks > 0 && totalWeeks <= Int.max / 7, "totalWeeks 必须是有效的正整数。")
        guard let start = startDate else { throw TimetableError.invalid("termStartDate 必须是 yyyy-MM-dd 格式的有效日期。") }
        try require(Self.calendar.component(.weekday, from: start) == 2, "termStartDate 必须是第 1 周的周一。")
        try require(Self.parseDate(exportedAt) != nil, "exportedAt 必须是 yyyy-MM-dd 格式的有效日期。")
        let sorted = blocks.sorted { $0.index < $1.index }
        try require(!sorted.isEmpty && sorted.map(\.index) == Array(0..<sorted.count), "blocks 的 index 必须从 0 开始连续排列。")
        for block in sorted {
            let expected = [block.index * 2 + 1, block.index * 2 + 2]
            let actual = block.sections.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            try require(actual == expected, "第 \(block.index + 1) 个大节的 sections 不正确。")
        }
        try require(Set(courses.map(\.id)).count == courses.count, "课程 id 重复，请重新导出课表。")
        for course in courses {
            try require(!course.id.isEmpty && !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "课程 id 和 name 不能为空。")
            try require((1...7).contains(course.day), "「\(course.name)」的 day 必须为 1 到 7。")
            try require((0..<sorted.count).contains(course.startBlock) && (1...sorted.count).contains(course.span), "「\(course.name)」的起始大节或跨度无效。")
            try require(course.span <= sorted.count - course.startBlock, "「\(course.name)」超出了当天大节范围。")
            try require(course.weeks.allSatisfy { (1...totalWeeks).contains($0) }, "「\(course.name)」的周次超出了学期范围。")
            try require(course.minuteRange != nil, "「\(course.name)」的 time 应为当天的 HH:mm-HH:mm，结束时间应晚于开始时间。")
            try require((course.hours ?? 0) >= 0, "「\(course.name)」的 hours 不能为负数。")
        }
        var document = self
        document.blocks = sorted
        return document
    }

    static let empty = TimetableDoc(schemaVersion: 1, exportedAt: "", term: "还没有课表",
                                    termStartDate: "2026-09-07", totalWeeks: 1, blocks: [], courses: [])
}

enum TimetableError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let text): return text }
    }
}
