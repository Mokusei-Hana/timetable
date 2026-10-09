import Foundation
import Combine

@MainActor
final class TimetableStore: ObservableObject {
    @Published private(set) var doc: TimetableDoc = .empty
    @Published private(set) var presentation: WeekPresentation = .empty
    @Published private(set) var todaySchedule: TodaySchedule = .empty
    @Published private(set) var sourceName = "没有数据"
    @Published private(set) var isImported = false
    @Published private(set) var isBusy = true
    @Published var message: String?
    private var followsToday = true
    private var index: ScheduleIndex?

    var week: Int { presentation.week }
    var hasData: Bool { !doc.blocks.isEmpty }
    var totalWeeks: Int { max(1, doc.totalWeeks) }

    init() {
        Task { await loadInitial() }
    }

    private func loadInitial() async {
        defer { isBusy = false }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                var notice: String?
                do {
                    let url = try Self.importedURL()
                    if FileManager.default.fileExists(atPath: url.path) {
                        do {
                            return (ScheduleIndex(doc: try Self.read(url)), true, Optional<String>.none)
                        } catch {
                            notice = "保存的课表无法读取，已尝试使用自带数据。\n\(error.localizedDescription)"
                        }
                    }
                } catch {
                    notice = "无法访问导入副本，已尝试使用自带数据。\n\(error.localizedDescription)"
                }
                return (ScheduleIndex(doc: try Self.bundled()), false, notice)
            }.value
            apply(result.0, imported: result.1)
            message = result.2
        } catch {
            message = "课表读取失败，请从「数据管理」导入。\n\(error.localizedDescription)"
        }
    }

    func selectWeek(_ value: Int) {
        followsToday = false
        setWeek(value)
    }

    private func setWeek(_ value: Int) {
        let target = min(max(1, value), totalWeeks)
        guard let index, target != week || presentation.days.isEmpty else { return }
        presentation = index.presentation(week: target)
    }

    func changeWeek(by delta: Int) { selectWeek(week + delta) }

    func jumpToToday() {
        followsToday = true
        refreshToday()
    }

    /// 分钟变化只在今日卡片内更新；只有跨日、时区或周次变化才发布新快照。
    func refreshToday(_ now: Date = Date()) {
        guard var current = index else { return }
        let zoneChanged = current.calendar.timeZone != TimeZone.current
        if zoneChanged {
            current = ScheduleIndex(doc: doc)
            index = current
        }
        if zoneChanged || !current.calendar.isDate(todaySchedule.date, inSameDayAs: now) {
            todaySchedule = current.today(at: now)
        }
        if followsToday {
            let target = current.nearestWeek(to: now)
            if target != week || zoneChanged { presentation = current.presentation(week: target) }
        } else if zoneChanged {
            presentation = current.presentation(week: week)
        }
    }

    private func apply(_ prepared: ScheduleIndex, imported: Bool) {
        let now = Date()
        index = prepared
        doc = prepared.doc
        isImported = imported
        sourceName = imported ? "导入的课表" : "自带课表"
        followsToday = true
        presentation = prepared.presentation(week: prepared.nearestWeek(to: now))
        todaySchedule = prepared.today(at: now)
    }

    nonisolated private static func importedURL() throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TimetableError.invalid("无法访问本机文稿目录。")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("timetable.json")
    }

    nonisolated private static func bundled() throws -> TimetableDoc {
        guard let url = Bundle.main.url(forResource: "timetable", withExtension: "dat") else {
            throw TimetableError.invalid("App 内缺少 timetable.dat 资源。")
        }
        return try read(url)
    }

    nonisolated private static func read(_ url: URL) throws -> TimetableDoc {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 10 * 1024 * 1024 else { throw TimetableError.invalid("课表文件不能超过 10 MB。") }
        return try decode(Data(contentsOf: url))
    }

    /// 明文优先，只有结构解码失败才尝试去掉换行后的 base64。
    nonisolated private static func decode(_ data: Data) throws -> TimetableDoc {
        guard data.count <= 10 * 1024 * 1024 else { throw TimetableError.invalid("课表文件不能超过 10 MB。") }
        let decoder = JSONDecoder()
        if let document = try? decoder.decode(TimetableDoc.self, from: data) {
            return try document.validated()
        }
        if let text = String(data: data, encoding: .utf8),
           let raw = Data(base64Encoded: text.components(separatedBy: .whitespacesAndNewlines).joined()),
           let document = try? decoder.decode(TimetableDoc.self, from: raw) {
            return try document.validated()
        }
        throw TimetableError.invalid("无法识别课表。请选择完整的 JSON 或 base64 DAT 文件，并检查字段名称与类型；hours 应为整数、null 或省略。")
    }

    @discardableResult
    func importFile(at url: URL) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            isBusy = false
        }
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                let parsed = try Self.read(url)
                let prepared = ScheduleIndex(doc: parsed)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                // 原子写入成功后才替换内存数据，失败时保留原课表。
                try encoder.encode(parsed).write(to: Self.importedURL(), options: .atomic)
                return prepared
            }.value
            apply(prepared, imported: true)
            message = "导入成功，共 \(prepared.doc.courses.count) 条课程安排。"
            return true
        } catch {
            message = "导入失败，原课表未更改。\n\(error.localizedDescription)"
            return false
        }
    }

    func resetToBundled() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                let prepared = ScheduleIndex(doc: try Self.bundled())
                let url = try Self.importedURL()
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                return prepared
            }.value
            apply(prepared, imported: false)
            message = "已恢复自带课表。"
        } catch {
            message = "恢复失败，原课表未更改。\n\(error.localizedDescription)"
        }
    }
}
