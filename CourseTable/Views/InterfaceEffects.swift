import SwiftUI

/// 动效只用于用户操作；时钟、文件解析和课程索引不参与动画状态。
enum InterfaceMotion {
    static let control = Animation.spring(response: 0.30, dampingFraction: 0.92)
    static let expansion = Animation.spring(response: 0.34, dampingFraction: 0.94)
    static let content = Animation.easeInOut(duration: 0.18)
    static let press = Animation.easeOut(duration: 0.12)
}

/// 内容卡片保持不透明，按压只改变显示变换，不重新测量布局。
struct CoursePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.82 : 1))
            .animation(reduceMotion ? nil : InterfaceMotion.press, value: configuration.isPressed)
    }
}

/// 同一操作区共享玻璃渲染；旧 SDK 完全不引用新符号。
struct ControlGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct ControlGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let id: String
    let namespace: Namespace.ID
    let interactive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .glassEffect(.regular.interactive(interactive && !reduceMotion), in: Capsule())
                .glassEffectID(id, in: namespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            content.background(Design.surface, in: Capsule())
        }
        #else
        content.background(Design.surface, in: Capsule())
        #endif
    }
}

private struct AdaptiveActionStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency, !reduceMotion {
            if prominent { content.buttonStyle(.glassProminent) }
            else { content.buttonStyle(.glass) }
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent) }
        else { content.buttonStyle(.bordered) }
    }
}

private struct CourseZoomSource: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace)
        } else { content }
        #else
        content
        #endif
    }
}

private struct CourseZoomDestination: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String?
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *), !reduceMotion, let id {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else { content }
        #else
        content
        #endif
    }
}

private struct MotionAccessibility: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

extension View {
    func controlGlass(id: String, in namespace: Namespace.ID, interactive: Bool = true) -> some View {
        modifier(ControlGlassSurface(id: id, namespace: namespace, interactive: interactive))
    }

    func adaptiveActionStyle(prominent: Bool = false) -> some View {
        modifier(AdaptiveActionStyle(prominent: prominent))
    }

    func courseZoomSource(_ id: String, in namespace: Namespace.ID) -> some View {
        modifier(CourseZoomSource(id: id, namespace: namespace))
    }

    func courseZoomDestination(_ id: String?, in namespace: Namespace.ID) -> some View {
        modifier(CourseZoomDestination(id: id, namespace: namespace))
    }

    func respectMotionPreference() -> some View { modifier(MotionAccessibility()) }
}
