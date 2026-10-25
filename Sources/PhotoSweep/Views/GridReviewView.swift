import Photos
import SwiftUI

struct GridReviewView: View {
    enum Source: Equatable {
        case blurry
        case screenshots
        case wechat
        case videos
    }

    let source: Source

    @EnvironmentObject private var model: AppModel
    @State private var selection: Set<String> = []
    @State private var showInfo = false

    private var items: [MediaItem] {
        guard let result = model.result else { return [] }
        switch source {
        case .blurry: return result.blurry
        case .screenshots: return result.screenshots
        case .wechat: return result.wechatPhotos
        case .videos: return result.largeVideos
        }
    }

    private var selectedItems: [MediaItem] {
        items.filter { selection.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(Int64(0)) { $0 + $1.displaySize }
    }

    private var allSelected: Bool {
        !items.isEmpty && selection.count == items.count
    }

    private var title: String {
        switch source {
        case .blurry: return "模糊照片"
        case .screenshots: return "截图"
        case .wechat: return "微信相机"
        case .videos: return "大体积视频"
        }
    }

    private var hint: String {
        switch source {
        case .blurry:
            return "按模糊程度排序，越靠前越虚。建议只勾选明显糊掉的，先看前 20 张。"
        case .screenshots:
            return "按时间倒序。截图里常有要保留的信息，建议逐张挑，别全选。"
        case .wechat:
            return "按判定把握从高到低排序。这些照片缺少 iPhone 原生相机的拍摄信息，是微信相机保存后的典型特征。点右上角 ⓘ 看判定依据。"
        case .videos:
            return "按体积从大到小排序，最大的在最前面。"
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if items.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "已经清空",
                    message: "这个分类里没有剩余项目了。"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                            .padding(.top, 6)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 104), spacing: 3)],
                            spacing: 3
                        ) {
                            ForEach(items) { item in
                                cell(item)
                            }
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                if !items.isEmpty {
                    bottomBar
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if source == .wechat {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(allSelected ? "取消全选" : "全选") {
                    toggleAll()
                }
                .font(.subheadline)
                .disabled(items.isEmpty)
            }
        }
        .alert("判定依据", isPresented: $showInfo) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("iOS 不记录「照片是哪个 App 拍的」，所以只能靠元数据反推。\n\n微信相机拍完会用 UIImage 重新压缩再存相册，JPEG 重编码会丢掉全部 EXIF。而 iPhone 原生相机一定会写厂商、机型、Apple 私有 MakerNote、镜头型号和曝光参数。\n\n凡是「这些信息全都没有」的照片，就判为微信相机。副作用：从网页保存的图、其他 App 保存的图也会命中，所以别一键全删，先扫一眼缩略图。")
        }
    }

    private func cell(_ item: MediaItem) -> some View {
        let isSelected = selection.contains(item.id)

        return ZStack(alignment: .topTrailing) {
            AssetThumbnail(asset: item.asset, side: 104, corner: 6)
                .overlay(alignment: .bottomLeading) {
                    if item.isVideo {
                        Text(Fmt.duration(item.asset.duration))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(5)
                    }
                }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.accent : Color.white.opacity(0.65))
                .shadow(color: .black.opacity(0.6), radius: 2)
                .padding(6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 0.5)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选 \(selection.count) 项")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(Fmt.size(selectedSize))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    let targets = selectedItems
                    Task {
                        await model.delete(targets)
                        selection.removeAll()
                    }
                } label: {
                    Text("删除")
                        .font(.headline)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Theme.danger, in: Capsule())
                }
                .disabled(selection.isEmpty || model.isDeleting)
                .opacity(selection.isEmpty ? 0.35 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func toggleAll() {
        if allSelected {
            selection.removeAll()
        } else {
            selection = Set(items.map { $0.id })
        }
    }
}
