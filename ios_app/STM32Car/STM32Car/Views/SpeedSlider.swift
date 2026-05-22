import SwiftUI

/// 速度滑块组件，1–9 档步进。
struct SpeedSlider: View {

    @Binding var speed: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("速度", systemImage: "speedometer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(speed)")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }

            SwiftUI.Slider(
                value: Binding(
                    get: { Double(speed) },
                    set: { speed = Int($0.rounded()) }
                ),
                in: 1...9,
                step: 1
            )
            .tint(.accentColor)
        }
    }
}

// MARK: - Preview

struct SpeedSlider_Previews: PreviewProvider {
    struct Wrapper: View {
        @State var speed = 5
        var body: some View {
            SpeedSlider(speed: $speed).padding()
        }
    }
    static var previews: some View { Wrapper() }
}
