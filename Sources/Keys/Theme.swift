import AppKit
import SwiftUI

/// The app's visual identity, shared with Mara AI: near-black and off-white, the system font,
/// pill-shaped controls and a dot-matrix mark (braces here, "M" there). The contrast color is
/// the text color itself: off-white on the dark look, near-black on the light one.
enum Theme {
    /// The background: near-black in dark mode, off-white in light mode.
    static let ink = adaptive(dark: 0x0D0D0D, light: 0xFAFAFA)
    /// The text, and the color that stands out on the background.
    static let paper = adaptive(dark: 0xFAFAFA, light: 0x0D0D0D)
    /// Selected and prominent controls: the text color, so white on dark and black on light.
    static let accent = paper
    static let muted = paper.opacity(0.6)
    /// Cards and fields on the ink background.
    static let surface = paper.opacity(0.05)
    static let hairline = paper.opacity(0.1)
    /// Panels floating over the window, a step apart from it.
    static let panel = adaptive(dark: 0x171718, light: 0xFFFFFF)
    /// The shadow under a floating panel, lighter where the background is light.
    static let shadow = Color(nsColor: NSColor(name: nil) { appearance in
        NSColor.black.withAlphaComponent(isDark(appearance) ? 0.45 : 0.14)
    })

    /// A color that follows the appearance the view is drawn in.
    static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            rgb(isDark(appearance) ? dark : light)
        })
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua, .vibrantDark, .vibrantLight]).map { [.darkAqua, .vibrantDark].contains($0) } ?? true
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Titles in the system font (San Francisco), like the rest of the app.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size * 0.86, weight: .semibold)
    }

    /// The 5 × 5 braces, "{ }": the variables and code a project keeps. "o" is the accent dot,
    /// in the middle.
    static let glyph = [".x.x.", "x...x", "x.o.x", "x...x", ".x.x."]

    /// The braces as a template image for the menu bar.
    static let menuBarIcon: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let step: CGFloat = 3.5
            let dot: CGFloat = 2.5
            let origin = side / 2 - step * 2
            NSColor.black.setFill()
            for (row, line) in glyph.enumerated() {
                for (column, mark) in line.enumerated() where mark != "." {
                    let x = origin + CGFloat(column) * step - dot / 2
                    let y = origin + CGFloat(row) * step - dot / 2
                    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dot, height: dot)).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

extension View {
    /// The app's look on a window or panel: ink behind, paper text and controls, in the
    /// appearance picked in Settings (the system's by default).
    func keysSurface() -> some View {
        background(Theme.ink)
            .foregroundStyle(Theme.paper)
            .tint(Theme.accent)
    }
}

/// The icon's dot-matrix braces. The dots pop in from left to right when
/// `shown` turns on.
struct DotMark: View {
    let shown: Bool
    var dot: CGFloat = 8.5
    var spacing: CGFloat = 4.5
    private let dots = Theme.glyph.map(Array.init)

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(dots.indices, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(dots[row].indices, id: \.self) { column in
                        Circle()
                            .fill(dots[row][column] == "o" ? Theme.accent : Theme.paper)
                            .frame(width: dot, height: dot)
                            .opacity(dots[row][column] != "." && shown ? 1 : 0)
                            .scaleEffect(shown ? 1 : 0.3)
                            .animation(.spring(response: 0.42, dampingFraction: 0.62).delay(Double(column) * 0.05 + Double(row) * 0.02), value: shown)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(appName)
    }
}

/// Primary button: a pill in the text color with the background's color for its label; `prominent: false` is the quiet version.
/// `large` is the lock screen's size.
struct PillButtonStyle: ButtonStyle {
    var prominent = true
    var large = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 13.5 : 12, weight: large ? .semibold : .medium))
            .padding(.horizontal, large ? 20 : 12)
            .padding(.vertical, large ? 8 : 5)
            .foregroundStyle(prominent ? Theme.ink : Theme.paper)
            .background(prominent ? Theme.accent : Theme.paper.opacity(0.12), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

/// A round icon button that lights up under the pointer, as in Mara's captions window.
struct IconButton: View {
    let symbol: String
    let help: String
    var color: Color = Theme.paper.opacity(0.7)
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24, height: 24)
                .background(Theme.paper.opacity(hovering ? 0.12 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Copies `value` and turns into a check mark for a moment. `symbol` tells side by side
/// copies apart (a username and its password, say).
struct CopyButton: View {
    let value: String
    var secret = false
    var symbol = "doc.on.doc"
    var help: String = localized("Copiar")
    @State private var copied = false

    var body: some View {
        IconButton(symbol: copied ? "checkmark" : symbol, help: help, color: copied ? Theme.accent : Theme.paper.opacity(0.7)) {
            Clipboard.copy(value, secret: secret)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                copied = false
            }
        }
        .disabled(value.isEmpty)
    }
}

/// A titled group on the ink background, with an optional hint below.
struct Card<Content: View>: View {
    let title: String?
    let hint: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            content
            if let hint {
                Text(hint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Icon tabs in a capsule: only the active one shows its name, as a pill in the contrast color, as in
/// Mara's Settings.
struct CapsuleTabs<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    let symbol: (Tab) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { item in
                let active = selection == item
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = item }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: symbol(item))
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16, height: 16)
                        if active {
                            Text(title(item))
                                .font(.system(size: 12, weight: .semibold))
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(active ? Theme.ink : Theme.paper.opacity(0.75))
                    .padding(.horizontal, active ? 11 : 8)
                    .padding(.vertical, 5)
                    .background(active ? Theme.accent : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(title(item))
                .accessibilityLabel(title(item))
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.paper.opacity(0.07), in: Capsule())
    }
}

/// A small capsule with a label, like Mara's summary kind.
struct Badge: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.15), in: Capsule())
    }
}

