import SwiftUI
import HiveMacCore

/// What the whole run does: nothing special (the field list and its steps), cycle the boosters, or work for one quest giver.
struct ModeRow: View {
    @EnvironmentObject var model: AppModel
    @State private var pending: String?

    private func isOn(_ b: Booster) -> Binding<Bool> {
        Binding(get: { model.profile.boosters.contains(b.rawValue) },
                set: { on in
                    model.profile.boosters.removeAll { $0 == b.rawValue }
                    if on { model.profile.boosters.append(b.rawValue) }
                })
    }

    private func timerText(_ giver: String) -> String {
        let key = giver + " quest"
        let left = model.mobTimers.remaining(key, now: Date().timeIntervalSince1970)
        return MobTimers.respawn[key] == 0 ? "no cooldown" : MobTimers.describe(remaining: left, timed: true)
    }

    private var modeBinding: Binding<String> {
        Binding(get: { model.profile.mode },
                set: { new in
                    guard new != model.profile.mode else { return }
                    let loss = model.profile.lossOnEntering(new)
                    if loss.fields + loss.steps > 0 { pending = new } else { model.profile.enterMode(new) }
                })
    }

    private var hasBlessingPicture: Bool {
        _ = model.settingsVersion
        return FileManager.default.fileExists(atPath: model.dirs.templates.appendingPathComponent("balloon_blessing.png").path)
    }

    private var confirmText: String {
        guard let new = pending else { return "" }
        let l = model.profile.lossOnEntering(new)
        var parts: [String] = []
        if l.fields > 0 { parts.append("\(l.fields) other field\(l.fields == 1 ? "" : "s")") }
        if l.steps > 0 { parts.append("\(l.steps) step\(l.steps == 1 ? "" : "s")") }
        let keep = model.profile.fields.first.map { $0.name.capitalized } ?? "the first field"
        return "This keeps \(keep) and removes \(parts.joined(separator: " and "))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            HStack(spacing: Theme.s3) {
                Text("Mode").font(Theme.body).foregroundStyle(Theme.resin).frame(width: 80, alignment: .leading)
                Choice(options: [("none", "None"), ("booster", "Booster mode"), ("quests", "Quests")],
                       selection: modeBinding, width: 150).disabled(model.running)
            }
            switch model.profile.mode {
            case "booster":
                HStack(spacing: Theme.s4) {
                    ForEach(Booster.allCases, id: \.rawValue) { b in
                        Toggle(b.title, isOn: isOn(b)).toggleStyle(.checkbox).font(Theme.body).disabled(model.running)
                    }
                    Spacer()
                }
                modeOptions
            case "quests":
                HStack(spacing: Theme.s3) {
                    Text("Quest giver").font(Theme.body).foregroundStyle(Theme.resin).frame(width: 80, alignment: .leading)
                    Choice(options: QuestGivers.all.map { ($0, $0.capitalized) }, selection: $model.profile.questGiver, width: 150)
                        .disabled(model.running)
                    Text(timerText(model.profile.questGiver)).font(Theme.caption).foregroundStyle(Theme.dust)
                    Spacer()
                }
                modeOptions
            default:
                AutoBoostRow()
            }
        }
        .confirmationDialog("Switch to \(pending == "quests" ? "Quests" : "Booster mode")?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Switch", role: .destructive) { if let p = pending { model.profile.enterMode(p) }; pending = nil }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { Text(confirmText) }
    }

    private var modeOptions: some View {
        HStack(spacing: Theme.s4) {
            Toggle("Wealth clock", isOn: $model.profile.modeClock).toggleStyle(.checkbox).font(Theme.body).disabled(model.running)
            Toggle("Keep balloon blessing", isOn: $model.profile.keepBlessing).toggleStyle(.checkbox).font(Theme.body)
                .disabled(model.running || !hasBlessingPicture)
            if !hasBlessingPicture {
                Text("Take the Balloon blessing picture in Settings first").font(Theme.caption).foregroundStyle(Theme.dust)
            }
            Spacer()
        }
    }
}
