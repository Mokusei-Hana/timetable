import Foundation

/// 展示数据在载入文件、切换周次或跨日时生成，滚动和切换模式不重新筛课。
struct LessonPresentation: Identifiable, Sendable {
    let course: Course
    let shortLocation: String
    let sections: String
    let colorIndex: Int
    let minutes: Range<Int>?
    var id: String { course.id }
}

struct CourseCluster: Identifiable, Sendable {
    let lessons: [LessonPresentation]
    let startBlock: Int
    let span: Int
    var id: String { lessons[0].id }
    var isConflict: Bool { lessons.count > 1 }
}

struct DayPresentation: Identifiable, Sendable {
    let day: Int
    let date: Date?
    let lessons: [LessonPresentation]
    let clusters: [CourseCluster]
    var id: Int { day }
}

struct WeekPresentation: Sendable {
    let week: Int
    let blocks: [ClassBlock]
    let days: [DayPresentation]
    let count: Int
    static let empty = WeekPresentation(week: 1, blocks: [], days: [], count: 0)
}

struct TodaySchedule: Sendable {
    let date: Date
    let week: Int?
    let beforeTerm: Bool
    let lessons: [LessonPresentation]
    static let empty = TodaySchedule(date: .now, week: nil, beforeTerm: false, lessons: [])
}

/// 只保存一份按日排序的索引；当前周与今天各保存一个快照，不累积历史周缓存。
struct ScheduleIndex: Sendable {
    let doc: TimetableDoc
    let start: Date?
    let calendar: Calendar
    let lessonsByDay: [Int: [LessonPresentation]]

    init(doc: TimetableDoc) {
        self.doc = doc
        start = doc.startDate
        calendar = TimetableDoc.calendar
        var grouped: [Int: [LessonPresentation]] = [:]
        for course in doc.courses {
            let sections = doc.blocks
                .filter { $0.index >= course.startBlock && $0.index < course.startBlock + course.span }
                .flatMap { $0.sections.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } }
            let label: String
            if let first = sections.first, let last = sections.last {
                label = first == last ? "第 \(first) 节" : "第 \(first)–\(last) 节"
            } else { label = "节次未提供" }
            grouped[course.day, default: []].append(LessonPresentation(
                course: course, shortLocation: course.shortLocation, sections: label,
                colorIndex: course.colorSeed % 8, minutes: course.minuteRange))
        }
        for day in Array(grouped.keys) {
            grouped[day]?.sort {
                if $0.course.startBlock != $1.course.startBlock { return $0.course.startBlock < $1.course.startBlock }
                return $0.id < $1.id
            }
        }
        lessonsByDay = grouped
    }

    func week(containing date: Date) -> Int? {
        guard let start else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? -1
        guard days >= 0 else { return nil }
        let week = days / 7 + 1
        return week <= doc.totalWeeks ? week : nil
    }

    func nearestWeek(to date: Date) -> Int {
        week(containing: date) ?? (date < (start ?? date) ? 1 : max(1, doc.totalWeeks))
    }

    func presentation(week: Int) -> WeekPresentation {
        let monday = start.flatMap { calendar.date(byAdding: .day, value: (week - 1) * 7, to: $0) }
        let days = (1...7).map { day -> DayPresentation in
            let lessons = lessonsByDay[day, default: []].filter { $0.course.isActive(inWeek: week) }
            let date = monday.flatMap { calendar.date(byAdding: .day, value: day - 1, to: $0) }
            return DayPresentation(day: day, date: date, lessons: lessons, clusters: Self.clusters(lessons))
        }
        return WeekPresentation(week: week, blocks: doc.blocks, days: days,
                                count: days.reduce(0) { $0 + $1.lessons.count })
    }

    func today(at now: Date) -> TodaySchedule {
        let currentWeek = week(containing: now)
        let day = (calendar.component(.weekday, from: now) + 5) % 7 + 1
        let lessons = currentWeek.map { week in
            lessonsByDay[day, default: []].filter { $0.course.isActive(inWeek: week) }.sorted {
                let a = $0.minutes?.lowerBound ?? 0
                let b = $1.minutes?.lowerBound ?? 0
                return a == b ? $0.id < $1.id : a < b
            }
        } ?? []
        return TodaySchedule(date: now, week: currentWeek, beforeTerm: now < (start ?? now), lessons: lessons)
    }

    /// 先按周过滤，再合并真实重叠区间。相接但不重叠的大节不会被算作冲突。
    private static func clusters(_ lessons: [LessonPresentation]) -> [CourseCluster] {
        var result: [CourseCluster] = []
        var pending: [LessonPresentation] = []
        var start = 0
        var end = 0
        for lesson in lessons {
            let course = lesson.course
            if !pending.isEmpty && course.startBlock >= end {
                result.append(CourseCluster(lessons: pending, startBlock: start, span: end - start))
                pending = []
            }
            if pending.isEmpty { start = course.startBlock; end = start }
            pending.append(lesson)
            end = max(end, course.startBlock + course.span)
        }
        if !pending.isEmpty { result.append(CourseCluster(lessons: pending, startBlock: start, span: end - start)) }
        return result
    }
}
