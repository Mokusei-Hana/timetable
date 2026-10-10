import SwiftUI

enum ScheduleViewMode: String, CaseIterable, Identifiable {
    case cards, list
    var id: String { rawValue }
    var title: String { self == .cards ? "卡片" : "列表" }
    var symbol: String { self == .cards ? "rectangle.grid.3x2" : "list.bullet" }
}

/// 一个常驻玻璃指示器沿等宽轨道移动，快速反向操作不会重新创建动画状态。
struct ViewModeSwitcher: View {
    @Binding var selection: ScheduleViewMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var direction
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36
    @Namespace private var glassNamespace

    var body: some View {
        ControlGlassGroup(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(ScheduleViewMode.allCases) { mode in
                    Button { selection = mode } label: {
                        Label(mode.title, systemImage: mode.symbol)
                            .font(.subheadline.weight(selection == mode ? .semibold : .regular))
                            .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity, minHeight: max(44, height))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CoursePressStyle())
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
                }
            }
            .background {
                GeometryReader { geometry in
                    ModeSelectionSurface(namespace: glassNamespace)
                        .frame(width: geometry.size.width / 2, height: geometry.size.height)
                        .offset(x: indicatorOnRight ? geometry.size.width / 2 : 0)
                        .animation(reduceMotion ? nil : InterfaceMotion.control, value: selection)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))
        .sensoryFeedback(.selection, trigger: selection)
        .respectMotionPreference()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("课表显示方式")
    }

    private var indicatorOnRight: Bool {
        direction == .leftToRight ? selection == .list : selection == .cards
    }
}

private struct ModeSelectionSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let namespace: Namespace.ID

    var body: some View {
        Group {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *), !reduceTransparency {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect(.regular.tint(Color.accentColor.opacity(0.10)), in: RoundedRectangle(cornerRadius: 12))
                    .glassEffectID("mode-selection", in: namespace)
            } else { opaqueSelection }
            #else
            opaqueSelection
            #endif
        }
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.6), lineWidth: 1)
            }
        }
    }

    private var opaqueSelection: some View {
        RoundedRectangle(cornerRadius: 12).fill(Design.surface)
    }
}
