import Photos
import SwiftUI

struct AssetThumbnail: View {
    let asset: PHAsset
    var side: CGFloat = 104
    var corner: CGFloat = 8

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.06))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.35))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .contentShape(Rectangle())
        .task(id: asset.localIdentifier) {
            let target = CGSize(width: side * 2.2, height: side * 2.2)
            let loaded = await ThumbnailProvider.shared.image(for: asset, size: target)
            image = loaded
            failed = loaded == nil
        }
    }
}

struct CategoryCard: View {
    let icon: String
    let title: String
    let detail: String
    let size: Int64
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.size(size))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint)
                Text("可释放")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.5)
        )
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 0.5))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
