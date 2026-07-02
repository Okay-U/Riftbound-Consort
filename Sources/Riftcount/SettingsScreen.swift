import SwiftUI

/// Settings subset for Wave 1: haptics + battery saver toggles, version info.
struct SettingsScreen: View {
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("batterySaver") var batterySaver: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Haptic feedback", isOn: $hapticsEnabled)
                Toggle("Battery saver", isOn: $batterySaver)
            }

            Section("About") {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(version) (\(build))")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Riftcount for Android — unofficial companion, not affiliated with Riot Games or UVS Games.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
