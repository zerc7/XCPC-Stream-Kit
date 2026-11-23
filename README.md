# XCPC-Stream-Kit

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4?logo=windows&logoColor=white)](#环境要求)
[![Runtime](https://img.shields.io/badge/runtime-ffmpeg%20%2B%20VLC%20portable-informational)](#工作原理)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**选手机屏幕 + 摄像头双路推流工具包** —— 一次编码、多端拉流、免安装、开机静默自启。

> A zero-install dual-stream (screen + webcam) broadcaster for Windows contest PCs.
> ffmpeg captures and encodes, VLC serves HTTP MPEG-TS, so CDS / OBS / a browser can
> pull the same stream without re-encoding. Silent autostart on logon, automatic
> reconnect, no Python / installer / PATH changes required.

## 目录

- [特性](#特性)
- [工作原理](#工作原理)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [命令一览](#命令一览)
- [配置](#配置)
- [接入 CDS](#接入-cds)
- [验证](#验证)
- [常见问题](#常见问题)
- [安全说明](#安全说明)
- [批量部署](#批量部署)
- [日志](#日志)
- [已知限制](#已知限制)
- [贡献](#贡献)
- [致谢](#致谢)
- [许可证](#许可证)

## 特性

- **一次编码、多端拉流** —— ffmpeg 负责抓屏 / 采集与 H.264 编码，VLC 只负责把 MPEG-TS
  用 HTTP 分发出去。CDS、OBS、浏览器拉同一路流，不重复编码。
- **零安装** —— 运行时只有 `bin\` 下的 ffmpeg 与便携版 VLC：不写注册表、不装系统目录，
  删掉文件夹即彻底清除。
- **静默自启** —— `install.bat` 在「启动」文件夹建一个快捷方式，登录后无窗口推流。
- **断流自动重连** —— 每个流是独立的重连循环：正常 5 s 后重试，连续失败 5 次
  （摄像头 3 次）后退避到 15 / 30 s。
- **单实例保护** —— 启动时连查两次端口（间隔 3 s），快速双击两次也不会双开抢端口。
- **断流原因可追** —— VLC 不加 `--quiet`，真实原因落在 `logs\*-vlc.log`，同时把 VLC 退出码
  写进主日志；`stop.bat` 会在日志末尾留停止标记，避免把正常停止误判成故障。
- **抓屏不闪光标** —— 默认走 Desktop Duplication API（`ddagrab`），不可用时自动退回
  `gdigrab`，实际用了哪个会写进日志。
- **颜色自适应** —— 自动识别 Windows 11「自动颜色管理」导致的抓屏偏暗并做反向补偿，
  没开 ACM 的机器不做任何处理。
- **摄像头可热换** —— 自动探测设备（优先使用 ASCII 别名），连续失败 3 次后重新探测，
  换一台摄像头不需要重启脚本。
- **纯 ASCII 脚本** —— 任意系统代码页下都不会因为中文被 cmd 拆行；中文只存在于本文档。

## 工作原理

```
  ┌ 桌面 ── ffmpeg(ddagrab / gdigrab) ─┐
  │                                    ├─→ VLC HTTP :9090 → http://<本机IP>:9090/
  │ 摄像头 ── ffmpeg(dshow) ────────────┴─→ VLC HTTP :9092 → http://<本机IP>:9092/
```

两个流各自是一个 cmd 重连循环：`ffmpeg | vlc` 通过 stdin 管道连接，VLC 一旦退出，
整个管道就断、循环重来。VLC 的 http 输出是真正的 HTTP 服务端，第一个 GET 到达后才开始
推数据，所以「端口在监听」不等于「有画面」——`status.bat` 会真的拉一段数据校验 TS 同步字节。

抓屏默认使用 **Desktop Duplication API（`ddagrab`）**：读 DWM 已经合成好的画面，不碰系统
光标层（不会出现「一推流本机鼠标就闪」），CPU 也明显更低（1080p25 实测：`gdigrab` 约
115% 单核，`ddagrab` 约 77%）。启动时先探一帧，失败（Win8 以前的系统、虚拟机、D3D11
驱动异常）才退回 `gdigrab`。

编码参数：H.264 Main / yuv420p / SAR 1:1；屏幕 1920×1080 @ 25 fps 5 Mbps，摄像头
1280×720 @ 25 fps 2.5 Mbps；GOP 50 帧（2 秒一个关键帧，方便 CDS 切 reaction 片段）。

### 与同类方案的关系

这套东西不是新发明，ICPC 自己在 World Finals 就是这么做的：官方
[Coach View 文档](https://tools.icpc.global/docs/CoachView.pdf) 的附录写明，每台选手机跑两个
VLC 实例，桌面推到 `9090`、摄像头推到 `8080`，输出都是 `http{mux=ts}`；WF 镜像再把这两条命令
包成 systemd 服务（`vlc-desktop` / `vlc-camera`，`Restart=always`）。本工具沿用同一架构，
差异集中在 Windows 侧：

| 方案 | 抓屏 / 编码 | 分发 | 适用场景 |
|---|---|---|---|
| ICPC WF（官方文档 + Linux 镜像） | VLC `screen://` / v4l2 | VLC `http{mux=ts}` | Linux，systemd 托管 |
| **本工具包** | ffmpeg（`ddagrab` / `dshow`） | VLC `http{mux=ts}` | Windows，无 systemd |
| [hydro-dev/xcpc-tools](https://github.com/hydro-dev/xcpc-tools) | 不产生流，只消费流地址 | 代理 + 监控面板 | 国内 XCPC，配合选手机镜像 |
| [webrtc-grabber](https://github.com/irdkwmnsb/webrtc-grabber) | Electron 抓屏 / 摄像头 | WebRTC + SFU relay | 给人看低延迟画面，不是给 CDS |
| MediaMTX / SRS / nginx-rtmp | 不抓屏 | RTMP / HLS / WebRTC | 通用流服务器；输出不是 CDS 要的裸 HTTP-TS |

为什么不直接用 VLC 抓屏：Windows 上 `screen://` 走 GDI，慢且会让本机鼠标闪，也没有
`ddagrab` 与编码器选择。所以这里把「抓 + 编」交给 ffmpeg，只保留 VLC 的 HTTP 分发
（`fallback-vlc-screen.bat` 保留了纯 VLC 的老路子，作为兜底）。

## 环境要求

| 项 | 要求 |
|---|---|
| 操作系统 | Windows 10 1809+ / Windows 11（x64）。抓屏依赖 `ddagrab` / `gdigrab`，摄像头依赖 DirectShow |
| PowerShell | 5.1（系统自带，无需安装） |
| 磁盘 | 约 410 MB（ffmpeg 218 MB + VLC 189 MB + 脚本） |
| 权限 | 仅 `install.bat` / `uninstall.bat` 里的防火墙部分需要管理员；推流本身不需要 |
| 会话 | 必须是**已登录的交互式桌面**，锁屏、RDP 断开即断流 |
| 网络 | 与 CDS / 导播机同网段，TCP 9090、9092 可达 |

## 快速开始

### 1. 获取文件

**方式 A：git clone（推荐，仓库不含二进制）**

```powershell
git clone https://github.com/<you>/XCPC-Stream-Kit.git
cd XCPC-Stream-Kit
powershell -ExecutionPolicy Bypass -File .\fetch-deps.ps1
```

`fetch-deps.ps1` 把 ffmpeg 与 VLC 便携版下载到 `bin\`（约 410 MB），**不安装到系统里**。
版本号是脚本参数（默认 ffmpeg 9.0.2 / VLC 3.0.24），换版本改默认值或用 `-Force` 重下。

**方式 B：离线包**

现场没有外网时，先在一台能上网的机器上跑完 `fetch-deps.ps1`，再把整个文件夹（含 `bin\`）
拷进镜像 / 母盘。

> 建议放在 `D:\XCPC-Stream-Kit` 或 `C:\XCPC-Stream-Kit`：纯英文路径，不要放中文目录，
> 不要直接在 U 盘上运行。

### 2. 改配置（可选）

按需修改 `config.bat`（端口 / 分辨率 / 码率 / 编码器 / 麦克风）。**默认值可直接使用。**

### 3. 安装

右键 `install.bat` → **以管理员身份运行**。它会依次：

1. 在「启动」文件夹创建快捷方式（登录后静默启动两路流）；
2. 放行入站 TCP 9090 / 9092（非管理员会自动跳过）；
3. 立刻静默启动一次并跑自检。

之后每次登录都会在后台推流，**没有任何窗口**。

### 4. 只想临时跑一次

```
双击 start-silent.vbs      ← 静默启动，双击后没有反应是正常的
双击 status.bat            ← 确认是否真的推起来了
双击 stop.bat              ← 停
```

> `start-silent.vbs` 不会弹任何提示。确认方式：跑 `status.bat`，`[streams]` 两行都是 `OK`。
> 如果 `bin\` 缺文件，它会弹错误框提示先跑 `fetch-deps.ps1`，不会静默失败。

## 命令一览

| 文件 | 作用 | 备注 |
|---|---|---|
| `config.bat` | 配置：端口、分辨率、码率、编码器、麦克风 | 改完需 `stop.bat` → 重新启动 |
| `fetch-deps.ps1` | 下载 ffmpeg + VLC 便携版到 `bin\` | `-Force` 强制重下，`-FfmpegVersion` / `-VlcVersion` 指定版本 |
| `install.bat` | 安装：自启 + 防火墙 + 立即启动 + 自检 | 建议管理员运行，支持 `/q` |
| `uninstall.bat` | 卸载：停流 + 删自启 + 删防火墙规则 | 不删文件夹，支持 `/q` |
| `start-silent.vbs` | 静默启动两路流（自启调用的就是它） | 无窗口 |
| `start-debug.bat` | 调试启动：两路各开一个控制台看实时输出 | 关窗口即停该路 |
| `stop.bat` | 停止两路流及其重连循环 | 只杀本文件夹内的进程，支持 `/q` |
| `status.bat` | 自检：进程 / 端口 / 真拉一段 TS / 日志尾部 | 支持 `/q` |
| `list-cameras.bat` | 列出 DirectShow 摄像头与麦克风设备名 | 支持 `/q` |
| `fallback-vlc-screen.bat` | 备用：只用 VLC 抓屏（ffmpeg 抓屏不可用时） | 不要与 `stream_screen.bat` 同跑 |

`status.bat` / `stop.bat` / `install.bat` / `uninstall.bat` / `list-cameras.bat` 都支持
两种写法：`xxx.bat /q` 或 `set XCPC_NOPAUSE=1`。（`start-debug.bat` 例外，它需要窗口保持打开。）

## 配置

`config.bat` 里可改的变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `SCREEN_PORT` / `CAM_PORT` | `9090` / `9092` | 端口，改了 CDS 侧也要改 |
| `BIND_ADDR` | `0.0.0.0` | 允许外部拉流；`127.0.0.1` 只有本机能看 |
| `ADVERTISE_IP` | `auto` | 对外展示/写进 CDS 的 IP。`auto` = 走默认路由、metric 最低的那块网卡；多网卡时可写死 |
| `SCREEN_W` / `SCREEN_H` | `1920` / `1080` | `W/H` 强制尺寸；`0/0` 原始分辨率；`0/H` 或 `W/0` 等比缩放到该边 |
| `SCREEN_FPS` / `SCREEN_BITRATE` | `25` / `5000` | 屏幕帧率与码率（kbps） |
| `DRAW_MOUSE` | `1` | 画面里是否画鼠标指针 |
| `SCREEN_CAPTURE` | `auto` | `auto` / `dda`（桌面复制）/ `gdi`（老式 GDI）。**默认别动** |
| `SCREEN_OUTPUT` | `0` | dda 抓第几个显示器，0 = 主屏；gdi 抓全部显示器拼接 |
| `SCREEN_COLOR_FIX` | `auto` | `auto` / `on` / `off`，见[常见问题 → 画面](#画面) |
| `SCREEN_GAMMA` | `2.2` | 补偿用的 gamma |
| `CAMERA_DEVICE` | `auto` | `auto` = 自动找第一路摄像头；也可写死设备名 |
| `CAM_W` / `CAM_H` / `CAM_FPS` / `CAM_BITRATE` | `1280` / `720` / `25` / `2500` | 摄像头参数 |
| `AUDIO_DEVICE` | `none` | 麦克风设备名；**推荐保持 none**，否则会收进全场噪音 |
| `AUDIO_BITRATE` | `128` | 音频码率（kbps） |
| `ENCODER` | `libx264` | 也可用 `h264_qsv`（Intel 核显）、`h264_nvenc`（NVIDIA） |
| `PRESET` / `X264_TUNE` | `veryfast` / `zerolatency` | 关 B 帧与前瞻，直播延迟最低 |
| `KEYINT` | `50` | 关键帧间隔（帧），25 fps 下 = 2 秒 |
| `RESTART_DELAY` | `5` | 断流后重连间隔（秒） |
| `LOGLEVEL` | `warning` | 排查问题可改 `info`（很啰嗦） |

## 接入 CDS

选手机的流地址每次启动都会写进 `logs\prep.log`，也可以直接跑 `status.bat` 看。
默认取的是**有默认网关、接口 metric 最低**那块网卡的地址，装了 VMware / Hyper-V / WSL 的
机器不会取到虚拟网卡。

编辑 CDS 的 `usr\servers\cds\config\cdsConfig.xml`：

```xml
<video desktop="http://192.168.10.21:9090/" desktopMode="lazy"
       webcam="http://192.168.10.21:9092/" webcamMode="lazy"/>
```

- 不写 `id` = 对所有队伍生效；`id="3"` = 只对 3 号队；
- 24 台机器就是 24 条 `<video>`，或用 `{0}` / `{host}` 按队伍号拼；
- **改完必须重启 CDS**，热加载不会重建流注册表；
- 排查单个地址：在 CDS 机器上用 VLC 打开 `http://192.168.10.21:9090/`，能出画面就说明推流侧没问题。

## 验证

运行 `status.bat`，正常输出如下：

```
=== XCPC-Stream-Kit status ===
base : D:\XCPC-Stream-Kit

[processes]
  ffmpeg   pid=5748   cpu=41.9     up=00:00:39
  ffmpeg   pid=23532  cpu=18.5     up=00:00:38
  vlc      pid=57380  cpu=0.3      up=00:00:38
  vlc      pid=58256  cpu=0.7      up=00:00:39

[streams]
  screen  tcp/9090  OK: MPEG-TS, 16487 bytes, sync byte 0x47
  camera  tcp/9092  OK: MPEG-TS, 16487 bytes, sync byte 0x47
```

- `OK` 表示**真的连上去拉了一段数据并校验到 TS 同步字节 0x47**，不是只看端口在不在。
- `FAIL` 往下看 `[logs]`，或直接看 `logs\screen.log` / `logs\camera.log`。
- `up=` 超过一天显示为 `1d 03:20:15`。

## 常见问题

### 拉流与网络

**CDS 拉不到流，但本机 `status.bat` 是 OK**
防火墙。以管理员身份重跑 `install.bat`，或手动放行入站 TCP 9090 / 9092。
全新机器第一次监听端口时 Windows 会弹「是否允许访问网络」，静默启动看不到这个弹窗，
所以建议用 `install.bat` 里的 `netsh` 规则先放行。

**提示 `already in use` / 端口被占用**
说明已经有一路在跑，脚本直接退出、不抢端口。启动时会连查两次端口（间隔 3 秒），
快速双击也不会双开。真需要重启就先 `stop.bat`。查占用者：`netstat -ano | findstr :9090`。

**`stop.bat` 之后直接双击 `scripts\stream_screen.bat` 没反应**
`stop.bat` 会留下 `STOP.flag`，只有 `prep.bat`（`start-silent.vbs` / `start-debug.bat` /
`install.bat` 会调用）才清掉它。这是为了防止「刚停掉又被重连循环拉起来」。

**能不能做成「无论是否登录都运行」的计划任务或服务？**
不行。抓屏必须在已登录的交互式会话里跑。正确做法是让选手机自动登录，自启快捷方式在
登录后拉起。

### 画面

**黑屏 / 只有一帧 / 一断一断**
桌面被锁屏（Win+L）、切到别的用户会话、或 RDP 断开。抓屏抓的是当前交互式桌面，锁屏抓不到，
脚本只会一直重连。比赛时在电源计划里关掉休眠与屏保。

**画面比例不对**
选手机是 16:10 等其它比例时会按配置拉伸到 1920×1080。想保持比例：`SCREEN_W=0` 且
`SCREEN_H=1080`（等比缩到高 1080），或两个都设 0 用原始分辨率。

**一启动推流，本机鼠标指针开始闪（不是流里，是本机屏幕）**
不是负载问题，是抓屏方式。`SCREEN_CAPTURE=auto` 已经优先用 `dda`，正常不会闪；
日志里 `capture = gdi` 或手动设成 `gdi` 才会出现——`gdigrab` 的 `CAPTUREBLT` 会强制 DWM
在每次抓屏时把光标重绘到桌面 DC，25 fps 就是每秒 25 次重绘。改成 `auto` / `dda` 即可；
只有 `dda` 探测失败（虚拟机、老系统、D3D11 驱动异常）时才需要容忍它。

**画面偏暗、对比度差、暗部糊成一片**
Windows 11 的「自动颜色管理（ACM）」导致：ACM 开着时 DWM 在线性光空间合成，`ddagrab`
会把线性值当 sRGB 交出来，画面暗一大截，而显示器上看是正常的。

`SCREEN_COLOR_FIX=auto` 会自动处理：启动时各抓一帧对比亮度，dda 明显偏暗（低于 GDI 参照的
70%）才做一次反向传递函数补偿，日志记为 `colour = gamma_fix=1`；没开 ACM 的机器记为
`gamma_fix=0`，不会被误调。判断失误时可手动指定：画面暗 → `on`，发灰发白（补偿过头）→ `off`。

更彻底的做法是关掉 ACM：**设置 → 系统 → 显示 → 高级显示 → 自动管理颜色**。
批量部署且机型统一时，关 ACM 比逐台调 gamma 靠谱。

**日志里 `not enough frames to estimate rate; consider increasing probesize`**
只在 `SCREEN_CAPTURE=gdi` 时出现，`gdigrab` 启动时的正常提示，不影响推流。

### 摄像头

**`[streams] camera FAIL`，日志里没有摄像头**
先跑 `list-cameras.bat` 确认系统是否认得。常见原因：被腾讯会议 / OBS / 浏览器占着，
或驱动没装好。脚本每 15 秒重试，**连续失败 3 次后重新探测设备**，所以拔掉 A 插上 B
也能自动恢复，不用重启脚本。

**摄像头有画面但经常 FAIL，`list-cameras.bat` 里名字是中文**
脚本优先用 ffmpeg 给出的 `@device_pnp_...` 别名（纯 ASCII），中文名不会出问题。只有设备
**没有**别名时才退回友好名，此时能否使用取决于控制台代码页。稳妥做法：把 `list-cameras.bat`
里那行 `@device_pnp_...` 整行复制进 `config.bat` 的 `CAMERA_DEVICE=`，写死它。

### 性能

**CPU 太高**
1080p25 + 720p25 的 libx264 veryfast 约吃 1.5–2 个核。老机器可把 `SCREEN_FPS` 降到 15、
`SCREEN_BITRATE` 降到 3000，或把 `ENCODER` 改成 `h264_qsv`（Intel 核显，CPU 占用几乎为零）。

### 日志与退出码

**日志里 ffmpeg 报 `Error submitting a packet to the muxer: Invalid argument` / `-22`**
含义是**管道读端已关闭**（Windows 上往断开的管道写就是 EINVAL），不是编码参数问题。

先看日志末尾有没有停止标记：

```
[2026/11/23 21:04:11] ===== stopped on purpose by stop.bat =====
```

有就是正常现象——VLC 被杀、管道断开，ffmpeg 必然报这一句，不用管。

没有这个标记才说明 VLC 自己先退了。VLC 没有用 `--quiet`，真实原因在 `logs\*-vlc.log`，
`screen.log` / `camera.log` 里同时有 `vlc exited with code N`。常见原因：

- VLC 目录不完整（缺 `plugins\`）→ 重跑 `fetch-deps.ps1 -Force`
- `*-vlc.log` 里 `playlist is empty` → stdin 管道没建立，通常是安全软件拦了子进程管道
- 端口被其它程序占着 → `netstat -ano | findstr :9090`

**批量跑脚本时卡在「请按任意键继续」**
用 `xxx.bat /q` 或 `set XCPC_NOPAUSE=1`，对 `status.bat` / `stop.bat` / `install.bat` /
`uninstall.bat` / `list-cameras.bat` 都有效。

### 部署

**机器有线和无线都有 IP，`prep.bat` 打印的不是我要的那个**
默认取「有默认路由 + 接口 metric 最低」的网卡，虚拟网卡会被排到后面。`logs\prep.log` 里
有一行 `candidate:` 列出全部候选与 metric，照那个挑。要写死就在 `config.bat` 里设
`ADVERTISE_IP=<你的IP>`。

## 安全说明

**这是一套零认证的局域网裸流。** 端口一放行，同网段任何人都能拉到选手的完整屏幕。

- 比赛网络必须与选手机隔离，只允许**导播机 / CDS 机**访问 9090 / 9092 入站，
  不要把全部选手机放进能互访的大 VLAN。
- 不要把已设 `BIND_ADDR=0.0.0.0` 的端口映射到公网。
- VLC 的 HTTP 输出没有密码、没有 Token，也不打算加：需要鉴权请在交换机 ACL 或 CDS 侧解决。

## 批量部署

1. 在一台机器上把 `config.bat` 调好（端口、分辨率、码率定死，24 台参数一致，
   这样 OBS 里各队画面比例完全相同，不用逐台调整）。
2. 在这台机器上跑完 `fetch-deps.ps1`，整个文件夹（约 410 MB）进镜像 / 母盘，不要 U 盘现拷。
3. 每台机器以管理员身份跑一次 `install.bat`（或写进部署脚本用 `install.bat /q`）。
4. 每台机器 IP 必须固定（DHCP 保留或静态），否则 `cdsConfig.xml` 一改就全乱。
5. 收工：`uninstall.bat`，或先 `stop.bat` 再删文件夹。

## 日志

`logs\` 下全部是纯文本，记事本可直接打开：

| 文件 | 内容 |
|---|---|
| `prep.log` | 每次启动的本机 IP、流地址、工具路径、所有候选网卡（超过 256 KB 自动清空重来） |
| `screen.log` | 屏幕流的 ffmpeg 输出、VLC 退出码、重连记录 |
| `screen-vlc.log` | 屏幕流 VLC 输出（正常时只有几行启动信息） |
| `camera.log` | 摄像头流的 ffmpeg 输出、探测到的设备、VLC 退出码、重连记录 |
| `camera-vlc.log` | 摄像头流 VLC 输出 |
| `screen-fallback.log` | 备用 VLC 抓屏脚本的日志 |

`screen.log` / `camera.log` 每次启动时清空重写，重连记录在同一次运行内追加。
时间戳是纯 ASCII（`2026/11/23 21:04:11`），不会因系统语言变成乱码。

> 用记事本打开日志时，ffmpeg 的 `2>>log` 可能写失败。排查完记得关掉，否则会影响重连记录。

## 已知限制

- 仅支持 Windows：抓屏依赖 `ddagrab` / `gdigrab`，摄像头依赖 DirectShow。
- 只能抓**已登录的交互式桌面**，锁屏 / RDP 断开即断流。
- 单机双路（屏幕 + 1 路摄像头）；需要更多路就复制一份并改端口。
- 无鉴权，见[安全说明](#安全说明)。
- 只使用 `bin\` 内的便携二进制，不使用系统 PATH 里的 ffmpeg / VLC（避免版本不一致导致的问题）。

## 贡献

欢迎 issue 与 PR。提交前请遵守两条硬约束：

- **脚本必须纯 ASCII**（`.bat` / `.ps1` / `.vbs`）：中文注释在非 UTF-8 代码页下会被 cmd 拆行，
  导致整段执行失败。中文只写进 `README.md`。
- **换行必须 CRLF**：`.bat` 用 LF 会让 `goto :label` 在多行块里失效。仓库已用 `.gitattributes`
  钉死 `*.bat text eol=crlf`，请勿删除。

改完至少在真机上跑一遍：`prep.bat` → `start-debug.bat` → `status.bat`（两路都是 `OK`）→ `stop.bat`。

## 致谢

推流架构来自 ICPC 官方 [Coach View 文档](https://tools.icpc.global/docs/CoachView.pdf) 与
World Finals 镜像里的 systemd 服务；[hydro-dev/xcpc-tools](https://github.com/hydro-dev/xcpc-tools)
提供了国内 XCPC 监控侧的参考。感谢 VLC 与 ffmpeg 社区。

## 许可证

脚本部分采用 MIT，见 [LICENSE](LICENSE)。
运行时依赖 ffmpeg（GPLv3）与 VLC（GPLv2+），由 `fetch-deps.ps1` 单独下载，不随仓库分发。
