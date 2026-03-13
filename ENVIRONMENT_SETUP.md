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

## 后端环境
后端参考：`backend/server/.env.example`

建议：
- 本地演示：`APP_ENV=development`
- 区域联调：`APP_ENV=development` 或 `staging`
- 正式上线：`APP_ENV=production`

当前后端策略：
- `APP_ENV=demo/development/test`：允许演示匹配候选池自动注册
- `APP_ENV=staging/production`：禁止演示匹配候选池自动注入，避免预发布或正式环境混入 demo 用户
