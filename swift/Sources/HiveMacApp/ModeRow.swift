import SwiftUI
import HiveMacCore

/// What the whole run does: farm the field list, cycle the boosters, or work for one quest giver.
struct ModeRow: View {
    @EnvironmentObject var model: AppModel

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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            HStack(spacing: Theme.s3) {
                Text("Mode").font(Theme.body).foregroundStyle(Theme.resin).frame(width: 80, alignment: .leading)
                Choice(options: [("fields", "Fields"), ("booster", "Booster mode"), ("quests", "Quests")],
                       selection: $model.profile.mode, width: 150).disabled(model.running)
            }
            switch model.profile.mode {
            case "booster":
                HStack(spacing: Theme.s4) {
                    ForEach(Booster.allCases, id: \.rawValue) { b in
                        Toggle(b.title, isOn: isOn(b)).toggleStyle(.checkbox).font(Theme.body).disabled(model.running)
                    }
                    Spacer()
                }
            case "quests":
                HStack(spacing: Theme.s3) {
                    Text("Quest giver").font(Theme.body).foregroundStyle(Theme.resin).frame(width: 80, alignment: .leading)
                    Choice(options: QuestGivers.all.map { ($0, $0.capitalized) }, selection: $model.profile.questGiver, width: 150)
                        .disabled(model.running)
                    Text(timerText(model.profile.questGiver)).font(Theme.caption).foregroundStyle(Theme.dust)
                    Spacer()
                }
            default:
                AutoBoostRow()
            }
        }
    }
}
