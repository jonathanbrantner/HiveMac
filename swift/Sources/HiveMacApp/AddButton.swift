import SwiftUI
import HiveMacCore

/// Add: every field is one click in a grid (no pop-out menu), the extra steps are below it.
struct AddButton: View {
    @EnvironmentObject var model: AppModel
    @State private var open = false

    private let columns = Array(repeating: GridItem(.fixed(104), spacing: Theme.s2), count: 3)

    var body: some View {
        Button("Add") { open.toggle() }
            .buttonStyle(QuietButtonStyle())
            .popover(isPresented: $open, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: Theme.s3) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.s2) {
                        ForEach(FieldDefaults.order, id: \.self) { name in
                            let fits = FieldColors.table[name] == model.hive.color && model.hive.color != "mixed"
                            Button(name.capitalized) {
                                var f = FieldConfig(name: name)
                                model.applyFieldDefaults(to: &f)
                                model.profile.fields.append(f)
                            }
                            .buttonStyle(QuietButtonStyle(tint: fits ? Theme.honeyText : Theme.wax))
                            .frame(width: 104)
                        }
                    }
                    Divider().overlay(Theme.grain)
                    HStack(spacing: Theme.s2) {
                        step("Bug run", "bug_run"); step("Clock and dispensers", "pickups")
                        step("Memory match", "memory"); step("Planters", "planters"); step("Quests", "quests")
                    }
                }
                .padding(Theme.s4).background(Theme.shed)
            }
    }

    private func step(_ title: String, _ kind: String) -> some View {
        Button(title) { model.profile.extras.append(ExtraStep(kind: kind)); open = false }.buttonStyle(QuietButtonStyle())
    }
}
