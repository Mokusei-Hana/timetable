import Foundation

/// 一个大节（两小节），对应课表里的一行。
struct ClassBlock: Codable, Hashable, Identifiable {
    /// 第几行，从 0 开始
    var index: Int
    /// 完整名字，例如「第一二节」
    var label: String
    /// 对应的小节编号，例如「01,02」
    var sections: String

    var id: Int { index }

    /// 左侧窄栏用的短名字，例如「一二节」
    var shortLabel: String {
        label.hasPrefix("第") ? String(label.dropFirst()) : label
    }
}

/// 一门课。
struct Course: Codable, Hashable, Identifiable {
    var id: String
    /// 课程名，例如「JAVA程序设计」
    var name: String
    /// 任课老师
    var teacher: String
    /// 上课地点（带教室全称），例如「教学楼101(示例教室)」
    var location: String
    /// 周几，1 = 周一，7 = 周日
    var day: Int
    /// 从第几个大节开始，0 = 第一二节
    var startBlock: Int
    /// 连上几个大节，通常是 1
    var span: Int
    /// 哪几周要上，例如 [3, 5, 7]
    var weeks: [Int]
    /// 周次的原始写法，例如「3-17」
    var weeksText: String
    /// 上课时间，例如「08:20-10:00」
    var time: String
    /// 上课班级
    var className: String
    /// 考核方式，考试 / 考查
    var examType: String
    /// 总学时
    var hours: Int?
    /// 课程编号
    var courseCode: String

    /// 这一周要不要上这门课
    func isActive(inWeek week: Int) -> Bool {
        weeks.contains(week)
    }

    /// 去掉括号里的教室全称，只留「教学楼101」这种短名
    var shortLocation: String {
        let cut = location.firstIndex { $0 == "(" || $0 == "（" } ?? location.endIndex
        let short = String(location[location.startIndex..<cut]).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? location : short
    }

    /// 给这门课挑颜色用的种子。
    ///
    /// 故意不用 Swift 自带的 hashValue：它每次启动都会变，会导致同一门课
    /// 这次打开是蓝色、下次打开变粉色。这里用固定算法的哈希，保证结果永远一样。
    var colorSeed: Int {
        var hash: UInt32 = 2166136261
        for byte in (name + "|" + teacher).utf8 {
            hash = (hash ^ UInt32(byte)) &* 16777619
        }
        return Int(hash & 0x7FFF_FFFF)
    }
}

/// 整个课表文件。
struct TimetableDoc: Codable {
    var schemaVersion: Int?
    /// 导出的日期
    var exportedAt: String?
    /// 学期，例如「2026-2027-1」
    var term: String
    /// 第 1 周周一的日期，格式 yyyy-MM-dd
    var termStartDate: String
    /// 一学期最多几周
    var totalWeeks: Int
    /// 每天有哪些大节
    var blocks: [ClassBlock]
    /// 所有课程
    var courses: [Course]

    /// 某一天有哪些课要上（按开始时间排序）
    func lessons(day: Int, week: Int) -> [Course] {
        courses.filter { $0.day == day && $0.isActive(inWeek: week) }
            .sorted { $0.startBlock < $1.startBlock }
    }

    /// 这一周有没有周末的课（用来提醒五天一栏的模式会漏掉东西）
    func hasWeekendCourse(week: Int) -> Bool {
        courses.contains { ($0.day == 6 || $0.day == 7) && $0.isActive(inWeek: week) }
    }

    /// 第 1 周周一的日期
    var startDate: Date? {
        TimetableDoc.dayFormatter.date(from: termStartDate)
    }

    /// 第几周的周一
    func monday(ofWeek week: Int) -> Date? {
        guard let start = startDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(byAdding: .day, value: (week - 1) * 7, to: start)
    }

    /// 今天是第几周（不在学期内就返回 nil）
    func week(containing date: Date) -> Int? {
        guard let start = startDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfStart = calendar.startOfDay(for: start)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfStart, to: startOfDate).day ?? 0
        guard days >= 0 else { return nil }
        let week = days / 7 + 1
        return week <= totalWeeks ? week : nil
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 读不到数据时的空壳，保证界面不会崩
    static let empty = TimetableDoc(
        schemaVersion: 1,
        exportedAt: nil,
        term: "还没有数据",
        termStartDate: "2026-09-07",
        totalWeeks: 20,
        blocks: [],
        courses: []
    )
}
