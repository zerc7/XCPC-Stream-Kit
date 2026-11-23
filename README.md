# XCPC-Stream-Kit — 选手机屏幕 / 摄像头推流（Windows 免安装版）

> Windows 免安装的选手机双路推流工具包。ffmpeg 抓屏编码，VLC 分发 HTTP MPEG-TS，
> CDS / OBS / 浏览器可同时拉同一路流；双击安装，开机静默自启，断流自动重连。
>
> Zero-install dual-stream (screen + webcam) broadcaster for Windows contest PCs.
> ffmpeg captures and encodes, VLC serves HTTP MPEG-TS so CDS / OBS / a browser can
> pull the same stream without re-encoding. Silent autostart, auto-reconnect.

整个文件夹拷到选手机上，双击一次就静默后台推流。自带 ffmpeg 与便携版 VLC，
选手机上**不需要装任何东西**（不需要 Python、不需要装 VLC、不需要配置 PATH）。

设计参考 ICPC 官方 unicup 镜像里的 ansible / systemd 方案：

| unicup（Linux / systemd） | 本工具包（Windows） |
|---|---|
| `files/start-vlc-screen`（MODE=ffmpeg） | `scripts\stream_screen.bat` |
| `files/start-vlc-dualwebcam`（MODE=ffmpeg） | `scripts\stream_camera.bat` |
| `vlc-webcam-front/side.service`，`Restart=always` | 脚本里的自动重连循环（5s / 失败多了退到 15–30s） |
| `start-vlc-screen` 的 `MODE=vlc` | `fallback-vlc-screen.bat`（备用，仅 VLC 抓屏） |
| systemd 开机自启 | `install.bat` 在「启动」文件夹建快捷方式 → `start-silent.vbs` |
| systemd `EnvironmentFile` | `config.bat` |

原理和 unicup 一样：**ffmpeg 负责抓屏/采集 + H.264 编码，VLC 只负责把 MPEG-TS 用 HTTP 分发出去**。
这样 CDS、OBS、浏览器可以同时拉同一路流，不需要重复编码。

```
  ┌ 桌面 ── ffmpeg(ddagrab/gdigrab) ─┐
  │                                  ├─→ VLC HTTP :9090  →  http://<本机IP>:9090/
  │ 摄像头 ─ ffmpeg(dshow) ──────────┴─→ VLC HTTP :9092  →  http://<本机IP>:9092/
```

抓屏默认用 **Desktop Duplication API（ddagrab）**：直接读 DWM 合成后的画面，
不干扰系统光标（不会出现「一推流鼠标就闪」），CPU 也比老的 GDI 抓屏低一半。
老系统或驱动不支持时自动退回 `gdigrab`，日志里 `capture =` 会写明用的是哪个。

编码：H.264 Main / yuv420p / 25fps / SAR 1:1，屏幕 1920×1080 5 Mbps，摄像头 1280×720 2.5 Mbps，
GOP 50 帧（2 秒一个关键帧，方便 CDS 切 reaction 片段）。

---

## 一、三步上手

### 1. 拿到文件

**方式 A：git clone（推荐，仓库里不含二进制）**

```powershell
git clone https://github.com/<you>/XCPC-Stream-Kit.git
cd XCPC-Stream-Kit
powershell -ExecutionPolicy Bypass -File .\fetch-deps.ps1
```

