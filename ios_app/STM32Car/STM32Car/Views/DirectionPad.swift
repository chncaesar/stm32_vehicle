import SwiftUI

/// 四方向方向盘组件（3×3 Grid，中心为停车按钮）。
///
/// 每个方向按钮通过 `DragGesture(minimumDistance: 0)` 区分按下和松开，
/// 与固件协议中的按下/松开语义完全匹配。
struct DirectionPad: View {

    let onPress: (BLECommand.Direction) -> Void
    let onRelease: () -> Void
    let onEmergencyStop: () -> Void
    let isEnabled: Bool

    @State private var isPressing = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 88, height: 88)
                directionButton(.forward, icon: "chevron.up")
                Color.clear.frame(width: 88, height: 88)
            }
            HStack(spacing: 8) {
                directionButton(.left, icon: "chevron.left")
                stopButton
                directionButton(.right, icon: "chevron.right")
            }
            HStack(spacing: 8) {
                Color.clear.frame(width: 88, height: 88)
                directionButton(.backward, icon: "chevron.down")
                Color.clear.frame(width: 88, height: 88)
            }
        }
        .frame(width: 288, height: 288)
    }

    // MARK: - Direction Button

    private func directionButton(_ direction: BLECommand.Direction,
                                 icon: String) -> some View {
        Button {
            // onTapGesture 不会触发这里；DragGesture 处理所有事件
        } label: {
            Image(systemName: icon)
                .font(.title.weight(.semibold))
                .frame(width: 88, height: 88)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(isPressing ? 0.5 : 0), lineWidth: 2)
                )
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressing else { return }
                    isPressing = true
                    onPress(direction)
                }
                .onEnded { _ in
                    guard isEnabled else { return }
                    isPressing = false
                    onRelease()
                }
        )
        .disabled(!isEnabled)
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button {
            onEmergencyStop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title.weight(.bold))
                .frame(width: 80, height: 80)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.red.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.red.opacity(0.25), lineWidth: 1)
                        )
                }
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

#Preview {
    DirectionPad(
        onPress: { _ in },
        onRelease: {},
        onEmergencyStop: {},
        isEnabled: true
    )
    .padding()
}
