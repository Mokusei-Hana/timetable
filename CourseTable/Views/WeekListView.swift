import SwiftUI

struct WeekListView: View {
    let snapshot: WeekPresentation
    let today: Date
    let select: (Course) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(snapshot.days) { day in
                Section {
                    if day.lessons.isEmpty {
                        Text("当天无课").font(.subheadline).foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    } else {
                        ForEach(day.lessons) { lesson in
                            Button { select(lesson.course) } label: { LessonListRow(lesson: lesson) }
                                .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text(TimetableDoc.dayName(day.day)).font(.headline)
                        if let date = day.date {
                            Text(date, format: .dateTime.month().day()).font(.subheadline).foregroundStyle(.secondary)
                            if TimetableDoc.calendar.isDate(date, inSameDayAs: today) {
                                Text("今天").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                            }
                        }
                        Spacer()
                    }.padding(.top, 8)
                }
            }
        }.padding(.bottom, 16)
    }
}

struct LessonListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let lesson: LessonPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Design.fill(lesson.colorIndex, dark: colorScheme == .dark))
                .frame(width: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text(lesson.course.name).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(TimetableDoc.dayName(lesson.course.day)) · \(lesson.sections)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(lesson.course.time).font(.subheadline.weight(.medium)).monospacedDigit()
                    .foregroundStyle(Design.ink(lesson.colorIndex, dark: colorScheme == .dark))
                Text(lesson.course.location.isEmpty ? "地点未提供" : lesson.course.location)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.surface, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
}

struct ConflictCoursesView: View {
    let cluster: CourseCluster
    let week: Int
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("以下课程的节次存在重叠。每门课的实际时间与节次如下，请核对上课安排。")
                    .font(.subheadline).foregroundStyle(.secondary)
                ForEach(cluster.lessons) { lesson in
                    NavigationLink {
                        CourseDetailView(course: lesson.course, week: week)
                    } label: { LessonListRow(lesson: lesson) }
                        .buttonStyle(.plain)
                }
            }.padding(16)
        }
        .background(Design.background)
        .navigationTitle("课程冲突")
        .navigationBarTitleDisplayMode(.inline)
    }
}
