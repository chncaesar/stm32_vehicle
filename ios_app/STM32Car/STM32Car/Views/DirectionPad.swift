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
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
                directionButton(.forward, icon: "chevron.up")
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                directionButton(.left, icon: "chevron.left")
                stopButton
                directionButton(.right, icon: "chevron.right")
            }
            GridRow {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
                directionButton(.backward, icon: "chevron.down")
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
        .frame(width: 216, height: 216)
    }

    // MARK: - Direction Button

    private func directionButton(_ direction: BLECommand.Direction,
                                 icon: String) -> some View {
        Button {
            // onTapGesture 不会触发这里；DragGesture 处理所有事件
        } label: {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 64, height: 64)
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
                .font(.title3.weight(.bold))
                .frame(width: 56, height: 56)
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
