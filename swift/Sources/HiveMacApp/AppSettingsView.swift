import SwiftUI
import AppKit
import HiveMacCore
import HiveMacPlatform

/// Permissions and the stop key: the two things every user may need to touch.
struct EssentialAppSettings: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Permissions")
            if model.permissions.allGranted {
                HStack(spacing: Theme.s3) {
                    HexDot(color: Theme.leaf); Text("Screen Recording, Accessibility and Input Monitoring are on").font(Theme.body).foregroundStyle(Theme.wax)
                    Spacer()
                }.frame(minHeight: Theme.rowHeight)
            } else {
                PermissionRow(title: "Screen Recording", ok: model.permissions.screenRecording,
                              why: "Lets HiveMac read the backpack and health bars.", pane: .screenRecording)
                PermissionRow(title: "Accessibility", ok: model.permissions.accessibility,
                              why: "Lets HiveMac press keys.", pane: .accessibility)
                HStack(spacing: Theme.s3) {
                    Button("Check again") { model.refreshPermissions() }.buttonStyle(QuietButtonStyle())
                    Text("After turning one on, quit and reopen HiveMac.").font(Theme.caption).foregroundStyle(Theme.dust)
                }.padding(.top, Theme.s2)
            }

            if let msg = model.stopKeyMessage { Text(msg).font(Theme.caption).foregroundStyle(Theme.ember) }
        }
    }
}

/// Everything else, folded away: phone remote, updates, data, recording walks, pictures.
struct MoreAppSettings: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var updates: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow(label: "Phone remote") {
                Toggle("Control from a phone", isOn: Binding(get: { model.remoteOn }, set: { model.setRemote($0) })).toggleStyle(.checkbox)
            }
            if model.remoteOn {
                HStack(spacing: Theme.s2) {
                    Text(model.remoteURL).font(Theme.caption).foregroundStyle(Theme.resin).lineLimit(1).truncationMode(.middle)
                    Button("Copy link") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.remoteURL, forType: .string)
                    }.buttonStyle(QuietButtonStyle())
                }
                Text("Same Wi-Fi or Tailscale. Anyone with this link can start and stop the macro.").font(Theme.caption).foregroundStyle(Theme.dust)
            }
            if let m = model.remoteMessage { Text(m).font(Theme.caption).foregroundStyle(Theme.ember) }
            UpdateRow(checker: updates)
            SettingRow(label: "Data folder") {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.dirs.data]) }.buttonStyle(QuietButtonStyle())
            }
            RecordWalkSection()
            PicturesSection()
        }
    }
}
