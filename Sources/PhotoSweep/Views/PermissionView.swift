import Photos
import SwiftUI

struct PermissionView: View {
    let status: PHAuthorizationStatus
    let onTap: () -> Void

    private var isDenied: Bool {
        status == .denied || status == .restricted
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 108, height: 108)
                Image(systemName: "photo.stack")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 10) {
                Text(isDenied ? "相册权限已关闭" : "需要访问你的相册")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(isDenied
                     ? "请到「设置 → 相册清理 → 照片」里选择「完全访问」，然后回到这里。"
                     : "扫描重复照片、相似连拍、模糊照片、截图与大体积视频。全部在本机完成，不会上传任何照片。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            Button(action: onTap) {
                Text(isDenied ? "前往设置" : "允许访问相册")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}
