import SwiftUI
import HiveMacCore

/// The run dropdown. Click a run to open it, or the bin next to it to delete it (asks once).
struct RunPicker: View {
    @EnvironmentObject var model: AppModel
    @State private var open = false
    @State private var asking: String?

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: Theme.s1) {
                Text(model.runs.first { $0.file == model.activeRunFile }?.name ?? "").font(Theme.body).foregroundStyle(Theme.wax).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.dust)
            }
            .padding(.horizontal, Theme.s2).frame(width: 200, height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.plank))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.grain, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.runs) { run in
                    HStack(spacing: Theme.s2) {
                        Button { model.switchRun(run.file); open = false } label: {
                            HStack {
                                Text(run.name).font(Theme.body).foregroundStyle(run.file == model.activeRunFile ? Theme.honeyText : Theme.wax)
                                Spacer(minLength: 0)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if asking == run.file {
                            Button("Delete") { asking = nil; model.deleteRun(run.file) }.buttonStyle(QuietButtonStyle(tint: Theme.ember))
                            Button("Keep") { asking = nil }.buttonStyle(QuietButtonStyle())
                        } else if model.canDeleteRun {
                            Button { asking = run.file } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).foregroundStyle(Theme.ember).help("Delete this run")
                        }
                    }
                    .padding(.horizontal, Theme.s3).frame(height: 32)
                }
            }
            .frame(width: 260).padding(.vertical, Theme.s2)
            .background(Theme.shed)
            .onDisappear { asking = nil }
        }
    }
}
