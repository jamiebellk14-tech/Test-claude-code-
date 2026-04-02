import SwiftUI

// MARK: - TaskMind Logo

struct TaskMindLogo: View {
    var fontSize: CGFloat = 34

    // Standard (plain) logo — used outside the nav bar
    var body: some View {
        HStack(spacing: 0) {
            Text("Task")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.primary)
            Text("Mind")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color(hex: "#00bf63"))
        }
    }
}

// MARK: - TaskMind Logo Badge
// Tactile 3-D pill version used in the nav bar.
// Same hard-ledge extrusion technique as TactileButtonStyle:
//   face = green rounded rect; ledge = shadow(radius:0, y:ledge)
// "Task" is white on green; "Mind" is black on green for contrast.

struct TaskMindLogoBadge: View {
    var fontSize: CGFloat = 18
    private let green = Color(hex: "#00bf63")
    private let ledge: CGFloat = 4

    var body: some View {
        HStack(spacing: 0) {
            Text("Task")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
            Text("Mind")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(green)
                // Inner border gives depth to the face
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
        }
        .compositingGroup()
        // Hard-shadow ledge — zero blur = solid pixel-perfect extrusion
        .shadow(color: green.darkened(), radius: 0, x: 0, y: ledge)
        .padding(.bottom, ledge)
    }
}

// MARK: - Tactile Button Style (filled, hard-ledge 3D effect)
//
// shadow(radius:0) renders a pixel-perfect copy of the shape below the face
// at `ledge` pts offset. On press the face offsets down and shadow collapses.

struct TactileButtonStyle: ButtonStyle {
    var color: Color = Color(hex: "#00bf63")
    var cornerRadius: CGFloat = 14
    private let ledge: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(color)
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
            .compositingGroup()
            .shadow(color: color.darkened(), radius: 0, x: 0, y: pressed ? 0 : ledge)
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.easeOut(duration: 0.1), value: pressed)
    }
}

// MARK: - Tactile Outline Button Style (border variant)

struct TactileOutlineButtonStyle: ButtonStyle {
    var color: Color = Color(hex: "#00bf63")
    var cornerRadius: CGFloat = 14
    private let ledge: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.systemBackground))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(color, lineWidth: 2)
                }
            }
            .compositingGroup()
            .shadow(color: color, radius: 0, x: 0, y: pressed ? 0 : ledge)
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.easeOut(duration: 0.1), value: pressed)
    }
}

// MARK: - Tactile Send Button Style (compact circle, for chat input)

struct TactileSendButtonStyle: ButtonStyle {
    private let ledge: CGFloat = 4
    private let color = Color(hex: "#00bf63")

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                ZStack {
                    Circle().fill(color)
                    Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                }
            }
            .compositingGroup()
            .shadow(color: color.darkened(), radius: 0, x: 0, y: pressed ? 0 : ledge)
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Brand Nav Bar
//
// Fully custom navigation bar — no UIKit/NavigationStack chrome whatsoever.
// Background extends behind the status bar via .ignoresSafeArea(edges: .top).

struct BrandNavBar: View {
    enum Center {
        case logo
        case title(String)
        case custom(AnyView)
    }

    let center: Center
    var leading: AnyView?
    var trailing: AnyView?

    // Convenience initialisers
    static func logo(leading: AnyView? = nil, trailing: AnyView? = nil) -> BrandNavBar {
        BrandNavBar(center: .logo, leading: leading, trailing: trailing)
    }
    static func titled(_ title: String, leading: AnyView? = nil, trailing: AnyView? = nil) -> BrandNavBar {
        BrandNavBar(center: .title(title), leading: leading, trailing: trailing)
    }
    static func custom(_ view: some View, leading: AnyView? = nil, trailing: AnyView? = nil) -> BrandNavBar {
        BrandNavBar(center: .custom(AnyView(view)), leading: leading, trailing: trailing)
    }

    private let ledge: CGFloat = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hard-ledge shadow makes the nav bar feel like a raised physical shelf
            Color(.systemBackground)
                .ignoresSafeArea(edges: .top)
                .shadow(color: Color(.label).opacity(0.18), radius: 0, x: 0, y: ledge)

            HStack(spacing: 0) {
                Group {
                    if let leading { leading }
                    else { Color.clear }
                }
                .frame(width: 60, alignment: .leading)

                Spacer(minLength: 0)

                switch center {
                case .logo:
                    // Tactile 3-D badge replaces plain text logo
                    TaskMindLogoBadge()
                case .title(let t):
                    Text(t).font(.system(size: 17, weight: .semibold))
                case .custom(let v):
                    v
                }

                Spacer(minLength: 0)

                Group {
                    if let trailing { trailing }
                    else { Color.clear }
                }
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .padding(.bottom, 6)
        }
        .frame(height: 52)
        // No underline — clean boundary with content below
    }
}

// MARK: - Tactile Nav Button
// Sits on the green BrandNavBar. White icon, dark-green hard-shadow ledge on press.

struct TactileNavButton: View {
    let icon: String
    let action: () -> Void

    // ── Nav button shadow (edit independently) ────────────────────────────────
    var shadowColor: Color    = Color(hex: "#00bf63").darkened(by: 0.45)
    var shadowRadius: CGFloat = 4        // blur radius
    var shadowX: CGFloat      = 0
    var shadowY: CGFloat      = 3        // distance below button

    private let ledge: CGFloat = 2

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#00bf63"))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: "#00bf63").opacity(0.12))
                        // Shadow on the background circle only — avoids clipping issues
                        .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
                )
        }
        .buttonStyle(_NavLedgeStyle(ledge: ledge))
    }
}

private struct _NavLedgeStyle: ButtonStyle {
    let ledge: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - Tactile Tab Bar

private let tabGreen = Color(hex: "#00bf63")

struct TactileTabBar: View {
    @Binding var selectedTab: Int

    private struct TabItem {
        let index: Int
        let icon: String
        let label: String
    }

    private let items: [TabItem] = [
        TabItem(index: 0, icon: "timer",                       label: "Timer"),
        TabItem(index: 1, icon: "chart.bar.fill",             label: "Reports"),
        TabItem(index: 2, icon: "list.bullet.clipboard.fill", label: "Schedule"),
        TabItem(index: 3, icon: "tag.fill",                   label: "Tags"),
        TabItem(index: 4, icon: "sparkles",                   label: "TaskMind"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.index) { item in
                TactileTabItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: selectedTab == item.index
                ) {
                    guard selectedTab != item.index else { return }
                    HapticManager.heavy()
                    selectedTab = item.index
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        // Hard ledge on the shape only — same tactile style as Begin Task button
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(tabGreen)
                RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.25), lineWidth: 0)
            }
            .shadow(color: tabGreen.darkened(by: 0.55), radius: 0, x: 0, y: 6)
        }
        .padding(.bottom, 6)   // clear space for the ledge shadow to show
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct TactileTabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let ledge: CGFloat = 3

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            // Hard ledge on the background shape — collapses when pressed in (selected)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0)
                }
                .shadow(
                    color: tabGreen.darkened(by: 0.55),
                    radius: 0,
                    x: 0,
                    y: isSelected ? 0 : ledge
                )
            }
            .offset(y: isSelected ? ledge : 0)      // face sinks down to meet the ledge
            .padding(.bottom, ledge)                 // reserve space so ledge shadow is visible
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Haptic Manager

enum HapticManager {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Card Style (general padding + background wrapper)

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Card Row Style (for List rows — card background + no separator)

struct CardRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
            )
            .listRowSeparator(.hidden)
    }
}

extension View {
    func cardRow() -> some View {
        modifier(CardRowStyle())
    }
}
