# Jarvis Swift

> 一个原生 macOS、开源、模型自由、面向普通用户的 AI Computer Agent。
>
> **你只管说你想要什么，剩下的交给 Jarvis。**

## 项目定位

Jarvis Swift 不是一个模型，也不是一个模型中转站，更不是一个只会聊天的 AI 外壳。

它是一个原生 Swift/macOS AI Agent：让 AI 能够理解用户意图、观察屏幕、操作鼠标与键盘、处理文件、使用应用、验证结果，并在失败后继续尝试。

它的目标不是教用户如何操作电脑，而是让用户根本不需要学习这些操作。

> **如果一个完全不会使用电脑的人只需要说出自己的目标，Jarvis 就应该尽可能替他完成整个过程。**

这就是 Jarvis Swift 的核心产品标准。

---

## 核心产品哲学

### 1. 用户给意图，不给步骤

用户应该说：

> “把这个视频剪成一分钟。”

而不是：

> “打开某个菜单，然后点击某个按钮，再选择某个选项。”

Jarvis 负责理解目标、寻找路径并完成任务。

---

### 2. Zero Learning Curve

Jarvis 应该像普通 Mac App 一样简单。

用户不需要理解：

- Agent
- Tool Calling
- API
- Token
- Context Window
- GGUF
- MLX
- MCP
- Prompt Engineering

这些复杂性全部隐藏在产品内部。

默认体验应该接近一个普通 AI 客户端：打开、输入、执行。

---

### 3. Observe → Plan → Act → Verify → Recover

Jarvis 的核心 Agent 循环不是单纯输出答案，而是：

1. **Observe**：观察当前屏幕、应用和环境。
2. **Plan**：理解目标并规划下一步。
3. **Act**：执行鼠标、键盘、文件和应用操作。
4. **Verify**：观察操作结果，确认是否成功。
5. **Recover**：失败时重新观察、换路线、重试或恢复状态。

失败不应该轻易等于“任务失败”。

---

### 4. 用户拥有最终控制权

Jarvis 不应该擅自改变用户的意图。

涉及明显不可逆或高风险的操作时，应提供合理的确认机制；普通可逆操作则应尽量直接完成。

用户决定什么时候做、做什么、使用哪个模型、使用哪个 Provider，以及是否启用记忆和外部服务。

---

### 5. 最小提示，最大自由

Jarvis 不依赖一大坨系统提示词来强行规定模型应该成为谁。

默认 System Prompt 应该极其简单，原则上只提供完成 Agent 工作所必须的最低上下文，例如：

> You are Jarvis. Help the user complete the requested task using the available tools.

具体工具定义、当前系统状态、权限、任务状态和执行边界主要由 Jarvis Runtime 管理，而不是堆在 System Prompt 里。

用户不需要配置复杂 System Prompt。

高级用户可以自行修改或扩展，但默认体验应接近“没有 System Prompt”。

---

### 6. 模型自由，Jarvis 不当模型警察

Jarvis 不要求用户必须使用某一家模型。

用户可以自由选择：

- OpenAI
- Google
- Groq
- DeepSeek
- Anthropic
- 其他云服务
- OpenAI-compatible API
- 自建服务器
- 本地模型
- 任意兼容的第三方后端

**用户如果坚持接入一个不适合 Jarvis 的模型，也可以。**

Jarvis 不负责替用户判断模型聪不聪明、会不会看图、会不会听音频，或者模型是否适合作为完整 Agent。

可以在必要场景提供一次简单、明确的免责声明：

> 你选择的 AI 模型由你负责。Jarvis 不保证第三方模型支持视觉、音频、工具调用或其他能力。模型能力不足造成的功能异常，请自行承担。

之后不做强制模型审查，不做模型资格委员会，也不因为用户选错模型而强行替换模型。

> **你选什么模型是你的自由，模型出了什么问题也是你自己的责任。**

---

### 7. 不卖模型，不做代理，不做隐藏中转

Jarvis Swift 是纯开源应用，不应围绕模型 API 建立隐藏的中转收费生意。

Jarvis 不应该：

