# P3DE (Processing 3D Editor)

> **极致原生 · 高度集成 · 零门槛创作**
> 
> *A light-weight, modular 3D content creation engine & editor built on the Processing P3D environment.*

---

![P3DE Banner](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324233441993-831857617.jpg)

---

## 1. 项目愿景与技术操守 (Core Philosophy)

P3DE 旨在证明在 **Processing** 这一极简的 Java 艺术编程框架下，依然可以构建出具备工业级交互体验、高保真渲染及可视化逻辑编辑能力的闭环工具链。

### 🛡️ “原生态”构建一切 (Native Everything)
本项目最核心的技术底线是：**全过程未引用任何第三方插件或外部 Jar 包库**（如 ControlP5, PeasyCam, Rhino 等）。
- **自研 Gizmo 系统**：基于纯向量数学与射线检测 (Raycasting) 实现。
- **原生 UI 渲染**：利用 Processing 基本绘图指令逐像素绘制所有界面。
- **零依赖脚本引擎 (P3DES)**：自建异步执行与变量插值系统。
- **原生 PBR 着色器**：直接在 GLSL 层级编写 Cook-Torrance BRDF 数学模型。

---

## 2. 核心功能特性 (Feature Map)

### 🎮 3D 核心与交互驱动
- **专业级 Gizmo 操纵器**：支持平移、旋转、缩放。具备世界/局部坐标系实时切换（`L` 键）与 10 单位整格吸附（`G` 键）。
- **层级管理树 (Hierarchy)**：支持无限深度的父子连子变换与右键上下文操作。
- **撤回重做 (Undo/Redo)**：基于命令模式构建，覆盖所有核心编辑操作。

![Interaction Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231325839-208076832.jpg)

### ✨ 物理级高保真渲染 (PBR Pipeline)
- **GGX Cook-Torrance BRDF**：精准模拟金属度与粗糙度。
- **IBL (Image Based Lighting)**：支持 360 度环境图加载，提供真实的全球照明氛围。
- **材质属性面板**：集成捡色器与实时纹理通道控制。

### 🧠 视觉逻辑蓝图 (Visual Logic Blueprint - VLB)
- **双模所有权**：蓝图可挂载于“实体”或“关卡”，实现对象逻辑与全局控制。
- **转译引擎**：通过 DFS 算法将非线性节点流转译为可执行的 P3DES 指令，支持热重载 (Hot-Reload)。

![Blueprint Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231359524-995366937.jpg)

### 🐚 脚本引擎与终端 (Terminal)
- **P3DEC (Direct Execution)**：专业级指令控制台。
- **P3DES (The Script Brain)**：轻量级异步脚本语言，支持 `wait` 等非阻塞指令。
- **初始化流**：支持 `init.p3dec` 自动化批处理。

![Terminal Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231439304-1543962446.jpg)

---

## 3. 运行指南 (Getting Started)

1.  **环境要求**：确保安装了 [Processing 4](https://processing.org/download) 或更高版本。
2.  **启动**：克隆本仓库，在 Processing IDE 中打开 `p3deditor/p3deditor.pde`。
3.  **零依赖运行**：无需安装任何库，点击 **Run** 即可进入编辑器。

### ⌨️ 部分核心快捷键
- `1` / `2` / `3` / `4`：选择 / 位移 / 旋转 / 缩放。
- `L`：世界/局部坐标空间切换。
- `G`：开启网格吸附。
- `Tab`：隐藏/显示所有 UI。
- `` ` `` (反引号)：呼出/关闭控制台终端。

---

## 4. 合作与致谢 (Credits)

本项目的诞生得益于 **Yifan Shen** 与 **Antigravity (Google AI Coding Agent)** 的深度协同：
- **Yifan Shen**：产品愿景、UX 交互设计与顶层蓝图。
- **Antigravity**：核心架构设计、数学算法固化与工程实现。

P3DE 证明了在 AI 辅助编程下，开发者可以以最小的代价定制化具备极高复杂度的专业创作工具。

---

---

### 🌐 详情查阅 (Deep Dives)
- [P3DE (Processing 3D Editor) 三维场景编辑器 · 软件白皮书 · 基于 v0.4.8](https://www.cnblogs.com/sharpeye/p/19766415)

---

### 📜 开源协议 (License)
本项目采用 **[MIT License](LICENSE)** 进行许可。版权所有 © 2026 Yifan Shen。

---
**P3DE 的征程才刚刚开始。** 在原生态的土壤里，通过对每一行底层代码的极致雕琢，终能开出艺术之花。
