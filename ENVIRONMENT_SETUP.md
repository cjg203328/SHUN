# 环境说明

## 前端运行环境
项目支持 4 种环境，通过 Dart define 控制：

- `demo`：本地演示环境，允许本地 OTP fallback、模拟匹配池、模拟聊天回复
- `development`：联调开发环境，允许模拟匹配池，不允许本地 OTP 登录
- `staging`：预发布环境，不允许本地 fallback
- `production`：正式环境，不允许本地 fallback

默认规则：
- Debug 未传参时，默认 `demo`
- Release 未传参时，默认 `production`

## 推荐命令

### 本地演示
`flutter run --dart-define=SUNLIAO_APP_ENV=demo`

### 联调开发
`flutter run --dart-define=SUNLIAO_APP_ENV=development --dart-define=SUNLIAO_API_BASE_URL=https://你的域名/api/v1`

### 预发布/正式打包
`flutter build apk --release --dart-define=SUNLIAO_APP_ENV=production --dart-define=SUNLIAO_RELEASE_BUILD=true --dart-define=SUNLIAO_API_BASE_URL=https://你的域名/api/v1 --dart-define=SUNLIAO_MEDIA_BASE_URL=https://你的域名/media`

## 当前策略
- 日间主题已关闭，统一固定夜间主题
- 本地验证码 fallback 仅允许在 `demo` 环境
- 本地好友搜索演示目录仅允许在 `demo/development` 环境
- 模拟匹配池允许在 `demo/development` 环境
- 模拟聊天自动回复仅允许在 `demo` 环境

## Flutter 命令假死快排
- 当前仓库的 Flutter SDK 位于工作区外：`D:\flutter_windows_3.27.1-stable`
- 已确认的高频根因：
  - 沙箱内执行 `flutter.bat` 时，Flutter tool 可能无法写入 `D:\flutter_windows_3.27.1-stable\flutter\bin\cache\lockfile`
  - 中断过的 `flutter test` 可能残留 `dart` 进程，后续再次执行时表现成“长时间无输出 / 像卡死”
- 标准处理顺序：
  1. 先检查是否有残留进程：
     `Get-Process flutter,dart -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,StartTime`
  2. 如果有旧的 `dart` / `flutter` 进程，先清掉再继续：
     `Get-Process dart,flutter -ErrorAction SilentlyContinue | Stop-Process -Force`
     清完后要立刻再复查一次；中断过的 `flutter test` 有时会重新拉起新的 `dart` worker，不能默认“一次 Stop 就结束”
     如果想直接走仓库内固定恢复脚本，可在项目根目录执行：
     `powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  3. 只要是 `flutter test`、`flutter analyze`、`flutter build` 这类命令，第一次超时或无输出后，不要继续在沙箱内重试，直接切到沙箱外 / 提权执行
  4. 纯格式化优先走：
     `D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format ...`
  5. 优先跑“目标测试 + 目标 analyze”，不要一上来全量回归，避免把一次假死放大成整轮阻塞
- 本项目后续默认口径：
  - `flutter` 命令优先按“沙箱外执行”准备
  - 一旦出现 60 秒以上无新输出，立即转入上面的快排流程，不再原地空等
  - 每次中断长命令后，下一步先查 `dart/flutter` 残留进程

## 后端环境
后端参考：`backend/server/.env.example`

建议：
- 本地演示：`APP_ENV=development`
- 区域联调：`APP_ENV=development` 或 `staging`
- 正式上线：`APP_ENV=production`

当前后端策略：
- `APP_ENV=demo/development/test`：允许演示匹配候选池自动注册
- `APP_ENV=staging/production`：禁止演示匹配候选池自动注入，避免预发布或正式环境混入 demo 用户
