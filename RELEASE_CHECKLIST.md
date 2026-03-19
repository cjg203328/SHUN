# 瞬聊发布清单

## 1. 发布环境
- 确认后端正式环境可用，并提供 HTTPS `SUNLIAO_API_BASE_URL`
- 如图片走 CDN/对象存储，提供 `SUNLIAO_MEDIA_BASE_URL`
- 确认数据库、对象存储、WebSocket 网关已部署
- 确认正式环境账号短信验证码能力可用

## 2. Android 签名
- 复制 `flutter-app/android/key.properties.example` 为 `flutter-app/android/key.properties`
- 填入正式 keystore 信息
- 将 `build.bat` 中 `ALLOW_DEBUG_RELEASE_SIGNING` 改为 `false`
- 确认 `flutter-app/android/app/build.gradle` 未回退到 debug 签名

## 3. 构建产物
- APK 本地验证：`build.bat apk`
- AAB 上架包：`build.bat aab`
- 如需指定接口地址：先设置 `SUNLIAO_API_BASE_URL` 再打包

## 4. 核心验收
- 登录 / 退出登录 / 切换账号无串号
- 资料与设置可从后端拉取并保存
- 头像上传后重新请求 `/users/me` 可拿到最新 `avatarUrl`
- 好友申请、好友列表、拉黑恢复正常
- 通知中心可看到未读消息、好友申请、好友互关提醒
- 应用启动、登录、聊天发送、好友申请等关键行为已进入本地埋点队列
- 应用异常可进入本地错误采集入口，系  统通知开关会同步到推送占位状态  
- 匹配次数与会话创建正常
- 文本消息、图片消息、已读同步、重新进 入会话恢复正常
- 已配  置 `S  UNLIAO_MEDIA_BASE_URL` 时，远端图片消息可正常预览
- 断网、后端不可用时有合理降级表现

## 5. 上架前补充
- 替换正式应用图标、启动图、隐私政策链接
- 准备应用截图、应用描述、测试账号
- 接入正式推送 SDK、监控平台和服务端上报后再提交正式审核
是 