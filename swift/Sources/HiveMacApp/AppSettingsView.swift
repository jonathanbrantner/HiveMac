import SwiftUI
import AppKit
import HiveMacCore
import HiveMacPlatform

/// Permissions and the stop key: the two things every user may need to touch.
struct EssentialAppSettings: View {
    @EnvironmentObject var model: AppModel
    /// The status was only read at launch and on Start, so it could show an old answer. Look again while this is on screen.
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Permissions")
            PermissionRow(title: "Screen Recording", ok: model.permissions.screenRecording,
                          why: "Lets HiveMac read the backpack and health bars.", pane: .screenRecording)
            PermissionRow(title: "Accessibility", ok: model.permissions.accessibility,
                          why: "Lets HiveMac press keys.", pane: .accessibility)
            PermissionRow(title: "Input Monitoring", ok: Permissions.inputMonitoring,
                          why: "Only for recording walks. Playing a run does not need it.", pane: .inputMonitoring)
            HStack(spacing: Theme.s3) {
                Button("Check again") { model.refreshPermissions() }.buttonStyle(QuietButtonStyle())
                if !model.permissions.allGranted {
                    Text("After turning one on, quit and reopen HiveMac.").font(Theme.caption).foregroundStyle(Theme.dust)
                }
            }.padding(.top, Theme.s2)

            if let msg = model.stopKeyMessage { Text(msg).font(Theme.caption).foregroundStyle(Theme.ember) }
        }
        .onAppear { model.refreshPermissions() }
        .onReceive(tick) { _ in model.refreshPermissions() }
    }
}

/// The app itself, opened from the gear: permissions, stop key, phone remote, updates, log and snapshots, data folder.
/// The macro's own settings (Roblox, hive, fields, walking, pictures) are in the Settings tab.
struct AppSettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var updates: UpdateChecker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("App settings").font(Theme.serif(20, .semibold)).foregroundStyle(Theme.wax)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(HoneyButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(Theme.s6)
            Divider().overlay(Theme.grain)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EssentialAppSettings()
                    SectionTitle("Stop key")
                    SettingRow(label: "Stop everything") { StopKeyField() }

                    SectionTitle("Phone remote")
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

                    SectionTitle("Updates")
                    UpdateRow(checker: updates)

                    SectionTitle("Files")
                    SettingRow(label: "Log file") {
                        Choice(options: [("capped", "Newest 2 MB"), ("all", "Keep everything"), ("off", "Off")],
                               selection: Binding(get: { _ = model.settingsVersion; return model.store.string("app.log_mode", "capped") }, set: { model.set("app.log_mode", $0) }), width: 150)
                    }
                    SettingRow(label: "Auto snapshots") {
                        Choice(options: [("keep20", "Newest 20"), ("all", "Keep all"), ("off", "Off")],
                               selection: Binding(get: { _ = model.settingsVersion; return model.store.string("app.snapshots", model.store.bool("app.auto_snapshots", true) ? "keep20" : "off") }, set: { model.set("app.snapshots", $0) }), width: 150)
                    }
                    SettingRow(label: "Data folder") {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.dirs.data]) }.buttonStyle(QuietButtonStyle())
                    }
                    SettingRow(label: "Permissions") {
                        Button("Reset and ask again") {
                            Permissions.reset(); Permissions.request(.screenRecording); Permissions.request(.accessibility)
                            model.refreshPermissions()
                        }.buttonStyle(QuietButtonStyle()).help("For when a permission shows as on but does nothing. Then quit and reopen HiveMac.")
                    }
                }
                .padding(.horizontal, Theme.s6).padding(.bottom, Theme.s6)
            }
        }
        .frame(minWidth: 520, minHeight: 560)
        .background(Theme.shed)
    }
}

/// Recording walks and picking pictures ship ready in HiveMac. Changing them can break reading the screen or walking,
/// so they sit behind a fold marked as a danger zone.
struct MoreAppSettings: View {
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.snappy(duration: 0.15)) { open.toggle() } } label: {
                HStack(spacing: Theme.s2) {
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).frame(width: 10)
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                    Text("Danger zone").font(Theme.bodyStrong)
                    Text("not recommended to change").font(Theme.caption)
                    Spacer()
                }
                .foregroundStyle(Theme.ember)
            }
            .buttonStyle(.plain).padding(.vertical, Theme.s2)
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Walks and pictures come with HiveMac and work for most people. Only change them if something does not work, and take a snapshot first.")
                        .font(Theme.caption).foregroundStyle(Theme.dust).fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Theme.s2)
                    RecordWalkSection()
                    PicturesSection()
                }
                .padding(Theme.s4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.ember.opacity(0.6), lineWidth: 1))
            }
        }
        .padding(.top, Theme.s4)
    }
}
