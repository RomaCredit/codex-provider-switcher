# Codex Provider Switcher

一个 Windows 上的 Codex Desktop provider 一键切换工具。

它可以在官方 ChatGPT 订阅模式和 OpenAI 兼容的第三方 API provider 之间切换，同时同步 Codex Desktop 的历史会话索引，避免切换后项目侧边栏看不到旧对话。

> 当前默认第三方 provider 为 APIMaster：`https://apimaster.ai/v1`。

## 功能

- 一键切换到 APIMaster API key 模式
- 一键切回官方 ChatGPT 订阅模式
- 自动保存官方配置和 APIMaster key
- 自动修复项目侧边栏历史会话
- 自动同步 `state_5.sqlite` 和 `sessions/rollout-*.jsonl` 里的 `model_provider`
- 自动修复旧版本留下的 `\\?\` 工作目录路径前缀
- 每次修改前自动备份关键状态文件

## 适用环境

- Windows
- Codex Desktop
- PowerShell
- Python 3，可在 `PATH` 中通过 `python` 调用

Python 用于安全修改 Codex Desktop 的 SQLite 状态库和 JSONL 会话元数据。

## 快速开始

下载或 clone 本项目后，双击：

```bat
codex-provider-menu.bat
```

菜单选项：

```text
1. Switch to APIMaster and sync history
2. Switch to official subscription and sync history
3. Show status
4. Test APIMaster /v1/models
5. Save current profile as official
6. Repair Desktop history list
0. Exit
```

推荐流程：

1. 完全退出 Codex Desktop
2. 双击 `codex-provider-menu.bat`
3. 选择要切换的模式
4. 等脚本完成
5. 重新打开 Codex Desktop

## 命令行用法

查看当前状态：

```powershell
.\switch-codex-provider.ps1 status
```

切换到 APIMaster。如果本机没有保存过 APIMaster key，脚本会提示输入：

```powershell
.\switch-codex-provider.ps1 apimaster
```

切换到 APIMaster，并显式传入 key、模型和 base URL：

```powershell
.\switch-codex-provider.ps1 apimaster `
  -ApiKey "YOUR_APIMASTER_KEY" `
  -Model "gpt-5.5" `
  -BaseUrl "https://apimaster.ai/v1"
```

切回官方 ChatGPT 订阅模式：

```powershell
.\switch-codex-provider.ps1 official
```

只修复历史会话列表，不切换 provider：

```powershell
.\switch-codex-provider.ps1 repair-history
```

测试 APIMaster `/models` 接口：

```powershell
.\switch-codex-provider.ps1 test
```

保存当前 Codex 配置和认证为“官方订阅配置”：

```powershell
.\switch-codex-provider.ps1 save-official
```

指定非默认 Codex home 目录，方便测试或排查：

```powershell
.\switch-codex-provider.ps1 status -CodexHome "D:\tmp\fake-codex-home"
```

## 它会修改什么

默认会读写：

- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\auth.json`
- `%USERPROFILE%\.codex\.codex-global-state.json`
- `%USERPROFILE%\.codex\state_5.sqlite`
- `%USERPROFILE%\.codex\sessions\...\rollout-*.jsonl`

它不会删除对话内容。历史同步只修改会话元数据里的 provider 和工作目录提示，让 Codex Desktop 在切换 provider 后仍能把旧线程归到当前项目下。

## 备份位置

所有备份都会写入：

```text
%USERPROFILE%\.codex\provider-switcher
```

常见备份文件：

- `config.<timestamp>.toml.bak`
- `auth.<timestamp>.json.bak`
- `global-state.<timestamp>.json.bak`
- `state_5.<timestamp>.sqlite.bak`
- `session-meta.<timestamp>.bak\...`

## 为什么需要同步历史

Codex Desktop 的项目侧边栏历史不是只看会话文件本身。它还会参考：

- 全局项目提示：`.codex-global-state.json`
- SQLite 线程索引：`state_5.sqlite`
- JSONL 第一行会话元数据：`sessions/rollout-*.jsonl`

其中 `model_provider` 会影响历史列表过滤或重建。只切换 `config.toml` 和 `auth.json` 时，旧会话仍可能停留在 `openai` 或 `custom` provider 下，于是切到 APIMaster 后项目里就看不到旧对话。

本工具会把这些元数据同步到当前 provider：

- APIMaster 模式：`apimaster`
- 官方订阅模式：`openai`

## 回滚

如果需要恢复，可以从 `%USERPROFILE%\.codex\provider-switcher` 找到对应时间戳的备份文件，手动复制回 `.codex` 目录。

建议在 Codex Desktop 完全退出时回滚。

## 安全说明

- API key 只保存在本机 `%USERPROFILE%\.codex\provider-switcher\apimaster.auth.json`
- 不会上传任何文件
- 不会修改 Codex 安装目录
- 不会删除会话内容
- 修改 SQLite 和 JSONL 前会先创建备份

## 限制

- 当前只面向 Windows 和 Codex Desktop
- Codex Desktop 内部状态结构可能随版本变化；如果升级后历史列表异常，请先运行 `repair-history`
- 官方订阅配置需要先在 Codex Desktop 中登录成功，再运行 `save-official` 或进行一次从官方到 APIMaster 的切换

## 开发

本项目没有构建步骤。核心文件：

- `switch-codex-provider.ps1`：切换和历史同步逻辑
- `codex-provider-menu.bat`：双击菜单入口

基本检查：

```powershell
.\switch-codex-provider.ps1 status
```

使用临时目录测试参数解析：

```powershell
.\switch-codex-provider.ps1 status -CodexHome "D:\tmp\fake-codex-home"
```

## 许可证

MIT. See [LICENSE](LICENSE).
