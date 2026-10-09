import Foundation
import Combine

@MainActor
final class TimetableStore: ObservableObject {
    @Published private(set) var doc: TimetableDoc = .empty
    @Published private(set) var week = 1
    @Published private(set) var sourceName = "没有数据"
    @Published private(set) var isImported = false
    @Published var message: String?
    private var followsToday = true

    var hasData: Bool { !doc.blocks.isEmpty }
    var totalWeeks: Int { max(1, doc.totalWeeks) }

    init() {
        do {
            let url = try Self.importedURL()
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    apply(try Self.read(url), imported: true)
                    return
                } catch {
                    message = "保存的课表无法读取，已尝试使用自带数据。\n\(error.localizedDescription)"
                }
            }
            apply(try Self.bundled(), imported: false)
        } catch {
            message = "课表读取失败，请从「数据管理」导入。\n\(error.localizedDescription)"
        }
    }

    func selectWeek(_ value: Int) {
        followsToday = false
        week = min(max(1, value), totalWeeks)
    }

    func changeWeek(by delta: Int) { selectWeek(week + delta) }

    func jumpToToday() {
        followsToday = true
        refreshToday()
    }

    /// 浏览其他周时不抢回当前位置；停留本周时随日期自然更新。
    func refreshToday(_ now: Date = Date()) {
        guard followsToday else { return }
        if let current = doc.week(containing: now) {
            week = current
        } else {
            week = now < (doc.startDate ?? now) ? 1 : totalWeeks
        }
    }

    private func apply(_ document: TimetableDoc, imported: Bool) {
        doc = document
        isImported = imported
        sourceName = imported ? "导入的课表" : "自带课表"
        jumpToToday()
    }

    private static func importedURL() throws -> URL {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TimetableError.invalid("无法访问本机文稿目录。")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("timetable.json")
    }

    private static func bundled() throws -> TimetableDoc {
        guard let url = Bundle.main.url(forResource: "timetable", withExtension: "dat") else {
            throw TimetableError.invalid("App 内缺少 timetable.dat 资源。")
        }
        return try read(url)
    }

    private static func read(_ url: URL) throws -> TimetableDoc {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 10 * 1024 * 1024 else { throw TimetableError.invalid("课表文件不能超过 10 MB。") }
        return try decode(Data(contentsOf: url))
    }

    /// 明文优先，只有结构解码失败才尝试去掉换行后的 base64。
    private static func decode(_ data: Data) throws -> TimetableDoc {
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
    func importFile(at url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let parsed = try Self.read(url)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let saved = try encoder.encode(parsed)
            // 原子写入成功后才替换内存数据，失败时保留原课表。
            try saved.write(to: Self.importedURL(), options: .atomic)
            apply(parsed, imported: true)
            message = "导入成功，共 \(parsed.courses.count) 条课程安排。"
            return true
        } catch {
            message = "导入失败，原课表未更改。\n\(error.localizedDescription)"
            return false
        }
    }

    func resetToBundled() {
        do {
            let bundled = try Self.bundled()
            let url = try Self.importedURL()
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            apply(bundled, imported: false)
            message = "已恢复自带课表。"
        } catch {
            message = "恢复失败，原课表未更改。\n\(error.localizedDescription)"
        }
    }
}