- 偷偷替用户更换模型
- 把高级模型请求转到廉价模型
- 强制引导用户使用 Jarvis 自己的模型中转站
- 通过隐藏代理抽取额外费用
- 把模型供应商的能力包装成 Jarvis 自己的“高级模型”再转售

用户自己的 API Key 就调用用户指定的 Provider。

用户自己的服务器就连接用户自己的 Endpoint。

本地模型就运行在用户自己的设备上。

Jarvis 的角色是 **客户端 + Agent Runtime + macOS 操作层**。

---

## 模型与后端系统

Jarvis Swift 需要支持丰富的本地和云端 AI 后端，并通过统一抽象层为 Agent 提供一致体验。

### 云端 / 远程 Provider

应支持官方 Provider 与通用接口，并允许扩展新的 Adapter，例如：

- OpenAI
- Google
- Groq
- DeepSeek
- Anthropic
- OpenAI-compatible API
- 自定义远程 API

### 本地后端

本地模型不应成为“只能聊天”的二等公民。

在模型和运行时能力允许的前提下，应尽可能支持：

- MLX
- llama.cpp
- GGUF
- Ollama
- LM Studio
- MLC
- 其他本地或远程本地运行时

### 统一模型接口

Agent Core 不应直接依赖某一家 Provider。

示意接口：

```swift
protocol ModelBackend {
    var name: String { get }

    func models() async throws -> [Model]

    func chat(
        messages: [Message],
        attachments: [Attachment]
    ) async throws -> AsyncThrowingStream<Event, Error>

    func supports(_ capability: Capability) -> Bool
}
```

上层只处理统一的：

- Message
- Attachment
- Model
- Tool
- ToolCall
- Response
- StreamEvent
- Capability

Provider 的差异由 Adapter 层解决。

---

## API 与 Provider 自定义

Jarvis 不应该只提供几个固定厂商选项。

用户应能够添加自定义 Provider，并选择相应 API 类型、认证方式和 Endpoint。

目标是尽可能覆盖市场上实际存在的主流 API 结构和协议，并允许通过 Adapter/配置继续扩展。

示意：

```text
Add AI Provider

Provider Name
[ My Provider ]

API Type
[ OpenAI Compatible ]

Base URL
[ https://example.com/v1 ]

Authentication
[ API Key ]

Models
[ Auto Detect ]
```

核心思想：

> **只要服务愿意通过某种接口把模型能力交出来，Jarvis 就尽量让它能够被接入。**

---

## 搜索系统

搜索是 Jarvis 的可选增强能力，而不是强制依赖。

没有搜索 Provider 时，Jarvis 依然应该能够正常完成本地 Agent 工作。

当用户觉得模型自己操作浏览器搜索太慢时，可以接入独立的 Search Provider。

### Search Provider 同样采用 BYO（Bring Your Own）模式

用户自己选择搜索厂商、自己申请 API、自己承担搜索费用。

Jarvis 不提供强制的官方搜索中转，也不抽取隐藏费用。

示意：

```text
Jarvis
  ↓
Search Provider
  ↓
用户自己的 API / Endpoint
```

搜索 Provider 应与 Model Provider 保持类似的模块化设计。

以后可以扩展：

- Web Search
- News Search
- Image Search
- Deep Search
- 自定义搜索 API

搜索只是 Agent 可以调用的一种工具。

---

## 记忆系统

Jarvis 应拥有类似现代 AI 助手的长期记忆能力，同时进一步支持**所有对话之间的共享记忆与历史检索**。

### Global Memory

不同对话不是互相隔离的知识孤岛。

用户可以在一个对话中确定的项目规则、偏好、长期信息，在其他对话中继续使用。

```text
                 Global Memory
                       │
       ┌───────────────┼───────────────┐
       ↓               ↓               ↓
     Chat A          Chat B          Chat C
       │               │               │
       └───────────────┼───────────────┘
                       ↓
                Shared Context
```

### Global Context ≠ Full Context

Jarvis 不应该把所有历史聊天全文塞进当前模型上下文。

正确方式是：

```text
Current Task
    ↓
Memory Retrieval
    ↓
Relevant Memories / Conversations
    ↓
Compact Context
    ↓
Model
```

这样即使历史越来越多，也不会因为无休止地增加上下文而耗尽 Context Window。

