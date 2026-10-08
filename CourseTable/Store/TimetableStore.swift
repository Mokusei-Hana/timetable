import Foundation

/// 课表数据 + 当前看第几周。界面上的东西都从这里读。
final class TimetableStore: ObservableObject {
    /// 课表内容
    @Published private(set) var doc: TimetableDoc
    /// 数据是哪来的，显示在底部方便区分
    @Published private(set) var sourceName: String
    /// 正在看第几周
    @Published var week: Int
    /// 需要弹给用户看的一句话，nil 表示不弹
    @Published var message: String?

    private static let importedFileName = "timetable.json"

    init() {
        let imported = Self.loadImported()
        let bundled = Self.loadBundled()

        let document: TimetableDoc
        let name: String
        if let imported {
            document = imported
            name = "用导入的数据"
        } else if let bundled {
            document = bundled
            name = "用自带的数据"
        } else {
            document = .empty
            name = "没有数据"
        }

        doc = document
        sourceName = name
        // 打开就停在今天所在的那一周
        week = Self.weekForToday(in: document)
    }

    // MARK: - 改周次

    var totalWeeks: Int { max(1, doc.totalWeeks) }

    func changeWeek(by delta: Int) {
        week = min(max(1, week + delta), totalWeeks)
    }

    func jumpToToday() {
        week = Self.weekForToday(in: doc)
    }

    /// 现在看到的这一周是不是就是今天所在的周
    var isShowingToday: Bool {
        doc.week(containing: Date()) == week
    }

    private static func weekForToday(in doc: TimetableDoc) -> Int {
        let today = doc.week(containing: Date()) ?? 1
        return min(max(1, today), max(1, doc.totalWeeks))
    }

    // MARK: - 日期显示

    /// 这一周七天的日期
    var weekDates: [Date] {
        guard let monday = doc.monday(ofWeek: week) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// 学期第一周到这一周，写成「10/05 - 10/11」
    var weekRangeText: String {
        let dates = weekDates
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(Self.shortDate.string(from: first)) - \(Self.shortDate.string(from: last))"
    }

    /// 要显示哪几天
    func visibleDays(dayCount: Int) -> [Int] {
        Array(1...min(max(1, dayCount), 7))
    }

    func weekdayName(_ day: Int) -> String {
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        guard day >= 1, day <= 7 else { return "" }
        return names[day - 1]
    }

    func dayNumberText(_ day: Int) -> String {
        guard let date = date(forDay: day) else { return "" }
        return Self.shortDate.string(from: date)
    }

    func date(forDay day: Int) -> Date? {
        let dates = weekDates
        guard day >= 1, day <= dates.count else { return nil }
        return dates[day - 1]
    }

    /// 这一列是不是今天
    func isToday(_ day: Int) -> Bool {
        guard let date = date(forDay: day) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    // MARK: - 读数据

    private static var importedURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(importedFileName)
    }

    private static func loadImported() -> TimetableDoc? {
        guard let url = importedURL, let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    private static func loadBundled() -> TimetableDoc? {
        guard let url = Bundle.main.url(forResource: "timetable", withExtension: "dat"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    /// 自带的数据是混淆过的（base64），导入的是明文 JSON，两种都能读
    private static func decode(_ data: Data) -> TimetableDoc? {
        if let doc = try? JSONDecoder().decode(TimetableDoc.self, from: data) {
            return doc
        }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let compact = text.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let raw = Data(base64Encoded: compact) else { return nil }
        return try? JSONDecoder().decode(TimetableDoc.self, from: raw)
    }

    /// 从「文件」App 里选一个课表文件导进来
    @discardableResult
    func importFile(at url: URL) -> Bool {
        // 从别的地方选来的文件，要先申请访问权限
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            guard let parsed = Self.decode(data) else {
                message = "导入失败：这个文件里没有能识别的课表数据"
                return false
            }
            if let destination = Self.importedURL {
                try data.write(to: destination, options: .atomic)
            }

            doc = parsed
            sourceName = "用导入的数据"
            week = Self.weekForToday(in: parsed)
            message = "导入成功，共 \(parsed.courses.count) 门课"
            return true
        } catch {
            message = "导入失败：\(error.localizedDescription)"
            return false
        }
    }

    /// 删掉导入的数据，用回 App 自带那份
    func resetToBundled() {
        if let url = Self.importedURL {
            try? FileManager.default.removeItem(at: url)
        }
        guard let bundled = Self.loadBundled() else {
            message = "自带的数据也读不到了"
            return
        }
        doc = bundled
        sourceName = "用自带的数据"
        week = Self.weekForToday(in: bundled)
        message = "已恢复成自带的数据"
    }
}
