import SwiftUI

struct ScanningView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: model.progress)

                VStack(spacing: 3) {
                    Text("\(Int(model.progress * 100))%")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(Fmt.count(model.processed)) / \(Fmt.count(max(model.total, 1)))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(width: 190, height: 190)

            VStack(spacing: 8) {
                Text(model.phaseLabel.isEmpty ? "正在准备…" : model.phaseLabel)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("照片只在本机分析，不会上传")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                model.cancelScan()
            } label: {
                Text("取消扫描")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: Capsule())
            }
            .padding(.bottom, 40)
        }
    }
}
