import SwiftUI

/// 点开一格课以后看到的详细信息。
struct CourseDetailView: View {
    let course: Course
    let blocks: [ClassBlock]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("老师", value: course.teacher)
                    LabeledContent("地点", value: course.location)
                    LabeledContent("时间", value: course.time)
                    LabeledContent("节次", value: sectionsText)
                }

                Section {
                    LabeledContent("周次", value: course.weeksText)
                    LabeledContent("班级", value: course.className)
                    LabeledContent("考核", value: course.examType)
                    if let hours = course.hours {
                        LabeledContent("总学时", value: "\(hours)")
                    }
                    LabeledContent("课程号", value: course.courseCode)
                }
            }
            .navigationTitle(course.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// 把「第几个大节」翻回「第三四节」这种人话
    private var sectionsText: String {
        guard !blocks.isEmpty else { return "第\(course.startBlock + 1)大节" }
        let start = min(max(0, course.startBlock), blocks.count - 1)
        let end = min(max(start, course.startBlock + course.span - 1), blocks.count - 1)
        return blocks[start...end].map(\.label).joined(separator: "、")
    }
}

#Preview {
    CourseDetailView(
        course: Course(
            id: "demo",
            name: "高等数学",
            teacher: "张老师",
            location: "教学楼101(示例教室)",
            day: 1,
            startBlock: 0,
            span: 1,
            weeks: [3, 5, 7],
            weeksText: "3,5,7",
            time: "08:20-10:00",
            className: "示例班级",
            examType: "考查",
            hours: 16,
            courseCode: "0000000"
        ),
        blocks: [
            ClassBlock(index: 0, label: "第一二节", sections: "01,02"),
            ClassBlock(index: 1, label: "第三四节", sections: "03,04")
        ]
    )
}
