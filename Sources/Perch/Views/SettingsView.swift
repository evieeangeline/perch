import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var taskStore: TaskStore

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Perch at login", isOn: $settings.launchAtLogin)
                Toggle("Start expanded", isOn: $settings.startExpanded)
            }

            Section("Appearance") {
                Picker("When not hovered", selection: $settings.glanceTranslucent) {
                    Text("Translucent").tag(true)
                    Text("Solid").tag(false)
                }
                .pickerStyle(.segmented)

                Picker("Show Perchie", selection: $settings.perchieStyle) {
                    ForEach(PerchieStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                if settings.glanceTranslucent {
                    LabeledContent("Tint") {
                        HStack {
                            Slider(value: $settings.glanceOpacity, in: 0.2...0.9)
                            Text("\(Int((settings.glanceOpacity * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }

            Section("Completed tasks") {
                Stepper(
                    "Show \(settings.recentCompletedCount) recent completed tasks",
                    value: $settings.recentCompletedCount,
                    in: 3...15
                )
                Button("Clear completed history", role: .destructive) {
                    taskStore.clearCompletedHistory()
                }
            }

            Section {
                Button("Quit Perch") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .formStyle(.grouped)
    }
}
