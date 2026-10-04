import SwiftUI

extension Color {
    static let ledgerAccent = Color.accentColor
    static func category(_ name: String) -> Color {
        let colors: [Color] = [.blue, .cyan, .green, .purple, .pink, .orange, .mint, .indigo, .teal, .brown, .red, .yellow, .green, .orange]
        return colors[(Catalog.categories.firstIndex(of: name) ?? 0) % colors.count]
    }
}
extension Rarity {
    var color: Color { [.brown, .gray, .orange, .cyan, .purple][rawValue] }
}
struct LedgerBackground: View {
    @EnvironmentObject var store: LedgerStore
    var body: some View { Color(uiColor: .systemGroupedBackground).ignoresSafeArea() }
}
struct SectionTitle: View {
    let title: String
    var body: some View { Text(title).font(.headline).accessibilityAddTraits(.isHeader) }
}
struct IconTile: View {
    @EnvironmentObject var store: LedgerStore
    let icon: String
    var size: CGFloat = 44
    var color: Color = .accentColor
    var body: some View {
        Group {
            if icon.hasPrefix("media/"), let image = UIImage(contentsOfFile: store.mediaURL(icon).path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else { Text(icon.isEmpty ? "🏆" : icon).font(.system(size: size * 0.6)) }
        }.frame(width: size, height: size)
    }
}
struct Avatar: View {
    @EnvironmentObject var store: LedgerStore
    var size: CGFloat = 52
    var body: some View { IconTile(icon: store.data.profile.avatar, size: size).clipShape(Circle()) }
}
struct Pill: View {
    var text: String
    var color: Color = .accentColor
    var body: some View { Text(text).font(.caption).foregroundStyle(color) }
}
struct Metric: View {
    var value: String
    var label: String
    var body: some View {
        LabeledContent(label) { Text(value).monospacedDigit() }
    }
}
struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        }.buttonStyle(.borderedProminent).controlSize(.large)
    }
}
struct EmptyState: View {
    var symbol = "sparkles"
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }
}
struct SettingsLink<Destination: View>: View {
    let title: String
    let symbol: String
    let destination: Destination
    init(_ title: String, symbol: String, @ViewBuilder destination: () -> Destination) {
        self.title = title; self.symbol = symbol; self.destination = destination()
    }
    var body: some View { NavigationLink { destination } label: { Label(title, systemImage: symbol) } }
}
struct RecordToolbar: ToolbarContent {
    @EnvironmentObject var store: LedgerStore
    @Binding var adding: Bool
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(store.t("记录成就", "Record achievement"), systemImage: "plus") { adding = true }
                .accessibilityIdentifier("addAchievement")
        }
    }
}

struct LedgerListBackground: ViewModifier {
    @EnvironmentObject var store: LedgerStore
    func body(content: Content) -> some View {
        if let path = store.data.preferences.backgroundImage,
           let image = UIImage(contentsOfFile: store.mediaURL(path).path) {
            content.scrollContentBackground(.hidden).background {
                GeometryReader { proxy in
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        .opacity(store.data.preferences.backgroundOpacity)
                }.ignoresSafeArea()
            }
        } else { content }
    }
}
