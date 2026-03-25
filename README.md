# P3DE (Processing 3D Editor)

**English** | [中文版](README_CN.md)

> **Native. Integrated. Zero-Threshold Creation.**
> 
> *A light-weight, modular 3D content creation engine & editor built on the Processing P3D environment.*

---

![P3DE Banner](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324233441993-831857617.jpg)

---

## 1. Core Philosophy

P3DE aims to prove that even within the minimalist Java-based artistic programming framework of **Processing**, it is possible to build a closed-loop toolchain with industrial-grade interaction, high-fidelity rendering, and visual logic editing.

### 🛡️ "Native" Everything
The core technical bottom line of this project is: **No third-party plugins or external Jar libraries were used throughout the entire process** (such as ControlP5, PeasyCam, Rhino, etc.).
- **Self-developed Gizmo System**: Implemented based on pure vector mathematics and Raycasting.
- **Native UI Rendering**: All interfaces are drawn pixel-by-pixel using Processing's basic drawing instructions.
- **Zero-dependency Script Engine (P3DES)**: Custom asynchronous execution and variable interpolation system.
- **Native PBR Shaders**: Cook-Torrance BRDF mathematical models written directly at the GLSL level.

---

## 2. Feature Map

### 🎮 3D Core & Interaction
- **Professional Gizmo Manipulator**: Supports Translate, Rotate, and Scale. Features real-time World/Local coordinate switching (`L` key) and 10-unit grid snapping (`G` key).
- **Hierarchy Management Tree**: Supports infinite depth of parent-child transformations with a right-click context menu.
- **Undo/Redo**: Built on the Command pattern, covering all core editing operations.

![Interaction Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231325839-208076832.jpg)

### ✨ Physics-Based Rendering (PBR Pipeline)
- **GGX Cook-Torrance BRDF**: Accurately simulates metalness and roughness.
- **IBL (Image Based Lighting)**: Supports 360-degree environment map loading for realistic global illumination.
- **Material Property Panel**: Integrated color picker and real-time texture channel control.

### 🧠 Visual Logic Blueprint (VLB)
- **Dual Ownership**: Blueprints can be attached to "Entities" or "Levels," enabling both object logic and global control.
- **Compilation Engine**: Translates non-linear node flows into executable P3DES instructions via DFS algorithm, supporting Hot-Reload.

![Blueprint Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231359524-995366937.jpg)

### 🐚 Script Engine & Terminal
- **P3DEC (Direct Execution)**: Professional-grade instruction console.
- **P3DES (The Script Brain)**: Lightweight asynchronous scripting language supporting non-blocking `wait` instructions.
- **Initialization Flows**: Supports `init.p3dec` for automated batch processing.

![Terminal Demo](https://img2024.cnblogs.com/blog/944545/202603/944545-20260324231439304-1543962446.jpg)

---

## 3. Getting Started

1.  **Requirements**: Ensure [Processing 4](https://processing.org/download) or higher is installed.
2.  **Launch**: Clone this repository and open `p3deditor/p3deditor.pde` in the Processing IDE.
3.  **Run with Zero Dependencies**: No libraries to install; just click **Run** to enter the editor.

### ⌨️ Key Shortcuts
- `1` / `2` / `3` / `4`: Select / Translate / Rotate / Scale.
- `L`: Toggle between World and Local coordinate spaces.
- `G`: Toggle grid snapping.
- `Tab`: Hide/Show all UI.
- `` ` `` (Backtick): Open/Close terminal console.

---

## 4. Credits

The birth of this project is the result of deep synergy between **Yifan Shen** and **Antigravity (Google AI Coding Agent)**:
- **Yifan Shen**: Product vision, UX design, and top-level blueprint.
- **Antigravity**: Core architecture design, mathematical algorithm implementation, and engineering.

P3DE proves that with AI-assisted programming, developers can customize highly complex professional creation tools with minimal overhead.

---

---

### 🌐 Deep Dives
- [P3DE (Processing 3D Editor) Whitepaper · Based on v0.4.8 (Chinese)](https://www.cnblogs.com/sharpeye/p/19766415)

---

### 📜 License
This project is licensed under the **[MIT License](LICENSE)**. Copyright © 2026 Yifan Shen.

---
**The journey of P3DE has just begun.** In the soil of "Native Everything," through the meticulous crafting of every line of low-level code, art finally blooms.