`fetch-deps.ps1` 会把 ffmpeg 与 VLC 便携版下载到 `bin\`（约 400 MB），
**不装到系统里**，删文件夹即彻底清除。版本号写在脚本参数里，需要换版本直接改默认值。

**方式 B：离线包**

比赛现场没有外网时，在一台能上网的机器上跑完 `fetch-deps.ps1`，把整个文件夹
（含 `bin\`）拷进镜像 / 母盘。约 410 MB，主要是 ffmpeg 218 MB + VLC 189 MB。

> 建议放在 `D:\XCPC-Stream-Kit` 或 `C:\XCPC-Stream-Kit`（纯英文路径，
> 别放中文目录、别用 U 盘直接跑）。

### 2. 改配置（可选）

需要的话改 `config.bat`（端口 / 分辨率 / 码率 / 编码器 / 麦克风）。**不改也能直接用。**

### 3. 安装

右键 `install.bat` → **以管理员身份运行**。

`install.bat` 会做三件事：建开机自启快捷方式 → 放行防火墙两个端口 → 立刻静默启动一次并自检。
装完之后每次登录都会自动在后台推流，**没有任何窗口**。

只想临时跑一次、不想装自启：

```
双击 start-silent.vbs      ← 静默启动（无窗口），双击后没有反应是正常的
双击 status.bat            ← 看是否真的推起来了
双击 stop.bat              ← 停
```

> 双击 `start-silent.vbs` 后屏幕不会有任何提示，这是设计如此。确认方式：跑 `status.bat`，
> `[streams]` 两行都出现 `OK` 就对了。
>
> 如果 `bin\` 里缺东西，`start-silent.vbs` 会弹一个错误框告诉你先跑 `fetch-deps.ps1`，
> 不会静默失败。

---

## 二、目录说明

```
XCPC-Stream-Kit\
├─ fetch-deps.ps1         下载 ffmpeg + VLC 便携版到 bin\（仓库不含二进制）
├─ install.bat            安装：开机自启 + 防火墙 + 立即启动 + 自检（建议管理员运行）
├─ uninstall.bat          卸载：停推流 + 删自启 + 删防火墙规则
├─ start-silent.vbs       ★ 静默启动两路推流（开机自启调的就是它）
├─ start-debug.bat        调试启动：两路各开一个黑窗口，能看到实时输出
├─ stop.bat               停止（只停本文件夹里的 ffmpeg / vlc，不影响你自己的 VLC）
├─ status.bat             自检：进程 / 端口 / 是否真能拉出 TS / 日志尾部
├─ list-cameras.bat       列出摄像头与麦克风设备名
├─ fallback-vlc-screen.bat 备用：只用 VLC 抓屏（ffmpeg 抓屏不行时才用）
├─ config.bat             ★ 配置文件
├─ scripts\               内部脚本（不要单独改）
│  ├─ _common.bat         路径 / 配置 / 找 ffmpeg 与 VLC
│  ├─ prep.bat            启动前准备（清标志、生成 VLC 插件缓存、打印本机 IP）
│  ├─ stream_screen.bat   屏幕流
│  ├─ stream_camera.bat   摄像头流
│  ├─ detect_camera.ps1   自动探测摄像头
│  ├─ detect_color.ps1    ACM 发暗探测
│  ├─ detect_ip.ps1       本机对外 IP（走路由表，排除虚拟网卡）
│  ├─ status.ps1 / stop.ps1 / install.ps1 / uninstall.ps1
├─ bin\                   fetch-deps.ps1 生成，不进仓库
│  ├─ ffmpeg.exe          ffmpeg static build
│  └─ vlc\                VLC 便携版，解压即用
└─ logs\                  运行日志（自动创建）
```

全部脚本都是**纯 ASCII**（中文在这个代码页里会被 cmd 拆行，会整段执行失败）。
中文只在本文档里。所以日志是英文的。

---

## 三、接到 CDS 上

选手机的 IP 和流地址，`prep.bat` 每次启动都会写进 `logs\prep.log`，也可以直接跑 `status.bat` 看。
（`prep.bat` 取的是**有默认网关那块网卡**的地址，装了 VMware / Hyper-V 的机器也不会取到虚拟网卡。）

CDS 的 `usr\servers\cds\config\cdsConfig.xml`：

```xml
<video desktop="http://192.168.10.21:9090/" desktopMode="lazy"
       webcam="http://192.168.10.21:9092/" webcamMode="lazy"/>
```

- 不写 `id` = 对所有队伍生效；`id="3"` = 只对 3 号队。
- 24 台机器就是 24 条 `<video>`，或者用 `{0}` / `{host}` 按队伍号拼。
- **改完必须重启 CDS**，热加载不会重建流注册表。
- 想确认某台机器通不通，在 CDS 机器上直接播 `http://192.168.10.21:9090/`，能出画面就说明推流没问题。

---

## 四、config.bat 里能改什么

