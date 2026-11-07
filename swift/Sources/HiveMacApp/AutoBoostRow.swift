import SwiftUI
import HiveMacCore

/// Auto field boost: roll Field Dice or use Glitter from the hotbar when a field is not boosted yet.
struct AutoBoostRow: View {
    @EnvironmentObject var model: AppModel
    private let slots = [0, 2, 3, 4, 5, 6, 7]

    private func slotPicker(_ title: String, _ value: Binding<Int>) -> some View {
        HStack(spacing: Theme.s2) {
            Text(title).font(Theme.caption).foregroundStyle(Theme.dust)
            Picker("", selection: value) {
                ForEach(slots, id: \.self) { Text($0 == 0 ? "None" : "Slot \($0)").tag($0) }
            }.labelsHidden().frame(width: 84).disabled(model.running)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            HStack(spacing: Theme.s4) {
                Toggle("Auto field boost", isOn: $model.profile.autoBoost.enabled).toggleStyle(.checkbox).font(Theme.body)
                    .disabled(model.running)
                if model.profile.autoBoost.enabled {
                    slotPicker("Dice", $model.profile.autoBoost.diceSlot)
                    slotPicker("Glitter", $model.profile.autoBoost.glitterSlot)
                }
                Spacer()
            }
            if model.profile.autoBoost.enabled {
                Text("Uses your dice and glitter (hotbar slots 2 to 7) when a field is not boosted.")
                    .font(Theme.caption).foregroundStyle(Theme.dust).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
