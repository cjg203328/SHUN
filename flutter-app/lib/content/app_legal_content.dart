enum LegalDocumentType {
  userAgreement,
  privacyPolicy,
}

class AppLegalContent {
  static LegalDocumentType? fromRouteParam(String? value) {
    switch (value) {
      case 'user-agreement':
        return LegalDocumentType.userAgreement;
      case 'privacy-policy':
        return LegalDocumentType.privacyPolicy;
      default:
        return null;
    }
  }

  static String routeParamOf(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.userAgreement:
        return 'user-agreement';
      case LegalDocumentType.privacyPolicy:
        return 'privacy-policy';
    }
  }

  static String titleOf(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.userAgreement:
        return '用户协议';
      case LegalDocumentType.privacyPolicy:
        return '隐私政策';
    }
  }

  static String contentOf(LegalDocumentType type) {
    switch (type) {
      case LegalDocumentType.userAgreement:
        return _userAgreement;
      case LegalDocumentType.privacyPolicy:
        return _privacyPolicy;
    }
  }

  static const String _userAgreement = '''
# 瞬用户协议

更新日期：2026年2月24日
生效日期：2026年2月24日

欢迎使用瞬！

## 1. 协议的接受

1.1 本协议是您与瞬（以下简称"我们"）之间关于您使用瞬服务所订立的协议。

1.2 在使用瞬服务前，请您务必仔细阅读并充分理解本协议。如果您不同意本协议的任何内容，请不要使用瞬服务。

## 2. 服务说明

2.1 瞬是一款24小时限时匿名社交应用，为用户提供随机匹配、即时聊天等服务。

2.2 所有对话将在24小时后自动消失（好友对话除外）。

2.3 我们保留随时修改或中断服务的权利。

## 3. 用户行为规范

3.1 您承诺不会利用瞬服务从事以下行为：
- 发布违法、暴力、色情、诈骗等不良信息
- 骚扰、威胁、侮辱他人
- 传播虚假信息
- 侵犯他人知识产权
- 其他违反法律法规的行为

3.2 如发现违规行为，我们有权采取警告、限制功能、封禁账号等措施。

## 4. 隐私保护

4.1 我们重视用户隐私保护，详见《隐私政策》。

4.2 您的聊天记录将在24小时后自动删除。

## 5. 免责声明

5.1 瞬仅提供信息交流平台，不对用户发布的内容负责。

5.2 因不可抗力导致的服务中断，我们不承担责任。

## 6. 协议修改

6.1 我们有权随时修改本协议，修改后的协议将在应用内公布。

6.2 继续使用服务即表示您接受修改后的协议。

## 7. 联系我们

如有任何问题，请通过应用内反馈功能联系我们。

---

瞬团队
2026年2月24日
''';

  static const String _privacyPolicy = '''
# 瞬隐私政策

更新日期：2026年2月24日
生效日期：2026年2月24日

瞬（以下简称"我们"）深知个人信息对您的重要性，我们将按照法律法规要求，采取相应安全保护措施，尽力保护您的个人信息安全可控。

## 1. 我们如何收集和使用您的个人信息

### 1.1 注册和登录
- 手机号码：用于账号注册和登录验证

### 1.2 匹配和聊天
- 位置信息：用于匹配附近的用户（每次使用时需要您确认）
- 聊天内容：用于提供即时通讯服务，24小时后自动删除

### 1.3 个人资料
- 昵称、头像、个人签名：用于展示个人信息

### 1.4 设备信息
- 设备型号、操作系统版本：用于优化应用性能

## 2. 我们如何使用Cookie等技术

2.1 我们使用本地存储技术保存您的登录状态和应用设置。

2.2 您可以通过清除应用数据来删除这些信息。

## 3. 我们如何共享、转让、公开披露您的个人信息

3.1 我们不会与第三方共享、转让您的个人信息，除非：
- 获得您的明确同意
- 法律法规要求
- 保护用户或公众的安全

3.2 我们不会公开披露您的个人信息。

## 4. 我们如何保护您的个人信息

4.1 我们采用行业标准的安全措施保护您的个人信息。

4.2 聊天记录采用端到端加密传输。

4.3 所有对话在24小时后自动删除。

## 5. 您的权利

5.1 您有权访问、更正、删除您的个人信息。

5.2 您有权注销账号，注销后所有数据将被永久删除。

5.3 您可以通过应用内设置管理权限。

## 6. 未成年人保护

6.1 我们不向18岁以下的未成年人提供服务。

6.2 如发现未成年人使用，我们将立即停止服务并删除相关信息。

## 7. 隐私政策的修改

7.1 我们可能适时修订本政策，修订后的政策将在应用内公布。

7.2 重大变更时，我们会通过显著方式通知您。

## 8. 联系我们

如对本政策有任何疑问，请通过应用内反馈功能联系我们。

---

瞬团队
2026年2月24日
''';
}
