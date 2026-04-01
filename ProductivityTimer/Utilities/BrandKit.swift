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
// Technique: shadow(radius: 0) renders a pixel-perfect copy of the rounded
// rect directly below the face at `ledge` pts offset — creating a solid
// extrusion without any ZStack gymnastics.  On press the face offsets down
// by `ledge` and the shadow collapses to y:0 (hidden behind the face).

struct TactileButtonStyle: ButtonStyle {
    var color: Color = Color(hex: "#00bf63")
    var cornerRadius: CGFloat = 14
    private let ledge: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: cornerRadius))
            .compositingGroup()
            .shadow(color: color.brightness(-0.28), radius: 0, x: 0, y: pressed ? 0 : ledge)
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
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(color, lineWidth: 2)
                    )
            }
            .compositingGroup()
            .shadow(color: color, radius: 0, x: 0, y: pressed ? 0 : ledge)
            .offset(y: pressed ? ledge : 0)
            .padding(.bottom, ledge)
            .animation(.easeOut(duration: 0.1), value: pressed)
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
}

// MARK: - Card Style

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
