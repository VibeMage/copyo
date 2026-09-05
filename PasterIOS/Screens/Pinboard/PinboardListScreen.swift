import PasterCore
import SwiftData
import SwiftUI

/// Pinboard 列表（设计 03）。桩：列出全部板与条目数。
struct PinboardListScreen: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Pinboard.sortIndex) private var boards: [Pinboard]

    var body: some View {
        List {
            ForEach(boards) { board in
                NavigationLink {
                    PinboardContentScreen(board: board)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: board.iconName ?? "pin.fill")
                            .foregroundStyle(Color(hexString: board.colorHex ?? "") ?? PasterTheme.accent)
                            .frame(width: 24)
                        Text(board.name)
                        Spacer()
                        Text("\(board.items?.count ?? 0)")
                            .foregroundStyle(PasterTheme.labelSecondary)
                    }
                }
            }
        }
        .overlay {
            if boards.isEmpty {
                EmptyState(symbol: "pin",
                           title: String(localized: "No pinboards"),
                           message: String(localized: "Pin a clip to keep it out of the history limit."))
            }
        }
        .navigationTitle(PasterTab.pinboard.title)
    }
}