### 三层存储

#### Conversation Store

保存完整历史对话。

#### Memory Store

保存长期、有价值的信息，例如：

- 用户偏好
- 长期项目决策
- 重要事实
- 长期任务

#### Retrieval Index

用于从历史对话和记忆中快速找到相关内容。

### 可关闭

记忆必须是用户可以自由控制的功能。

```text
Memory

● On
○ Off
```

关闭后：

- 不使用全局长期记忆
- 不向当前任务注入跨对话记忆
- 当前对话仍可以正常工作

同时提供：

- 查看记忆
- 删除单条记忆
- 清空全部记忆
- 暂停记忆

### 记忆独立于模型

记忆属于用户和 Jarvis 数据层，而不是属于某个模型。

今天使用 GPT，明天换 Gemini，后天换本地 Gemma，记忆依然存在。

> **模型可以换，记忆不能跟着模型一起消失。**

---

## UI / UX 设计哲学

Jarvis Swift 必须是一个真正的原生 macOS App，而不是网页套壳。

### 技术方向

- Swift
- SwiftUI
- 原生 macOS API
- Liquid Glass / 现代系统材质与层次

### 视觉语言

Jarvis 的默认设计方向：

> **Apple 式材质与空间感 + Google 式几何美感与动态交互 + Jarvis 自己的视觉人格**

重点包括：

- 半透明玻璃材质
- 清晰空间层级
- 圆形与圆角矩形
- 几何化 UI 元素
- 柔和阴影与高光
- 克制的动态效果
- 原生 macOS 排版

### 动态交互

动画不是装饰，而是交互反馈。

例如：

- Hover 时轻微浮起
- 点击时轻微压缩
- Focus 时出现柔和高光
- Agent 思考时有低干扰的状态动画
- 执行时有明确但克制的运行反馈
- 完成任务时有一次短促的成功反馈

核心原则：

> **UI 应该有生命，但不能喧宾夺主。**

### Motion Hierarchy

动画应该有层级：

1. 即时反馈：按钮、Hover、点击
2. 状态变化：启动、任务开始、完成
3. 环境动画：玻璃、背景、Agent 状态
4. 静态内容：文字、设置、列表

并支持系统的减少动态效果设置。

---

## 用户自定义视觉

Jarvis 的设计系统保持一致，但视觉个性由用户决定。

### Appearance

- 跟随系统
- 浅色
- 深色

### Accent Color

用户可以自由选择主要色彩：

- 蓝色
- 紫色
- 绿色
- 橙色
- 红色
- 粉色
- 黄色
- 自定义颜色
- 跟随系统强调色

主色应该自动驱动：

- Button
- Hover
- Focus Ring
- Glass Tint
- Glow
- Selection
- Agent State

这样用户只选择一个颜色，整个 Jarvis 视觉系统就能自然变化。

> **设计语言由 Jarvis 定义，视觉个性由用户决定。**

---

## 关于经典 Macintosh / 复古像素风

最终方案：**删除。**

Jarvis Swift 不采用 Macintosh 经典电脑造型、经典像素角色、复古 Mac UI 仿制或其他容易与 Apple 历史品牌视觉产生混淆的元素。

原因不是否定复古设计，而是 Jarvis 已经确定采用现代原生 macOS 视觉体系，没有必要为了复古彩蛋主动增加品牌相似性和法律风险。

Jarvis 应建立自己的视觉人格，而不是依赖 Macintosh 视觉符号。

---

## 默认用户体验

Jarvis 的核心体验应该接近现代 AI 客户端：

```text
打开 App
    ↓
看到极简主界面
    ↓
输入一句话
    ↓
Jarvis 理解任务
    ↓
观察屏幕 / 文件 / App
    ↓
执行
    ↓
验证
    ↓
完成
```

普通用户不需要：

- 学习快捷键
- 学习 Finder
- 理解 API
- 配置复杂 Prompt
- 手动管理 Agent 步骤
- 学习模型工程

---

## 示例

用户：

> 把桌面整理一下。

Jarvis：

```text
找到 23 个文件

我准备按类型整理到桌面文件夹。
```

然后执行：