| 变量 | 默认 | 说明 |
|---|---|---|
| `SCREEN_PORT` / `CAM_PORT` | 9090 / 9092 | 端口，改了 CDS 也要改 |
| `BIND_ADDR` | 0.0.0.0 | 允许外部拉流；填 127.0.0.1 只有本机能看 |
| `SCREEN_W` / `SCREEN_H` | 1920 / 1080 | `0/0` = 桌面原始分辨率；`0/H` 或 `W/0` = 保持比例缩放到该边；`W/H` = 强制该尺寸（奇数宽高会自动修正） |
| `SCREEN_FPS` / `SCREEN_BITRATE` | 25 / 5000 | 屏幕帧率、码率(kbps) |
| `DRAW_MOUSE` | 1 | 画面里是否画鼠标指针 |
| `SCREEN_CAPTURE` | auto | 抓屏方式：`auto` / `dda`（桌面复制 API）/ `gdi`（老式 GDI）。**默认别动**，见第六节第 7 条 |
| `SCREEN_OUTPUT` | 0 | `dda` 抓第几个显示器，0 = 主屏。`gdi` 会抓全部显示器拼接 |
| `SCREEN_COLOR_FIX` | auto | 画面发暗的自动补偿：`auto` / `on` / `off`，见第六节第 8 条 |
| `SCREEN_GAMMA` | 2.2 | 补偿用的 gamma，默认 2.2 一般不用改 |
| `CAMERA_DEVICE` | auto | auto = 自动找第一路摄像头；也可写死设备名 |
| `CAM_W` / `CAM_H` / `CAM_FPS` / `CAM_BITRATE` | 1280/720/25/2500 | 摄像头参数 |
| `AUDIO_DEVICE` | none | 麦克风；**推荐保持 none**，否则会收全场噪音 |
| `ENCODER` | libx264 | 也可以 `h264_qsv`（Intel 核显）或 `h264_nvenc`（NVIDIA） |
| `X264_TUNE` | zerolatency | 关 B 帧/前瞻，直播延迟最低 |
| `KEYINT` | 50 | 关键帧间隔（帧数），25fps 下 = 2 秒 |
| `RESTART_DELAY` | 5 | 断流后几秒重连 |
| `LOGLEVEL` | warning | 排查问题可改 info（很啰嗦） |

改完要 `stop.bat` → `start-silent.vbs` 才生效。

---

## 五、验证

```
双击 status.bat
```

正常输出：

```
[processes]
  ffmpeg   pid=5748   cpu=41.9   up=00:00:39
  ffmpeg   pid=23532  cpu=18.5   up=00:00:38
  vlc      pid=57380  cpu=0.3    up=00:00:38
  vlc      pid=58256  cpu=0.7    up=00:00:39

[streams]
  screen  tcp/9090  OK: MPEG-TS, 16487 bytes, sync byte 0x47
  camera  tcp/9092  OK: MPEG-TS, 16487 bytes, sync byte 0x47
```

- `[streams]` 的 `OK` 是**真的连上去拉了一段数据、并检查到 TS 同步字节 0x47**，不是只看端口。
- `FAIL` 就往下看 `[logs]`，或者看 `logs\camera.log` / `logs\screen.log`。
- 也可以拿 VLC「打开网络串流」输入 `http://127.0.0.1:9090/` 直接看画面。
- `up=` 超过一天会显示成 `1d 03:20:15`。

---

## 六、常见问题

**1. CDS 拉不到流，本机 status.bat 却是 OK**
防火墙。以管理员身份重跑 `install.bat`，或手动放行入站 TCP 9090 / 9092。
全新机器第一次监听端口时 Windows 会弹「是否允许访问网络」，静默运行是看不到这个弹窗的，
所以最好用 `install.bat` 里的 `netsh` 规则先把端口放行。

**2. `[streams] camera FAIL`，日志里没有摄像头**
先跑 `list-cameras.bat` 看系统认不认。常见原因：摄像头被腾讯会议 / OBS / 浏览器占着，
或者设备管理器里驱动没装好。脚本会每 15 秒重试，**连续失败 3 次后会重新探测设备**，
所以换一个摄像头（拔掉 A 插上 B）也能自动恢复，不用重启脚本。

**3. 日志里 `not enough frames to estimate rate; consider increasing probesize`**
只在 `SCREEN_CAPTURE=gdi` 时出现，gdigrab 启动时的正常提示，不影响推流，忽略即可。

**4. 黑屏 / 只有一帧 / 一断一断**
桌面被锁屏（Win+L）、或切到了别的用户会话、或 RDP 断开。抓屏抓的是**当前交互式桌面**，
锁屏状态下抓不到，脚本会一直重连。比赛时保持机器不锁屏（电源计划里关掉休眠和屏保）。

**5. 屏幕流正常但画面比例不对**
选手机如果是 16:10（1920×1200）之类，会按配置拉伸到 1920×1080。想保持比例就把
`SCREEN_W` 改成 0、`SCREEN_H` 保持 1080（等比缩放到高 1080），或者两个都改成 0 用原始分辨率。

**6. CPU 太高**
1080p25 + 720p25 的 libx264 veryfast 大约吃 1.5–2 个核。老机器可以降 `SCREEN_FPS` 到 15、
`SCREEN_BITRATE` 到 3000，或者把 `ENCODER` 改成 `h264_qsv`（Intel 核显，CPU 占用几乎为零）。

