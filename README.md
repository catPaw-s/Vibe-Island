<div align="center">
  <h3 align="center">Vibe Island</h3>
  <p align="center">
    一款基于cmux中的claude-cli，codex-cli灵动岛工具
    <br />
    <br />
    <a href="https://github.com/catPaw-s/Vibe-Island/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/catPaw-s/Vibe-Island?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
    <a href="#" target="_blank" rel="noopener noreferrer">
      <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/catPaw-s/Vibe-Island/total?style=rounded&color=white&labelColor=000000">
    </a>
  </p>
</div>

> 本项目基于原始 [`claude-island`](https://github.com/farouqaldori/claude-island) 开发


## 功能特性

- **灵动岛 UI**：从 MacBook 刘海区域展开的动态浮层
- **实时会话监控**：实时追踪多个 Claude Code 会话
- **权限审批**：直接在灵动岛里允许或拒绝工具调用
- **聊天记录**：支持 Markdown 渲染的完整会话历史
- **自动初始化**：首次启动时自动安装 hooks

## 运行要求

- macOS 15.6+
- Claude Code CLI
- codex
- cmux

## 安装方式

可以直接下载最新 release，或从源码构建：

```bash
xcodebuild -scheme ClaudeIsland -configuration Release build
```

## 许可证

Apache 2.0
