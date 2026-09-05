import PasterCore
import SwiftData
import SwiftUI

/// iPad 侧栏（设计 09）。桩：历史 / 分类 / Pinboard / 设置四段，配色与计数由 iPad 代理补。
struct SidebarView: View {
    @Binding var selection: SidebarSelection?

    @Query(sort: \Pinboard.sortIndex) private var boards: [Pinboard]

    var body: some View {
        List(selection: $selection) {
            Section {
                Label(String(localized: "History"), systemImage: PasterTab.history.symbol)
                    .tag(SidebarSelection.history(nil))
                ForEach(KindPresentation.regularFilters, id: \.self) { kind in
                    Label(KindPresentation.label(kind), systemImage: KindPresentation.symbol(kind))
                        .tag(SidebarSelection.history(kind))
                }
            }

            Section(PasterTab.pinboard.title) {
                ForEach(boards) { board in
                    Label(board.name, systemImage: board.iconName ?? "pin.fill")
                        .tag(SidebarSelection.pinboard(board.persistentModelID))
                }
            }

            Section {
                Label(PasterTab.settings.title, systemImage: PasterTab.settings.symbol)
                    .tag(SidebarSelection.settings)
            }
        }
        .navigationTitle("Paster")
    }
}