**7. 一启动推流，本机的鼠标指针就开始闪（不是流里，是本机屏幕）**
**不是负载问题**，跟 CPU 占用无关，是抓屏方式导致的。默认的 `SCREEN_CAPTURE=auto` 已经换成
桌面复制 API（`dda`），正常不会闪；如果日志里 `capture = gdi`，或者你手动改成了 `gdi`，就会出现：

- 原因是 GDI 抓屏走 `BitBlt` 并带 `CAPTUREBLT` 标志，这个标志强制 DWM 在每次抓屏时
  把光标重绘到桌面 DC 上。25fps 就是每秒 25 次重绘，肉眼看就是指针在闪。
- 解决：把 `config.bat` 里的 `SCREEN_CAPTURE` 改成 `auto`（或 `dda`），重启推流。
  `dda` 直接读 DWM 合成好的画面，完全不动系统光标层，顺带 CPU 还低一半
  （本机实测 gdigrab 约 115% 单核，ddagrab 约 77%）。
- 只有 `dda` 探测失败（Win8 以前的系统、虚拟机、D3D11 驱动异常）才会自动退回 `gdi`，
  这时闪烁属于抓屏方式的固有限制，不影响送出去的画面和评分，只是本地看着别扭。

**8. 拉到画面特别暗、对比度差、暗部糊成一片（屏幕本身看着完全正常）**
这是 Windows 11 的**自动颜色管理（ACM / 高级颜色）**造成的，不是编码或码率问题。
ACM 开着时 DWM 在线性光空间合成，桌面复制 API（ddagrab）会把**线性值**当成 sRGB 交出来，
于是抓到的画面暗一大截；而 GDI 抓屏、以及显示器上看到的都是正常的。

默认 `SCREEN_COLOR_FIX=auto` 会自动处理：启动时各抓一帧对比亮度，发现 dda 明显偏暗
（不到 GDI 参照的 70%）才加一次反向传递函数补偿，日志里记为 `colour = gamma_fix=1`。
没开 ACM 的机器不会被误调，记为 `gamma_fix=0`。

如果 `auto` 判断失误（比如启动瞬间屏幕是黑的），可以手动指定：

- 画面暗 → `config.bat` 里设 `SCREEN_COLOR_FIX=on`
- 画面发灰发白（补偿过头）→ 设 `SCREEN_COLOR_FIX=off`

更彻底的办法是直接关掉 ACM：**设置 → 系统 → 显示 → 高级显示 → 自动管理颜色，关掉**。
关掉后 dda 抓到的就是标准 sRGB，`SCREEN_COLOR_FIX=auto` 会自动不再补偿。
批量部署时如果所有机器都是同一型号，建议直接关 ACM，比逐台调 gamma 靠谱。

**9. 端口被占用 / 提示 `already in use`**
说明已经有一路在跑了，脚本直接退出，不抢端口。启动时会**连查两次端口（间隔 3 秒）**，
所以快速双击两次也不会双开。
真想重启就 `stop.bat` 再启动。查是谁占着：`netstat -ano | findstr :9090`。

**10. `stop.bat` 之后直接双击 `scripts\stream_screen.bat` 没反应**
`stop.bat` 会留一个 `STOP.flag`，只有 `prep.bat`（也就是 `start-silent.vbs` / `start-debug.bat` /
`install.bat`）会清掉它。这是为了防止「刚停掉又被重连循环拉起来」。正常从 `start-silent.vbs` 启动即可。

**11. 能不能做成「不管用户是否登录都运行」的计划任务 / 服务？**
不行。抓屏必须在**已登录的交互式会话**里跑。正确做法是让选手机自动登录，自启快捷方式在登录后拉起。

**12. 日志里 ffmpeg 报 `Error submitting a packet to the muxer: Invalid argument` / `-22`**
这个错误的意思是**管道读端已经关掉了**，不是编码或参数问题
（Windows 上往一个断开的管道写，ffmpeg 报的就是 EINVAL）。

先往下翻一行：如果是你自己按了 `stop.bat`，日志末尾会有

```
[2026/11/23 21:04:11] ===== stopped on purpose by stop.bat =====
```

那就是正常现象——VLC 被杀掉、管道断开，ffmpeg 必然报这一句，**不用管**。

如果**没有**这个标记就出现了，说明 VLC 自己先退出了。现在 VLC 不再用 `--quiet`，
它的真实原因会落在 `logs\*-vlc.log`，同时 `screen.log` / `camera.log` 里会多一行
`vlc exited with code N`。照这两处看即可，最常见的是：

