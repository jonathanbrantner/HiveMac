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

    @State private var showMore = false

    /// One setting: a name and the control. No explanations; the names say it.
    private func setting<Control: View>(_ name: String, @ViewBuilder _ control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: Theme.s3) {
            Text(name).font(Theme.body).foregroundStyle(Theme.resin).frame(width: 150, alignment: .leading)
            control()
            Spacer(minLength: 0)
        }
        .frame(minHeight: 28)
    }

    private var more: some View {
        VStack(alignment: .leading, spacing: 0) {
            setting("Use this field") { Toggle("", isOn: $field.enabled).toggleStyle(.checkbox).labelsHidden() }
            setting("Pattern size") {
                Choice(options: [("xs", "Tiny"), ("s", "Small"), ("m", "Medium"), ("l", "Large"), ("xl", "Huge")], selection: sizeBinding, width: 120)
            }
            setting("Sprinkler spot") {
                Choice(options: Self.locations.map { ($0, $0.capitalized) }, selection: $field.sprinklerLocation, width: 120)
            }
            setting("Back to hive") {
                Choice(options: [("walk", "Walk back"), ("reset", "Respawn")], selection: $field.returnMethod, width: 120)
            }
            setting("Get there") {
                Choice(options: [("default", "Usual"), ("walk", "Walk"), ("cannon", "Cannon")], selection: $field.travel, width: 120)
            }

            Button { withAnimation(.snappy(duration: 0.15)) { showMore.toggle() } } label: {
                HStack(spacing: Theme.s1) {
                    Image(systemName: showMore ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold)).frame(width: 10)
                    Text("More").font(Theme.bodyStrong)
                }.foregroundStyle(Theme.honeyText)
            }
            .buttonStyle(.plain).padding(.vertical, Theme.s2)

            if showMore {
                setting("Camera turn") {
                    Choice(options: [("none", "None"), ("left", "Left"), ("right", "Right")], selection: $field.camera, width: 90)
                    TextField("", value: $field.turns, format: .number).fieldStyle(width: 48)
                }
                setting("Sprinkler distance") { TextField("", value: $field.sprinklerDistance, format: .number).fieldStyle(width: 56) }
                setting("Pattern repeats") { TextField("", value: $field.width, format: .number).fieldStyle(width: 56) }
                setting("Shift lock") { Toggle("", isOn: $field.shiftLock).toggleStyle(.checkbox).labelsHidden() }
                setting("Mirror forward and back") { Toggle("", isOn: $field.invertFB).toggleStyle(.checkbox).labelsHidden() }
                setting("Mirror left and right") { Toggle("", isOn: $field.invertLR).toggleStyle(.checkbox).labelsHidden() }
                Button("Reset to Natro's values") {
                    var d = FieldConfig(name: field.name)
                    d.enabled = field.enabled; d.minutes = field.minutes; d.backpackPercent = field.backpackPercent
                    d.returnMethod = field.returnMethod; d.travel = field.travel
                    field = d
                }
                .buttonStyle(QuietButtonStyle()).padding(.top, Theme.s2)
            }
        }
    }

    private func label(_ t: String) -> some View { Text(t).font(Theme.caption).foregroundStyle(Theme.dust) }
}
