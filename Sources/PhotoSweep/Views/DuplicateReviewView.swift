import Photos
import SwiftUI

struct DuplicateReviewView: View {
    enum Kind {
        case exact
        case similar
    }

    let kind: Kind

    @EnvironmentObject private var model: AppModel

    private var groups: [DuplicateGroup] {
        guard let result = model.result else { return [] }
        return kind == .exact ? result.exactGroups : result.similarGroups
    }

    private var totalDeletable: Int {
        groups.reduce(0) { $0 + $1.deletable.count }
    }

    private var totalSavings: Int64 {
        groups.reduce(Int64(0)) { $0 + $1.savings }
    }

    private var title: String {
        kind == .exact ? "重复照片" : "相似连拍"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if groups.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "已经清空",
                    message: "没有剩余的分组了。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        header
                        ForEach(groups) { group in
                            card(group)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("全部清理") {
                    let targets = groups.flatMap { $0.deletable }
                    Task { await model.delete(targets) }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
                .disabled(groups.isEmpty || model.isDeleting)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("共 \(groups.count) 组，每组保留画质最好的一张")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            Text("建议删除 \(totalDeletable) 张，可释放 \(Fmt.size(totalSavings))")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if kind == .similar {
                Text("「相似」是按画面指纹判断的，可能是连拍或轻微改动的同一张。删之前先看一眼缩略图。")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private func card(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(group.items.count) 张")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let date = group.items.first?.creationDate {
                    Text(Fmt.dayFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Text("省 \(Fmt.size(group.savings))")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        thumb(item, isBest: index == 0)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                Task { await model.delete(group.deletable) }
            } label: {
                Text("删除其余 \(group.deletable.count) 张")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.danger.opacity(0.12), in: Capsule())
            }
            .disabled(model.isDeleting)
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.5)
        )
    }

    private func thumb(_ item: MediaItem, isBest: Bool) -> some View {
        VStack(spacing: 5) {
            AssetThumbnail(asset: item.asset, side: 92, corner: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isBest ? Theme.accent : Color.clear, lineWidth: 2)
                )

            if isBest {
                Text("保留")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            } else {
                Text(Fmt.size(item.displaySize))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