```text
✓ 分析桌面
✓ 创建文件夹
✓ 移动文件
✓ 验证结果
✓ 完成
```

另一个例子：

用户：

> 打开 Final Cut，把刚才那个视频导进去。

Jarvis 应该能够：

```text
寻找视频
↓
打开 Final Cut
↓
等待应用启动
↓
识别导入入口
↓
选择文件
↓
导入
↓
检查素材是否出现
```

用户不应该需要告诉 Jarvis 每一步具体点什么。

---

## 隐私原则

Jarvis 要尊重用户设备和数据。

原则上：

- 能本地处理就优先本地处理
- 能只读取必要文件就不读取整个目录
- 能只截取必要窗口就不获取无关画面
- 明确告诉用户哪些数据会发送到外部 Provider
- 不偷偷上传与任务无关的数据
- 用户能够清理和导出自己的历史与记忆数据

尤其因为 Jarvis 能访问屏幕、文件和系统操作权限，隐私不是“以后再加”的功能，而是基础设计要求。

---

## 技术架构目标

```text
┌─────────────────────────────────────┐
│             Jarvis UI               │
│       SwiftUI / Liquid Glass        │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│            Jarvis Agent              │
│ Observe → Plan → Act → Verify       │
│                 → Recover            │
└──────────────────┬──────────────────┘
                   ↓
┌─────────────────────────────────────┐
│          Unified Model Layer         │
│           JarvisModelKit             │
└───────────────┬─────────┬───────────┘
                │         │
          Cloud / Remote  Local
                │         │
       ┌────────┼─────┐   ├── MLX
       ↓        ↓     ↓   ├── llama.cpp
     OpenAI   Google  ...  ├── Ollama
                            ├── LM Studio
                            └── Others

┌─────────────────────────────────────┐
│         Jarvis Automation            │
│ Screen / Mouse / Keyboard / Files   │
│ Windows / Apps / Accessibility      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│          Jarvis Memory              │
│ Conversations / Memories / Index    │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│          Search Providers            │
│     User-owned APIs / Endpoints      │
└─────────────────────────────────────┘
```

---

## 推荐技术栈

```text
Language
Swift

UI
SwiftUI

Screen Capture
ScreenCaptureKit

Computer Control
Accessibility API
CGEvent

Files
Foundation / FileManager

Persistence
SwiftData

Networking
URLSession

Concurrency
async/await / Actors
```

最低系统版本与具体 Framework 采用情况以后根据实际实现阶段确定。

---

## 开源原则

Jarvis Swift 的开源不仅意味着公开源代码，也意味着尽量减少人为锁定。

用户应该能够：

- 自由选择模型
- 自由选择 Provider
- 自由使用本地模型
- 自由配置 API
- 自由关闭记忆
- 导出自己的数据
- 自托管自己的服务
- 扩展新的 Provider
- 扩展新的工具和 Agent 能力

> **Jarvis 的价值来自工具、执行能力和优秀体验，而不是通过锁死用户来创造收入。**

---

## 产品底线

Jarvis Swift 的核心底线：

1. **不要求用户学习电脑操作。**
2. **不要求用户理解 AI 工程。**
3. **不强制用户使用某一家模型。**
4. **不偷偷替换用户选择的模型。**
5. **不建立隐藏的模型中转收费生意。**
6. **不依赖巨型 System Prompt 驯化模型。**
7. **不把本地模型故意做成二等公民。**
8. **不把搜索做成强制付费入口。**
9. **记忆必须可关闭、可查看、可删除。**
10. **UI 必须是产品本身，而不是功能完成之后再补上的皮。**

---

## 最终愿景

Jarvis Swift 希望成为：

> **一个像普通 Mac App 一样简单，却能够真正操作整个 Mac 的开源 AI Agent。**

它不是某一家模型公司的客户端。

不是 API 中转站。

不是只能开发者使用的命令行工具。

也不是一个把复杂 AI 技术全部暴露给用户的“高级设置集合”。

它应该做到：

> **模型可以换，Provider 可以换，本地和云端可以换，搜索可以换，记忆可以关，界面可以个性化，但 Jarvis 的核心体验始终保持一致。**

最终目标：

# **让电脑学会理解人，而不是让人继续学习电脑。**

