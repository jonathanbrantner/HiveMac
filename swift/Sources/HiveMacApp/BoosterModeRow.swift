import SwiftUI
import HiveMacCore

/// Booster mode: cycle through the field boosters and gather where the boost lands, until it ends.
struct BoosterModeRow: View {
    @EnvironmentObject var model: AppModel

    private func isOn(_ b: Booster) -> Binding<Bool> {
        Binding(get: { model.profile.boosters.contains(b.rawValue) },
                set: { on in
                    model.profile.boosters.removeAll { $0 == b.rawValue }
                    if on { model.profile.boosters.append(b.rawValue) }
                })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            HStack(spacing: Theme.s4) {
                Toggle("Booster mode", isOn: $model.profile.boosterMode).toggleStyle(.checkbox).font(Theme.body)
                    .disabled(model.running)
                if model.profile.boosterMode {
                    ForEach(Booster.allCases, id: \.rawValue) { b in
                        Toggle(b.title, isOn: isOn(b)).toggleStyle(.checkbox).font(Theme.caption).disabled(model.running)
                    }
                }
                Spacer()
            }
            if model.profile.boosterMode {
                Text("Gathers in whichever field a ready booster boosts, until the boost ends.")
                    .font(Theme.caption).foregroundStyle(Theme.dust).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
