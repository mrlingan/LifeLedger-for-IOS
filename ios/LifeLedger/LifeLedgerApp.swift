import SwiftUI

@main
struct LifeLedgerApp: App {
    @StateObject private var store = LedgerStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .environment(\.locale, store.locale)
                .preferredColorScheme(store.data.preferences.theme == "dark" ? .dark : store.data.preferences.theme == "light" ? .light : nil)
        }
    }
}
