import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    @AppStorage("blurThreshold") private var blurThreshold: Double = 60
    @AppStorage("largeVideoMB") private var largeVideoMB: Int = 100
    @AppStorage("includeVideos") private var includeVideos: Bool = true
    @AppStorage("maxDistance") private var maxDistance: Int = 6
    @AppStorage("detectWeChat") private var detectWeChat: Bool = true

    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                libraryCard
                scanButton
                safetyCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("相册清理")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("找出重复、模糊、截图和大视频，一次清干净")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var libraryCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.count(model.photoCount))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("张照片")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 0.5, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.count(model.videoCount))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("个视频")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.5)
        )
    }

    private var scanButton: some View {
        Button {
            let settings = ScanSettings(
                blurThreshold: blurThreshold,
                largeVideoMB: largeVideoMB,
                includeVideos: includeVideos,
                maxDistance: maxDistance,
                detectWeChat: detectWeChat
            )
            model.startScan(settings: settings)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                Text("开始扫描")
                    .font(.headline)
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 4)
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("删除很安全", systemImage: "shield.lefthalf.filled")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)

            bullet("照片只在本机分析，App 不联网、不上传")
            bullet("删除前系统会再确认一次")
            bullet("删掉的照片在「最近删除」里保留 30 天，可随时恢复")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.accent.opacity(0.7))
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("blurThreshold") private var blurThreshold: Double = 60
    @AppStorage("largeVideoMB") private var largeVideoMB: Int = 100
    @AppStorage("includeVideos") private var includeVideos: Bool = true
    @AppStorage("maxDistance") private var maxDistance: Int = 6
    @AppStorage("detectWeChat") private var detectWeChat: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("模糊判定严格度")
                            Spacer()
                            Text("\(Int(blurThreshold))")
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(value: $blurThreshold, in: 20...150, step: 5)
                        Text("数值越大越严格，被判定为「模糊」的照片越多。默认 60。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("模糊检测")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("大视频阈值")
                            Spacer()
                            Text("\(largeVideoMB) MB")
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(largeVideoMB) },
                                set: { largeVideoMB = Int($0) }
                            ),
                            in: 50...1000,
                            step: 50
                        )
                    }
                } header: {
                    Text("视频")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("重复判定容差")
                            Spacer()
                            Text("\(maxDistance)")
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(maxDistance) },
                                set: { maxDistance = Int($0) }
                            ),
                            in: 2...12,
                            step: 1
                        )
                        Text("数值越大，越容易把「相似」判成「重复」。建议保持 6。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("重复检测")
                }

                Section {
                    Toggle("扫描视频", isOn: $includeVideos)
                }

                Section {
                    Toggle("识别微信相机照片", isOn: $detectWeChat)
                    Text("通过读取每张照片的 EXIF 判断是否由微信相机保存。开启后会多花一些时间，因为要逐张读原图元数据。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("微信相机")
                }

                Section {
                    Text("修改设置后需要重新扫描才会生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("扫描设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