/// The project's symbol in its color, on a quiet tile of the same color.
struct ProjectBadge: View {
    let project: Project
    var size: CGFloat = 22

    var body: some View {
        let color = Theme.color(project.tint)
        Image(systemName: project.symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

extension Theme {
    /// A project's color, picked in its header. All are soft, so none shouts.
    static func color(_ tint: Project.Tint) -> Color {
        // Pastels on the dark look; deeper versions of the same hues on the light one, so the
        // icons keep their contrast.
        switch tint {
        case .lavender: adaptive(dark: 0xB8A4F8, light: 0x7558D8)
        case .sky: adaptive(dark: 0x8CC4F7, light: 0x2A7FCC)
        case .mint: adaptive(dark: 0x86DBBC, light: 0x1D9468)
        case .lime: adaptive(dark: 0xC2DE80, light: 0x5F8A16)
        case .amber: adaptive(dark: 0xF2C66D, light: 0xB07A0C)
        case .coral: adaptive(dark: 0xF49A86, light: 0xD0533A)
        case .rose: adaptive(dark: 0xF0A2C8, light: 0xC84784)
        case .slate: adaptive(dark: 0xAEB5C0, light: 0x5F6876)
        }
    }
}

/// A text field drawn as a quiet rounded surface instead of a bordered box.
struct FieldStyle: TextFieldStyle {
    var monospaced = false
    /// Room kept on the right for a button laid inside the field.
    var trailingRoom: CGFloat = 0

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: monospaced ? .monospaced : .default))
            .padding(.leading, 8)
            .padding(.trailing, 8 + trailingRoom)
            .padding(.vertical, 6)
            .background(Theme.paper.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

extension TextFieldStyle where Self == FieldStyle {
    static var field: FieldStyle { FieldStyle() }
    static var code: FieldStyle { FieldStyle(monospaced: true) }
    static func code(trailingRoom: CGFloat) -> FieldStyle { FieldStyle(monospaced: true, trailingRoom: trailingRoom) }
}

/// The sidebar button's icon: a rounded square with a short bar along its left side.
struct SidebarIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .strokeBorder(lineWidth: 1.5)
            .frame(width: 17, height: 15)
            .overlay(alignment: .leading) {
                Capsule()
                    .frame(width: 1.8, height: 6.5)
                    .padding(.leading, 4.5)
            }
            .accessibilityHidden(true)
    }
}

/// The sidebar button: the icon, and a rounded rectangle behind it under the pointer, the shape of
/// the system's own title bar buttons.
struct SidebarButtonLabel: View {
    @State private var hovering = false

    var body: some View {
        SidebarIcon()
            .foregroundStyle(Theme.paper.opacity(hovering ? 0.95 : 0.7))
            .frame(width: 30, height: 26)
            .background(Theme.paper.opacity(hovering ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
