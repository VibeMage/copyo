import PasterCore
import SwiftUI

/// 设置（设计 04）。桩：三个开关 + 历史上限，完整分组、说明页、系统设置跳转由设置页代理补。
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model

    @AppStorage(IOSSettings.Key.cloudSyncEnabled, store: IOSSettings.defaults)
    private var cloudSyncEnabled = true
    @AppStorage(IOSSettings.Key.autoReadOnForeground, store: IOSSettings.defaults)
    private var autoReadOnForeground = true
    @AppStorage(IOSSettings.Key.historyLimit, store: IOSSettings.defaults)
    private var historyLimit = 500

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "iCloud Sync"), isOn: $cloudSyncEnabled)
                LabeledContent(String(localized: "Status")) {
                    Text(statusText).foregroundStyle(PasterTheme.labelSecondary)
                }
            } footer: {
                Text(String(localized: "Changing sync takes effect after you reopen Paster."))
            }

            Section {
                Toggle(String(localized: "Read clipboard when opening Paster"), isOn: $autoReadOnForeground)
            } footer: {
                Text(String(localized: "Set “Paste from Other Apps” to Allow in iOS Settings so Paster can save without a prompt."))
            }

            Section {
                Picker(String(localized: "History Limit"), selection: $historyLimit) {
                    ForEach(IOSSettings.historyLimitOptions, id: \.self) { limit in
                        Text(limit == 0 ? String(localized: "Unlimited") : "\(limit)").tag(limit)
                    }
                }
            }
        }
        .navigationTitle(PasterTab.settings.title)
        .onChange(of: historyLimit) { _, limit in
            model.applyHistoryLimit(limit)
        }
    }

    private var statusText: String {
        switch model.syncStatus.status {
        case .synced: String(localized: "Synced")
        case .syncing: String(localized: "Syncing…")
        case .off(let reason): reason.message
        }
    }
}
