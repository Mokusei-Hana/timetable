import SwiftUI

/// 列出所有周次，点一个就跳过去。
struct WeekPickerView: View {
    @Binding var week: Int
    let totalWeeks: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(1...max(1, totalWeeks), id: \.self) { value in
                    Button {
                        week = value
                        dismiss()
                    } label: {
                        HStack {
                            Text("第\(value)周")
                                .foregroundStyle(.primary)
                            Spacer()
                            if value == week {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择周次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WeekPickerView(week: .constant(5), totalWeeks: 22)
}
