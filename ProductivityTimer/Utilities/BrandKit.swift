import SwiftUI

// MARK: - TaskMind Logo

struct TaskMindLogo: View {
    var fontSize: CGFloat = 34

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
            .background(color, in: RoundedRectangle(cornerRadius: cornerRadius))
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
            .background(color, in: Circle())
            .compositingGroup()
            .shadow(color: color.darkened(), radius: 0, x: 0, y: pressed ? 0 : ledge)
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
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
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 20, x: 0, y: 8)
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
            .foregroundStyle(isSelected ? tabGreen : Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? tabGreen.opacity(0.14) : Color.clear)
            )
            .compositingGroup()
            .shadow(
                color: isSelected ? .clear : Color.black.opacity(0.4),
                radius: 0, x: 0, y: isSelected ? 0 : ledge
            )
            .offset(y: isSelected ? ledge : 0)
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
