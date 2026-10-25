import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    private var result: ScanResult { model.result ?? ScanResult() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                heroCard
                    .padding(.bottom, 4)

                if !result.hasFindings {
                    EmptyStateView(
                        icon: "checkmark.seal",
                        title: "很干净",
                        message: "没有发现可清理的重复、微信相机照片、截图或大视频。"
                    )
                    .frame(height: 260)
                } else {
                    if !result.exactGroups.isEmpty {
                        NavigationLink {
                            DuplicateReviewView(kind: .exact)
                        } label: {
                            CategoryCard(
                                icon: "square.on.square",
                                title: "重复照片",
                                detail: "\(result.exactGroups.count) 组 · 建议删 \(result.exactGroups.reduce(0) { $0 + $1.deletable.count }) 张",
                                size: result.exactSavings,
                                tint: Theme.accent
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !result.similarGroups.isEmpty {
                        NavigationLink {
                            DuplicateReviewView(kind: .similar)
                        } label: {
                            CategoryCard(
                                icon: "rectangle.stack",
                                title: "相似连拍",
                                detail: "\(result.similarGroups.count) 组 · 建议删 \(result.similarGroups.reduce(0) { $0 + $1.deletable.count }) 张",
                                size: result.similarSavings,
                                tint: Theme.info
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !result.wechatPhotos.isEmpty {
                        NavigationLink {
                            GridReviewView(source: .wechat)
                        } label: {
                            CategoryCard(
                                icon: "message.fill",
                                title: "微信相机",
                                detail: "\(result.wechatPhotos.count) 张 · 无原生相机拍摄信息",
                                size: result.wechatSavings,
                                tint: Theme.wechat
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !result.blurry.isEmpty {
                        NavigationLink {
                            GridReviewView(source: .blurry)
                        } label: {
                            CategoryCard(
                                icon: "camera.filters",
                                title: "模糊照片",
                                detail: "\(result.blurry.count) 张 · 拉普拉斯方差低于阈值",
                                size: result.blurrySavings,
                                tint: Theme.warning
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !result.screenshots.isEmpty {
                        NavigationLink {
                            GridReviewView(source: .screenshots)
                        } label: {
                            CategoryCard(
                                icon: "crop",
                                title: "截图",
                                detail: "\(result.screenshots.count) 张 · 按时间倒序",
                                size: result.screenshotSavings,
                                tint: Theme.purple
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if !result.largeVideos.isEmpty {
                        NavigationLink {
                            GridReviewView(source: .videos)
                        } label: {
                            CategoryCard(
                                icon: "film.stack",
                                title: "大体积视频",
                                detail: "\(result.largeVideos.count) 个 · 体积最大优先",
                                size: result.videoSavings,
                                tint: Theme.danger
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                statsFooter

                rescanButton
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationTitle("扫描结果")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("预计可释放")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            Text(Fmt.size(result.reclaimable))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)

            HStack(spacing: 6) {
                Text("重复 \(result.duplicateCount) 张")
                Text("·")
                Text("截图 \(result.screenshots.count) 张")
                Text("·")
                Text("大视频 \(result.largeVideos.count) 个")
            }
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .padding(.top, 2)

            if !result.wechatPhotos.isEmpty {
                Text("另有 \(result.wechatPhotos.count) 张微信相机照片 · \(Fmt.size(result.wechatSavings))")
                    .font(.caption)
                    .foregroundStyle(Theme.wechat)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.accent.opacity(0.22), lineWidth: 0.5)
        )
    }

    private var statsFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "扫描详情")
            HStack(spacing: 4) {
                Text("照片 \(Fmt.count(result.scannedImages)) 张")
                Text("·")
                Text("视频 \(Fmt.count(result.scannedVideos)) 个")
                Text("·")
                Text("耗时 \(Fmt.elapsed(result.elapsed))")
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)

            if result.skipped > 0 {
                Text("\(result.skipped) 张照片存放在 iCloud 未下载，已跳过。可在「照片」里先下载原图后重新扫描。")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private var rescanButton: some View {
        Button {
            let settings = ScanSettings(
                blurThreshold: UserDefaults.standard.object(forKey: "blurThreshold") as? Double ?? 60,
                largeVideoMB: UserDefaults.standard.object(forKey: "largeVideoMB") as? Int ?? 100,
                includeVideos: UserDefaults.standard.object(forKey: "includeVideos") as? Bool ?? true,
                maxDistance: UserDefaults.standard.object(forKey: "maxDistance") as? Int ?? 6,
                detectWeChat: UserDefaults.standard.object(forKey: "detectWeChat") as? Bool ?? true
            )
            model.startScan(settings: settings)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text("重新扫描")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
