import SwiftUI
import HiveMacCore

/// "All": the same four values as the Settings tab, to set every field of this run at once.
struct AllFieldsButton: View {
    @EnvironmentObject var model: AppModel
    @State private var open = false

    private func num(_ path: String, _ fallback: Double) -> Binding<Double> {
        Binding(get: { _ = model.settingsVersion; return model.store.double(path, fallback) }, set: { model.set(path, $0) })
    }
    private func int(_ path: String, _ fallback: Int) -> Binding<Int> {
        Binding(get: { _ = model.settingsVersion; return model.store.int(path, fallback) }, set: { model.set(path, $0) })
    }
    private func str(_ path: String, _ fallback: String) -> Binding<String> {
        Binding(get: { _ = model.settingsVersion; return model.store.string(path, fallback) }, set: { model.set(path, $0) })
    }

    var body: some View {
        Button("All") { open.toggle() }
            .buttonStyle(QuietButtonStyle()).help("Set every field at once")
            .popover(isPresented: $open, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: Theme.s2) {
                    row("Minutes") { TextField("", value: num("fields.minutes", 10), format: .number).fieldStyle(width: 64) }
                    row("Pattern size") {
                        Choice(options: [("xs", "Tiny"), ("s", "Small"), ("m", "Medium"), ("l", "Large"), ("xl", "Huge")], selection: str("fields.size", "m"), width: 110)
                    }
                    row("Pattern repeats") { TextField("", value: int("fields.width", 4), format: .number).fieldStyle(width: 64) }
                    row("Back to hive") {
                        Choice(options: [("walk", "Walk back"), ("reset", "Respawn")], selection: str("fields.return", "walk"), width: 110)
                    }
                    Button("Apply to all fields") { model.applyFieldDefaultsToAll(); open = false }
                        .buttonStyle(HoneyButtonStyle()).padding(.top, Theme.s2)
                }
                .padding(Theme.s4).background(Theme.shed)
            }
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: Theme.s3) {
            Text(label).font(Theme.body).foregroundStyle(Theme.resin).frame(width: 110, alignment: .leading)
            control()
        }
    }
}
