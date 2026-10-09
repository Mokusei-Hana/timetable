import SwiftUI

/// 只依赖容器和字体约束；不会读取滚动位置或把几何结果写回状态。
private struct GridMetrics {
    let gap: CGFloat = 3
    let rail: CGFloat
    let column: CGFloat
    let header: CGFloat
    let row: CGFloat
    let contentHeight: CGFloat

    init(size: CGSize, rowCount: Int, fontSize: CGFloat) {
        let count = max(1, rowCount)
        rail = min(44, max(24, fontSize * 2))
        column = max(1, (size.width - rail - 7 * gap) / 7)
        header = max(40, fontSize * 3.2)
        let minimum = max(52, fontSize * 3.4 + 8)
        let maximum = max(minimum, 100)
        let usable = size.height - header - gap - CGFloat(count - 1) * gap
        row = min(maximum, max(minimum, floor(usable / CGFloat(count))))
        contentHeight = header + gap + row * CGFloat(count) + gap * CGFloat(count - 1)
    }
}

struct WeekGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption) private var fontSize: CGFloat = 12
    let snapshot: WeekPresentation
    let today: Date
    let viewport: CGSize
    let scrolls: Bool
    let select: (CourseCluster) -> Void

    var body: some View {
        let metrics = GridMetrics(size: viewport, rowCount: snapshot.blocks.count, fontSize: fontSize)
        Group {
            if scrolls {
                ScrollView(.vertical) { grid(metrics) }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                grid(metrics)
            }
        }
    }

    private func grid(_ metrics: GridMetrics) -> some View {
        HStack(alignment: .top, spacing: metrics.gap) {
            VStack(spacing: metrics.gap) {
                Text("节次").font(.system(size: fontSize)).foregroundStyle(.secondary)
                    .frame(width: metrics.rail, height: metrics.header)
                ForEach(snapshot.blocks) { block in
                    Text(block.sections.replacingOccurrences(of: ",", with: "\n"))
                        .font(.system(size: fontSize, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: metrics.rail, height: metrics.row, alignment: .top)
                        .accessibilityLabel(block.label)
                }
            }
            ForEach(snapshot.days) { day in
                dayColumn(day, metrics: metrics)
            }
        }
        .frame(width: viewport.width, height: metrics.contentHeight, alignment: .topLeading)
    }

    private func dayColumn(_ day: DayPresentation, metrics: GridMetrics) -> some View {
        let isToday = day.date.map { TimetableDoc.calendar.isDate($0, inSameDayAs: today) } ?? false
        let gridHeight = metrics.contentHeight - metrics.header - metrics.gap
        return VStack(spacing: metrics.gap) {
            VStack(spacing: 2) {
                Text(metrics.column < fontSize * 2 + 4 ? String(TimetableDoc.dayName(day.day).suffix(1)) : TimetableDoc.dayName(day.day)).lineLimit(1)
                if let date = day.date {
                    Text(date, format: .dateTime.day()).monospacedDigit()
                        .font(.system(size: min(fontSize, max(12, (metrics.column - 4) / 1.3)), weight: .medium))
                }
            }
            .font(.system(size: fontSize, weight: isToday ? .bold : .medium))
            .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
            .frame(width: metrics.column, height: metrics.header)
            .background(isToday ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .clipped()
            .accessibilityLabel("\(TimetableDoc.dayName(day.day))\(isToday ? "，今天" : "")")
            ZStack(alignment: .topLeading) {
                ForEach(day.clusters) { cluster in
                    let height = metrics.row * CGFloat(cluster.span) + metrics.gap * CGFloat(cluster.span - 1)
                    clusterCard(cluster, width: metrics.column, height: height)
                        .frame(width: metrics.column, height: height)
                        .offset(y: CGFloat(cluster.startBlock) * (metrics.row + metrics.gap))
                }
            }
            .frame(width: metrics.column, height: gridHeight, alignment: .topLeading)
        }
    }

    private func clusterCard(_ cluster: CourseCluster, width: CGFloat, height: CGFloat) -> some View {
        let lesson = cluster.lessons[0]
        let dark = colorScheme == .dark
        let padding: CGFloat = width < 44 ? 3 : 5
        // 七列总览的字号下限为 12；辅助功能大字号超出单列时，以列宽为上限，列表保留完整字号。
        let cardFont = min(fontSize, max(12, width - padding * 2))
        let showLocation = !cluster.isConflict && width >= cardFont * 3.5 && height >= cardFont * 7.5
        let reserved = showLocation ? cardFont * 2.4 : (cluster.isConflict ? cardFont * 1.5 : 0)
        let lines = max(1, min(6, Int((height - padding * 2 - reserved) / (cardFont * 1.3))))
        return Button { select(cluster) } label: {
            VStack(alignment: .leading, spacing: 2) {
                if cluster.isConflict {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(cluster.lessons.count)").lineLimit(1)
                    }.font(.system(size: cardFont, weight: .bold))
                }
                Text(lesson.course.name)
                    .font(.system(size: cardFont, weight: .semibold))
                    .lineLimit(lines).truncationMode(.tail)
                Spacer(minLength: 0)
                if showLocation {
                    Text(lesson.shortLocation).font(.system(size: cardFont)).lineLimit(2)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Design.ink(lesson.colorIndex, dark: dark))
            .background(Design.fill(lesson.colorIndex, dark: dark), in: RoundedRectangle(cornerRadius: 8))
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cluster.isConflict
            ? "\(cluster.lessons.count) 门课程时间冲突，轻点查看全部"
            : "\(lesson.course.name)，\(lesson.sections)，\(lesson.course.time)，\(lesson.course.location)")
        .accessibilityHint("窄卡片省略的信息可在详情或列表中完整查看")
    }
}
