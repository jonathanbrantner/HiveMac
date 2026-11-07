import SwiftUI
import HiveMacCore

struct FieldRow: View {
    @Binding var field: FieldConfig
    var key: String
    /// Names of all fields in this run, so the same field is not picked twice.
    var taken: [String] = []
    var remove: () -> Void
    @State private var open = ProcessInfo.processInfo.environment["HIVEMAC_OPEN"] != nil

    private static let locations = ["center", "upper left", "upper", "upper right", "left", "right", "lower left", "lower", "lower right"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.s2) {
                DragHandle(key: key)
                Button { open.toggle() } label: {
                    HStack(spacing: Theme.s1) {
                        Image(systemName: open ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).frame(width: 10)
                        Text(field.name.capitalized).font(Theme.body)
                            .foregroundStyle(field.enabled ? Theme.wax : Theme.dust)
                    }
                    .frame(width: 100, alignment: .leading)
                }
                .buttonStyle(.plain).help("Show every option for this field")
                TextField("", value: $field.minutes, format: .number).fieldStyle(width: 56)
                TextField("", value: $field.backpackPercent, format: .number).fieldStyle(width: 56)
                Choice(options: [("walk", "Walk back"), ("reset", "Respawn")], selection: $field.returnMethod, width: 104)
                Choice(options: [("default", "Usual"), ("walk", "Walk"), ("cannon", "Cannon")], selection: $field.travel, width: 88)
                Choice(options: Patterns.names.map { ($0, Self.pretty($0)) }, selection: $field.pattern, width: 140)
                Spacer(minLength: 0)
                Button(action: remove) { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain).foregroundStyle(Theme.ember).help("Remove this field")
            }
            .frame(height: Theme.rowHeight + 4)

            if open { more.padding(.leading, 34).padding(.bottom, Theme.s3) }
        }
    }

    private static func pretty(_ s: String) -> String { s.replacingOccurrences(of: "_", with: " ").capitalized }

    /// Changing the size scales the sprinkler distance with it, so the sprinkler stays in the same
    /// place relative to the pattern.
    private var sizeBinding: Binding<String> {
        Binding(get: { field.size }, set: { new in
            let ratio = Patterns.sizeFactor(new) / Patterns.sizeFactor(field.size)
            field.sprinklerDistance = max(1, Int((Double(field.sprinklerDistance) * ratio).rounded()))
            field.size = new
        })
    }

    /// Switching to another field gives it that field's own pattern, size and sprinkler, but keeps
    /// the minutes, backpack percent, return, travel and on/off you already set.
    private var nameBinding: Binding<String> {
        Binding(get: { field.name }, set: { new in
            guard new != field.name else { return }
            var f = FieldConfig(name: new)
            f.minutes = field.minutes; f.backpackPercent = field.backpackPercent
            f.returnMethod = field.returnMethod; f.travel = field.travel; f.enabled = field.enabled
            field = f
        })
    }

    @State private var showMore = false

    /// One setting: a name, the control, and one plain sentence about what it does.
    private func setting<Control: View>(_ name: String, _ hint: String, @ViewBuilder _ control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: Theme.s3) {
            Text(name).font(Theme.body).foregroundStyle(Theme.resin).frame(width: 150, alignment: .leading)
            control()
            Text(hint).font(Theme.caption).foregroundStyle(Theme.dust).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 30)
    }

    private var more: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            setting("Field", "Which field this row is for.") {
                Choice(options: FieldDefaults.order.filter { $0 == field.name || !taken.contains($0) }.map { ($0, $0.capitalized) },
                       selection: nameBinding, width: 120)
            }
            setting("Use this field", "Untick to skip it without deleting it.") {
                Toggle("", isOn: $field.enabled).toggleStyle(.checkbox).labelsHidden()
            }
            setting("Pattern size", "How wide the walking pattern spreads. Bigger covers more of the field.") {
                Choice(options: [("xs", "Tiny"), ("s", "Small"), ("m", "Medium"), ("l", "Large"), ("xl", "Huge")], selection: sizeBinding, width: 90)
            }
            setting("Sprinkler spot", "Where in the field the sprinkler goes.") {
                Choice(options: Self.locations.map { ($0, $0.capitalized) }, selection: $field.sprinklerLocation, width: 120)
            }

            Button { withAnimation(.snappy(duration: 0.15)) { showMore.toggle() } } label: {
                HStack(spacing: Theme.s1) {
                    Image(systemName: showMore ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).frame(width: 10)
                    Text("More").font(Theme.body)
                }.foregroundStyle(Theme.resin)
            }
            .buttonStyle(.plain).padding(.top, Theme.s2)

            if showMore {
                setting("Turn the camera", "After arriving, turn the camera this way so the pattern lines up with the field.") {
                    Choice(options: [("none", "Don't"), ("left", "Left"), ("right", "Right")], selection: $field.camera, width: 90)
                }
                setting("Camera turn steps", "How many small turns. Two turns is a quarter circle.") {
                    TextField("", value: $field.turns, format: .number).fieldStyle(width: 56)
                }
                setting("Sprinkler distance", "How far from the middle of the field the sprinkler goes.") {
                    TextField("", value: $field.sprinklerDistance, format: .number).fieldStyle(width: 56)
                }
                setting("Pattern repeats", "How many times the pattern is walked before it starts again.") {
                    TextField("", value: $field.width, format: .number).fieldStyle(width: 56)
                }
                setting("Shift lock", "Gather with shift lock on. Some patterns need it.") {
                    Toggle("", isOn: $field.shiftLock).toggleStyle(.checkbox).labelsHidden()
                }
                setting("Mirror forward and back", "Swap the pattern's forward and back. Only if it walks the wrong way in this field.") {
                    Toggle("", isOn: $field.invertFB).toggleStyle(.checkbox).labelsHidden()
                }
                setting("Mirror left and right", "Swap the pattern's left and right. Only if it walks the wrong way in this field.") {
                    Toggle("", isOn: $field.invertLR).toggleStyle(.checkbox).labelsHidden()
                }
                Button("Reset these to Natro's values") {
                    var d = FieldConfig(name: field.name)
                    d.enabled = field.enabled; d.minutes = field.minutes; d.backpackPercent = field.backpackPercent
                    d.returnMethod = field.returnMethod; d.travel = field.travel
                    field = d
                }
                .buttonStyle(QuietButtonStyle()).padding(.top, Theme.s2)
                .help("Puts pattern, size, camera and sprinkler back to Natro's values for this field")
            }
        }
    }

    private func label(_ t: String) -> some View { Text(t).font(Theme.caption).foregroundStyle(Theme.dust) }
}