- VLC 目录不完整（少 `plugins\`）→ 重跑 `fetch-deps.ps1 -Force`
- `logs\*-vlc.log` 里 `playlist is empty` → stdin 管道没建立，通常是被安全软件拦了子进程管道
- 端口被别的程序占着 → `netstat -ano | findstr :9090`

**13. 摄像头有画面但经常 `FAIL`，`list-cameras.bat` 里名字是中文**
脚本优先用 ffmpeg 给出的 `@device_pnp_...` 别名（纯 ASCII），中文名也不会出问题。
只有当设备**没有**别名时才会退回友好名，这时候名字能不能用取决于控制台代码页。
稳妥做法：把 `list-cameras.bat` 里那个 `@device_pnp_...` 整行复制进 `config.bat` 的
`CAMERA_DEVICE=`，写死它。

**14. 想批量跑 `status.bat` / `stop.bat` 但每次都卡在「请按任意键继续」**
两种方式都行：

```
status.bat /q
set XCPC_NOPAUSE=1 && status.bat
```

`/q` 和 `XCPC_NOPAUSE=1` 对 `status.bat` / `stop.bat` / `install.bat` / `uninstall.bat` /
`list-cameras.bat` 都有效。

**15. 机器有线和无线都有 IP，`prep.bat` 打印的不是我要的那个**
默认取「有默认路由 + 接口优先级最高」的那块网卡，虚拟网卡（VMware / Hyper-V / WSL）会被排除。
`logs\prep.log` 里有一行 `candidate:` 列出所有候选和它们的 metric，照那个挑。
要写死就在 `config.bat` 里设 `ADVERTISE_IP=<你的IP>`，之后 prep / status 都按它显示。

---

## 七、安全说明（重要）

**这一套是零认证的局域网裸流。** 端口一放行，同网段任何人都能拉到选手的完整屏幕。

- 比赛网络必须与选手机隔离，只允许**导播机 / CDS 机**访问 9090 / 9092 入站，
  不要把所有选手机都放进能互访的大 VLAN。
- 不要把 `BIND_ADDR` 改成 `0.0.0.0` 之后又把这些端口映射到公网。
- VLC 的 HTTP 输出没有密码、没有 Token，也不打算加——需要鉴权的话在交换机 ACL 或
  CDS 侧解决，不要指望这个工具。

---

## 八、批量部署建议

1. 在一台机器上先把 `config.bat` 改好（端口、分辨率、码率定死，24 台机器参数一致，
   这样 OBS 里各队画面比例完全一样，不用逐个调）。
2. 在这台机器上跑完 `fetch-deps.ps1`，然后整个文件夹（约 410 MB）进镜像 / 母盘，别用 U 盘现拷。
3. 每台机器右键 `install.bat` 以管理员身份跑一次（或写进部署脚本，用 `install.bat /q`）。
4. 收工：`uninstall.bat`，或者直接删文件夹（先 `stop.bat`）。
5. 每台机器 IP 要固定（DHCP 保留或静态），否则 `cdsConfig.xml` 一改就全乱。

---

## 九、日志在哪

`logs\` 下，全是纯文本，可以直接记事本打开：

| 文件 | 内容 |
|---|---|
| `prep.log` | 每次启动的本机 IP、流地址、工具路径（超过 256 KB 自动清掉重来） |
| `screen.log` | 屏幕流 ffmpeg 输出、VLC 退出码、重连记录 |
| `screen-vlc.log` | 屏幕流 VLC 输出（正常时有几行启动信息） |
| `camera.log` | 摄像头流 ffmpeg 输出、探测到的设备、VLC 退出码、重连记录 |
| `camera-vlc.log` | 摄像头流 VLC 输出 |
| `screen-fallback.log` | 备用 VLC 抓屏脚本的日志 |

`screen.log` / `camera.log` 在每次启动时会被清空重写；重连记录在同一次运行内追加。
时间戳是 ASCII（`2026/11/23 21:04:11`），不会因为系统语言变成乱码。

---

## 十、已知限制

- 只支持 Windows（抓屏依赖 ddagrab / gdigrab，摄像头依赖 DirectShow）。
- 只能抓**已登录的交互式桌面**，锁屏 / RDP 断开即断流。
- 单机双路（屏幕 + 1 路摄像头）；需要更多路就复制一份改端口。
- 没有鉴权，见第七节。

## License

脚本部分 MIT，见 `LICENSE`。运行时的 ffmpeg（GPLv3）与 VLC（GPLv2+）由 `fetch-deps.ps1`
单独下载，不随仓库分发。
