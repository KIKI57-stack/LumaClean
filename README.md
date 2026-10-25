# 相册清理 PhotoSweep

一个用 SwiftUI + PhotoKit 写的 iPhone 相册清理工具。扫描全库，按「重复照片 / 相似连拍 / 模糊照片 / 截图 / 大体积视频」分类，批量删除。

用 [xtool](https://github.com/xtool-org/xtool) 构建：**不需要 Mac**，在 Windows（WSL）上就能编译、签名、装进 iPhone。

---

## 它能做什么

| 分类 | 判定方式 |
|---|---|
| 重复照片 | 64 bit 感知哈希（dHash）+ 多索引分桶加速，汉明距离 ≤ 3 判为重复 |
| 相似连拍 | 同一套哈希，距离 4–6 判为相似，单独一组 |
| 微信相机 | 读 EXIF，缺少 iPhone 原生相机的厂商/机型/MakerNote/镜头/曝光参数 → 判为微信相机保存 |
| 模糊照片 | 128×128 灰度图上算拉普拉斯方差，低于阈值判为模糊（阈值可调） |
| 截图 | 读 PhotoKit 的 `photoScreenshot` 原生标记，不会误判 |
| 大体积视频 | 按真实文件大小排序，阈值可调 |

删除时：

- 每组重复/相似照片自动保留**画质最好的一张**（分辨率 → 文件大小 → 清晰度依次比较）
- 删除前 iOS 系统会再弹一次确认框
- 删掉的照片进「最近删除」，**保留 30 天，随时可恢复**

## 隐私

所有分析都在设备本地完成。App 不发起任何网络请求，没有第三方 SDK，照片不出手机。

---

## 微信相机照片是怎么认出来的

先说结论：**iOS 没有任何 API 能告诉你「这张照片是哪个 App 拍的」**。`PHAsset` 里没有这个字段，公开接口也查不到。所以只能靠元数据反推。

依据是这条事实链：

1. 微信相机拍完，会把画面用 `UIImage` 重新压缩再存进相册
2. `UIImage` 的 JPEG 重新编码会**丢掉全部 EXIF**
3. 而 iPhone 原生相机**一定**会写这些字段：

| 字段 | 原生相机 | 微信相机保存后 |
|---|---|---|
| `TIFF.Make` | `Apple` | 无 |
| `TIFF.Model` | `iPhone 15 Pro` | 无 |
| `Exif.MakerApple`（Apple 私有 MakerNote） | 有 | 无 |
| `Exif.LensModel` | 有 | 无 |
| `Exif.FNumber` / `ExposureTime` / `ISOSpeedRatings` | 有 | 无 |
| `GPS` | 视定位权限 | 通常无 |
| `Exif.DateTimeOriginal` | 有 | 通常无 |

凡是「这些信息全都没有」的照片，就判为微信相机保存的。

**这是一个有假阳性的启发式，不是 100% 判定。** 同样会命中这个分类的还有：

- 从网页/微信聊天里保存下来的图片
- 其他 App 用同样方式保存的图
- 经过某些第三方修图软件导出、抹掉元数据的图

所以这个分类里**不要一键全选删除**，先扫一眼缩略图。App 里点右上角 ⓘ 也能看到这段说明。

判定采用加权打分（满分 10），达到 5 分才进列表，按分数从高到低排序——排在最前面的把握最大。

另外，开启这项检测会让扫描变慢，因为要逐张读原图的元数据（不解码像素，只读文件头）。不想用可以在设置里关掉。

---

## 装到 iPhone（Windows，不需要 Mac）

整套流程一次性配置约 1–2 小时，主要时间花在下载 Xcode 上（约 12 GB）。配好之后，改代码只要敲一句 `xtool dev`。

### 前置要求

- Windows 11，或 Windows 10 21H2 及以上
- **至少 40 GB 空闲磁盘，而且不能放在 C 盘。** 空间账：Ubuntu + Swift 约 6 GB，`Xcode.xip` 12 GB，xtool 解包出的 SDK 可能再占 20–30 GB。C 盘通常被系统占满，所以第 1 步会把 WSL 挪到其他盘
- 一个 Apple ID（免费账号就够，不需要 99 美元开发者账号）
- iPhone 数据线

---

### 第 1 步：装 WSL2 和 Ubuntu，然后挪到非系统盘

以**管理员身份**打开 PowerShell：

```powershell
wsl --install -d Ubuntu
```

装完重启电脑。重启后 Ubuntu 会自动弹出来，按提示设置用户名和密码。

然后**先把 Ubuntu 从 C 盘挪走**，再装其他东西：

```powershell
wsl --shutdown
wsl --manage Ubuntu --move E:\WSL\Ubuntu
```

> 把 `E:\WSL\Ubuntu` 换成你实际想放的路径。执行前确认那个盘有 40 GB 以上空闲。
>
> 如果提示 `--manage` 不支持，先跑 `wsl --update` 升级 WSL；升级后仍不行就用导出导入的方式：
>
> ```powershell
> wsl --export Ubuntu E:\WSL\ubuntu-backup.tar
> wsl --unregister Ubuntu
> wsl --import Ubuntu E:\WSL\Ubuntu E:\WSL\ubuntu-backup.tar --version 2
> ```
>
> 用 import 方式重装后默认用户会变成 root，需要自己在 `/etc/wsl.conf` 里设回普通用户。

之后所有命令都在 **Ubuntu 终端**里跑（开始菜单搜 Ubuntu）。

确认版本：

```bash
wsl --version
```

---

### 第 2 步：装 Swift 6.4 工具链

在 Ubuntu 终端里：

```bash
sudo apt update
sudo apt install -y binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
```

然后按 <https://swift.org/install/linux> 上的命令下载 Swift 6.4 并解压。装完验证：

```bash
swift --version
# Swift version 6.4 (swift-6.4-RELEASE)
```

---

### 第 3 步：把项目拷进 WSL，一键装依赖

先拷到 Linux 主目录（**别直接在 `/mnt/c` 里编译**，跨文件系统访问会慢好几倍）：

```bash
cd ~
cp "/mnt/c/Users/18539/WorkBuddy AI/2026-10-25-09-18-45/PhotoSweep.zip" .
unzip -q PhotoSweep.zip
cd PhotoSweep
```

然后跑脚本，它会装好 usbmuxd、编译依赖和 xtool：

```bash
bash tools/setup-wsl.sh
```

脚本最后会自检四项。Swift 那项显示「缺失」是正常的，下一步才装。

不想用脚本的话，等价命令是：

```bash
sudo apt install -y usbmuxd libimobiledevice-utils
```

检查设备通信：

```bash
usbmuxd --help
ideviceinfo
```

`ideviceinfo` 要能打出设备名。如果报错说连不上设备，多半是第 4 步的 USB 直通没做。

---

### 第 4 步：把 iPhone 的 USB 直通给 WSL

在 **PowerShell（管理员）**里：

```powershell
winget install usbipd
```

装完**重开**一个管理员 PowerShell，插上 iPhone 并在手机上点「信任」：

```powershell
usbipd list
```

找到 Apple 那一行，记下 BUSID（形如 `2-3`），然后：

```powershell
usbipd bind --busid 2-3
usbipd attach --wsl --busid 2-3
```

回到 Ubuntu 终端：

```bash
ideviceinfo
# DeviceName: xxx 的 iPhone
```

看到设备名就成了。**注意：每次拔插数据线都要重新执行 `usbipd attach`。**

---

### 第 5 步：下载 Xcode.xip

用浏览器打开 <https://developer.apple.com/download/all/?q=Xcode>，用 Apple ID 登录并同意协议，下载 **Xcode 27** 的 `.xip`（约 12 GB）。

> 这个地址需要登录，不能用 curl 直接下。
> 下载好的文件放在 Windows 的下载目录即可，WSL 里通过 `/mnt/c/Users/你的用户名/Downloads/` 访问。

---

### 第 6 步：安装 xtool

第 3 步的脚本已经装好了，跑一下 `xtool --help` 确认即可。如果那步没跑成功，手动装：

```bash
curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
chmod +x xtool
sudo mv xtool /usr/local/bin/
xtool --help
```

---

### 第 7 步：初始化 xtool

```bash
xtool setup
```

会依次问你两件事：

**① 登录方式**

```
Select login mode
0: API Key (requires paid Apple Developer Program membership)
1: Password (works with any Apple ID but uses private APIs)
Choice (0-1):
```

没有付费开发者账号就选 **`1`**，然后输入 Apple ID 邮箱、密码、双重认证验证码。

> 密码模式走的是苹果私有接口。介意的话可以注册一个小号专门用来签名，但要记住是哪个号——后面手机上「信任开发者」时显示的会是它。

**② Xcode.xip 路径**

```
Path to Xcode.xip:
```

填 WSL 里的路径，例如：

```
/mnt/c/Users/你的用户名/Downloads/Xcode_27.0.xip
```

xtool 会解包并生成 iOS Swift SDK，需要几分钟。完成后验证：

```bash
swift sdk list
# darwin
```

---

### 第 8 步：编译并装进手机

```bash
cd ~/PhotoSweep
xtool dev
```

它会自动完成：编译 → 注册设备 → 申请证书和描述文件 → 签名 → 通过 USB 安装。

第一次编译要等几分钟（要为 iOS SDK 编译 Swift 模块），之后会快很多。

装完第一次打开如果提示「不受信任的开发者」：

1. **设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → 信任**
2. 如果打不开还提示需要开发者模式：**设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机 → 确认**
3. 再运行一次 `xtool dev`

---

## 怎么用

1. 打开 App → 允许访问**所有照片**
2. 点「开始扫描」，等进度走完（1 万张照片大约 1–3 分钟）
3. 结果页会显示预计可释放的空间，点进各分类：
   - **重复照片 / 相似连拍**：每组已标出「保留」的那张，点「删除其余 N 张」，或右上角「全部清理」
   - **微信相机**：按判定把握排序，逐个勾选后删除。**别全选**，先看缩略图（会混进网页保存的图）
   - **模糊 / 截图 / 大视频**：网格里逐张勾选后点「删除」
4. 删除时系统会再确认一次

右上角滑块图标可以调扫描参数。

---

## 参数说明

| 参数 | 默认 | 说明 |
|---|---|---|
| 模糊判定严格度 | 60 | 拉普拉斯方差阈值。调大 → 找出的「模糊」照片变多（可能误伤夜景、纯色背景）。调小 → 只挑明显虚焦的 |
| 大视频阈值 | 100 MB | 超过这个体积才进「大视频」列表 |
| 重复判定容差 | 6 | 哈希汉明距离。调大更容易把「相似」判成「重复」。建议保持 6 |
| 扫描视频 | 开 | 关掉可以加快扫描 |
| 识别微信相机照片 | 开 | 逐张读 EXIF 判断来源。关掉可以明显加快扫描，但不会生成「微信相机」分类 |

改完参数要重新扫描才生效。

---

## 项目结构

这个项目有**两条互不干扰的构建通道**，共用同一份 `Sources/`：

```
PhotoSweep/
├── Package.swift              xtool 通道：SwiftPM 定义
├── xtool.yml                  xtool 通道：Bundle ID、图标、Info.plist 路径
├── project.yml                Xcode 通道：XcodeGen 工程描述
├── .gitattributes             强制 LF 换行（Windows 上防 CRLF 弄坏 workflow）
├── .github/workflows/build.yml  Xcode 通道：云端编译，产出未签名 ipa
├── Support/
│   ├── Info.plist             xtool 用：只写覆盖键，xtool 会合并
│   └── Info-xcode.plist       Xcode 用：完整 plist
├── Assets/Assets.xcassets/    Xcode 用图标集（icon-1024.png 由脚本生成）
├── Resources/AppIcon.png      1024×1024 原图（xtool 用，同样由脚本生成）
├── tools/
│   ├── make_icon.py           图标生成脚本（纯 Python，无依赖）
│   └── setup-wsl.sh           WSL 依赖一键安装
└── Sources/PhotoSweep/
    ├── App/PhotoSweepApp.swift
    ├── Models/                MediaItem、ScanResult、DuplicateGroup
    ├── Services/
    │   ├── PhotoLibraryService.swift   权限、取图、删除
    │   ├── ImageAnalyzer.swift         dHash + 拉普拉斯方差
    │   ├── DuplicateGrouper.swift      多索引分桶 + 并查集
    │   ├── ExifInspector.swift        读 ImageIO 属性字典（不解码像素）
    │   ├── WeChatDetector.swift       微信相机加权判定
    │   ├── ThumbnailProvider.swift     缩略图缓存
    │   └── AppModel.swift              扫描流程编排
    ├── Views/                 5 个界面
    └── Support/               主题色、格式化
```

**图标不在仓库里，要用之前先跑一次脚本：**

```bash
python3 tools/make_icon.py
```

它会同时写出 `Resources/AppIcon.png`（xtool 用）和 `Assets/.../icon-1024.png`（Xcode 用）。CI 里已经自动执行这一步，所以走云端编译时你什么都不用做。

之所以不入库，是因为 PNG 是二进制：一旦被 Git 当文本处理就会被改写字节、图标直接损坏；而且改一次配色就多 21KB 历史。脚本是确定性的，任何机器上跑出来字节完全相同。

**`Assets/` 必须在 `Sources/PhotoSweep/` 之外。** SwiftPM 会把 target 目录里未声明的非源码文件当成「未处理资源」直接报错，xtool 通道会立刻挂掉。

**改 Bundle ID 要改两处**，否则两条通道产出的是两个不同的 App：

- `xtool.yml` 的 `bundleID`
- `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`

---

## 另一条通道：GitHub Actions（不用装 WSL，不用下 12 GB）

如果你不想配 WSL + Swift + Xcode.xip，可以走云端编译。macOS 机器由 GitHub 提供，自带 Xcode，你本地只需要装 Sideloadly 签名。

### 两条通道怎么选

| | xtool（本地） | GitHub Actions（云端） |
|---|---|---|
| 本地要下载 | 12 GB + 6 GB | 约 250 MB |
| 首次配置 | 2–4 小时 | 约 40 分钟 |
| 改代码后 | `xtool dev` 一条命令 | push → 等 5 分钟 → 下载 ipa → 拖进 Sideloadly |
| 签名 | 全自动 | 手动填一次 App 专用密码 |

只清一次相册 → 选云端。要反复改代码 → 选 xtool。

### 云端流程

**1. 建一个空仓库**

github.com/new → 名字随意 → 选 **Private** → **不要**勾 README / .gitignore / license。

**2. 把项目传上去**

保持目录结构不变。GitHub 网页端支持直接把文件夹拖进上传框。

**3. 触发构建**

仓库页 → **Actions** → 左侧 `Build unsigned IPA` → 右侧 **Run workflow** → 绿色按钮。

等 3–5 分钟。第一次因为要 `brew install xcodegen` 会慢一些。

**4. 下载 ipa**

进这次运行记录 → 页面底部 **Artifacts** → 下载 `PhotoSweep-unsigned-ipa.zip` → 解压得到 `PhotoSweep-unsigned.ipa`。

**5. 在 Windows 上签名安装**

1. 装 iTunes（Apple 官网下载，**不要**用 Microsoft Store 版）—— 它提供 USB 驱动
2. 下载 [Sideloadly](https://sideloadly.io)，**要用较新版本**，旧版可能拒绝导入未签名 ipa
3. 生成 App 专用密码：appleid.apple.com → 登录 → 安全 → App 专用密码
4. 数据线连 iPhone，手机上点「信任此电脑」
5. Sideloadly 里拖入 ipa，Apple ID 填邮箱，密码填**App 专用密码**，点 Start
6. 手机上：设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → 信任
7. 设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启 → 确认

### 免费额度

私有仓库每月 2000 分钟，macOS runner 按 10 倍计费，实际约 200 分钟。每次构建约 5 分钟，够跑 40 次。公开仓库无限。

---

## 常见问题

**`Error: AFCClient.Error.muxError`**

USB 直通没打通。先试 `sudo usbmuxd -f -v`（单独开一个终端，保持运行），再重跑 `xtool dev`。
还不行就用 iTunes 中转方案，见 <https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718>。

**`ideviceinfo` 看不到设备**

重新执行 `usbipd attach --wsl --busid X-Y`（每次拔插都要重来），并确认手机上点了「信任此电脑」。

**App 打开闪退 / 提示需要开发者模式**

iOS 16 以后自签名 App 必须开开发者模式：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启。

**7 天后 App 打不开了**

免费 Apple ID 签的证书有效期 7 天。重跑一次 `xtool dev` 即可，不用重新配置。清理是一次性任务，通常清完就可以把 App 删掉。

**编译报错 `found unhandled resource`**

SwiftPM 要求 target 目录里不能有未声明的资源文件。`Support/`、`Resources/` 已经放在 target 目录外，如果你自己往里加文件，注意别放进 `Sources/PhotoSweep/`。

**扫描很慢**

- 照片超过 3 万张时，第一次扫描需要几分钟，属正常
- 开了「优化 iPhone 存储」的照片如果还没下载原图，会被跳过（结果页会显示跳过了多少张）。可以先把原图下载下来再扫
- 在设置里关掉「扫描视频」可以明显加快

**模糊列表里混进了夜景或纯色照片**

拉普拉斯方差对低纹理画面天然敏感。把「模糊判定严格度」调小到 30–40，或直接忽略那几张。

**「微信相机」里混进了不是微信拍的照片**

正常。网页保存的图、其他 App 保存的图同样没有相机 EXIF，会被一起命中。iOS 没有接口能查到「创建这张照片的 App」，这个误判在技术上无法根除。把这个分类当**候选清单**用，删之前过一眼缩略图。

**一张微信照片都没认出来**

说明你的微信版本保存时保留了部分 EXIF，这套启发式就失效了。补救办法：挑 2–3 张确认是微信拍的，用「文件」App 存出来发我，我看看里面到底有哪些字段，再改判定规则。`Sources/PhotoSweep/Services/WeChatDetector.swift` 里的打分权重是集中的，改起来很快。
