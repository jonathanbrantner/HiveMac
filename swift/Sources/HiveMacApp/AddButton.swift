import SwiftUI
import HiveMacCore

/// Add: every field is one click in a grid (no pop-out menu), the extra steps are below it.
struct AddButton: View {
    @EnvironmentObject var model: AppModel
    @State private var open = false

    /// Fields by flower colour, the same groups the field boosters use (Red HQ, Blue HQ, Mountain Top for white).
    private static let groups: [(title: String, color: Color, fields: [String])] = [
        ("White", Color(red: 0.93, green: 0.91, blue: 0.84), ["sunflower", "dandelion", "clover", "spider", "pineapple", "cactus", "pumpkin", "coconut", "mountain top"]),
        ("Red", Color(red: 0.94, green: 0.42, blue: 0.36), ["mushroom", "strawberry", "rose", "pepper"]),
        ("Blue", Color(red: 0.45, green: 0.66, blue: 0.96), ["blue flower", "bamboo", "pine tree", "stump"]),
    ]

    private let columns = Array(repeating: GridItem(.fixed(104), spacing: Theme.s2), count: 3)

    var body: some View {
        Button("Add") { open.toggle() }
            .buttonStyle(QuietButtonStyle())
            .popover(isPresented: $open, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: Theme.s3) {
                    ForEach(Self.groups, id: \.title) { g in
                        VStack(alignment: .leading, spacing: Theme.s1) {
                            HStack(spacing: 6) {
                                Circle().fill(g.color).frame(width: 9, height: 9)
                                Text(g.title).font(Theme.caption).foregroundStyle(Theme.resin)
                            }
                            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.s2) {
                                ForEach(g.fields, id: \.self) { name in
                                    Button(name.capitalized) {
                                        var f = FieldConfig(name: name)
                                        model.applyFieldDefaults(to: &f)
                                        model.profile.fields.append(f)
                                    }
                                    .buttonStyle(QuietButtonStyle(tint: g.color))
                                    .frame(width: 104)
                                }
                            }
                        }
                    }
                    Divider().overlay(Theme.grain)
                    HStack(spacing: Theme.s2) {
                        step("Bug run", "bug_run"); step("Clock and dispensers", "pickups")
                        step("Memory match", "memory"); step("Planters", "planters")
                    }
                }
                .padding(Theme.s4).background(Theme.shed)
            }
    }

    private func step(_ title: String, _ kind: String) -> some View {
        Button(title) { model.profile.extras.append(ExtraStep(kind: kind)); open = false }.buttonStyle(QuietButtonStyle())
    }
}
