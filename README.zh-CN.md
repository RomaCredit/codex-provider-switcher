# Codex Provider Switcher

[English](README.md)

Codex Provider Switcher 是一个 Windows 上的小工具，用于在 Codex Desktop 的官方 ChatGPT 订阅模式和 OpenAI 兼容第三方 API provider 之间一键切换。

当前默认第三方 provider 为 APIMaster：

```text
https://apimaster.ai/v1
```

它还会同步 Codex Desktop 的历史会话元数据，避免切换 provider 后项目侧边栏看不到旧对话。

## 语言

默认语言是英文。

使用中文输出：

```powershell
.\switch-codex-provider.ps1 status -Lang zh
```

使用中文菜单：

```bat
codex-provider-menu.zh-CN.bat
```

## 功能

- 切换到 APIMaster API key 模式
- 切回官方 ChatGPT 订阅配置
- 保存并复用官方配置和 APIMaster 认证
- 修复 Codex Desktop 项目侧边栏历史会话
- 同步 `state_5.sqlite` 和 `sessions/rollout-*.jsonl` 中的 `model_provider`
- 修复旧版本留下的 `\\?\` 工作目录路径前缀
- 修改 Codex Desktop 状态前自动备份
- 支持英文和中文 CLI/菜单输出，默认英文

## 适用环境

- Windows
- Codex Desktop
- PowerShell
- Python 3，可通过 `python` 在 `PATH` 中调用

Python 用于安全修改 Codex Desktop 的 SQLite 状态库和 JSONL 会话元数据。

## 快速开始

先完全退出 Codex Desktop，然后双击：

```bat
codex-provider-menu.bat
```

中文用户也可以双击：

```bat
codex-provider-menu.zh-CN.bat
```

英文菜单选项：

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
2. 运行菜单脚本
3. 选择目标 provider 模式
4. 等脚本完成
5. 重新打开 Codex Desktop

## 命令行用法

查看当前状态：

```powershell
.\switch-codex-provider.ps1 status
```

切换到 APIMaster。如果没有保存过 APIMaster key，脚本会提示输入：

```powershell
.\switch-codex-provider.ps1 apimaster
```

显式传入 key、模型和 base URL：

```powershell
.\switch-codex-provider.ps1 apimaster `
  -ApiKey "YOUR_APIMASTER_KEY" `
  -Model "gpt-5.5" `
  -BaseUrl "https://apimaster.ai/v1"
```

切回官方 ChatGPT 订阅配置：

```powershell
.\switch-codex-provider.ps1 official
```

只修复历史，不切换 provider：

```powershell
.\switch-codex-provider.ps1 repair-history
```

测试 APIMaster `/models`：

```powershell
.\switch-codex-provider.ps1 test
```

保存当前 Codex 配置和认证为官方配置：

```powershell
.\switch-codex-provider.ps1 save-official
```

使用非默认 Codex home 目录做测试：

```powershell
.\switch-codex-provider.ps1 status -CodexHome "D:\tmp\fake-codex-home"
```

## 它会修改什么

默认读写：

- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\auth.json`
- `%USERPROFILE%\.codex\.codex-global-state.json`
- `%USERPROFILE%\.codex\state_5.sqlite`
- `%USERPROFILE%\.codex\sessions\...\rollout-*.jsonl`

它不会删除对话内容。历史修复只更新 Codex Desktop 用来关联项目和 provider 的元数据。

## 备份

备份写入：

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

Codex Desktop 的项目侧边栏历史不只依赖会话文件本身，还可能使用：

- 全局项目提示：`.codex-global-state.json`
- SQLite 线程索引：`state_5.sqlite`
- JSONL 第一行会话元数据：`sessions/rollout-*.jsonl`

其中 `model_provider` 会影响侧边栏过滤或重建行为。如果只切换 `config.toml` 和 `auth.json`，旧会话仍可能停留在 `openai` 或 `custom` provider 下，于是切到 APIMaster 后项目里看不到旧对话。

本工具会把 provider 元数据同步到当前模式：

- APIMaster 模式：`apimaster`
- 官方订阅模式：`openai`

## 回滚

如需回滚，请完全退出 Codex Desktop，然后从以下目录手动恢复对应时间戳的备份：

```text
%USERPROFILE%\.codex\provider-switcher
```

## 安全说明

- API key 只保存在本机
- 不会上传文件
- 不会修改 Codex 安装目录
- 不会删除对话文件
- 修改 SQLite 和 JSONL 前会先备份

不要在公开 issue 中上传真实 `.codex` 文件。里面可能包含密钥或私有工作目录路径。

## 限制

- 仅支持 Windows 和 Codex Desktop
- Codex Desktop 内部状态结构可能随版本变化。如果未来升级后历史异常，请先运行 `repair-history`
- 官方订阅配置需要先在 Codex Desktop 中登录成功，然后运行 `save-official` 或至少从官方模式切换到 APIMaster 一次

## 开发

本项目没有构建步骤。

核心文件：

- `switch-codex-provider.ps1`
- `codex-provider-menu.bat`
- `codex-provider-menu.zh-CN.bat`

基本检查：

```powershell
.\switch-codex-provider.ps1 status
.\switch-codex-provider.ps1 status -Lang zh
```

## 许可证

MIT. See [LICENSE](LICENSE).
