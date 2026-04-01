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
