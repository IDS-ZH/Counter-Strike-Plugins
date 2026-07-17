---
name: "source-engine-qt6-porting"
description: "Guidelines for porting legacy Source Engine tools (MFC/Win32) and systems to modern Qt6 and CMake."
---

# Source Engine & Qt6 Porting Guidelines

This skill provides architectural rules and common patterns for porting legacy Source Engine tools (like Hammer, Model Viewer, Faceposer) from legacy MFC/Win32/WTL to modern Qt 6.x using C++17/20.

## 1. Build System & Toolchain
- **CMake over VPC:** Valve's old VPC (Valve Project Creator) system must be replaced with `CMakeLists.txt`. Qt 6 has native CMake integration (`find_package(Qt6 COMPONENTS Widgets Core Gui Network REQUIRED)`).
- **C++ Standard:** Enforce C++17 or C++20. Many legacy Source Engine macros (`DECLARE_CLASS`, `DEFINE_INDEX`) remain, but modern loops, `auto`, and smart pointers should be used where safe.

## 2. API Transitions & Qt6 specifics
- **No MFC:** Any remnants of `CString`, `CWnd`, `CDialog`, `CRect`, `CPoint` must be strictly mapped to `QString`, `QWidget`, `QDialog`, `QRect`, `QPoint`.
- **String Conversions:** Source Engine heavily uses UTF-8 `char*`. Use `QString::fromUtf8(str)` and `qString.toUtf8().constData()` when passing back to Source Engine APIs.
- **Signals and Slots:** Replace MFC Message Maps (`BEGIN_MESSAGE_MAP`) with Qt 6 pointer-based connect syntax: 
  `connect(button, &QPushButton::clicked, this, &MyClass::onButtonClicked);`
- **Deprecations:** Qt 6 removed many Qt 5 APIs (like `QRegExp` -> `QRegularExpression`, `QDesktopWidget` -> `QScreen`). Ensure you write code that is natively Qt 6 compliant.

## 3. Rendering Pipeline
- **Legacy OpenGL vs RHI:** Older tools used legacy OpenGL (`glBegin`, `glEnd`) inside a custom Windows `HDC`. Qt 6 uses RHI (Rendering Hardware Interface). 
- **Viewports:** For 3D viewports (e.g., Hammer 3D view), use `QOpenGLWidget` as the bridge. You may need to override `initializeGL`, `resizeGL`, and `paintGL`. The Source engine materialsystem must be hooked into the Qt context correctly by passing the OS-level window handle (`QWidget::winId()`).
- **Input:** Intercept Qt's `keyPressEvent`, `mousePressEvent`, and `wheelEvent` to feed into Source Engine's `CInputSystem`.

## 4. Multi-threading and Concurrency
- **UI Thread Blocking:** The Source Engine is generally single-threaded for tool logic. Do NOT block the main Qt GUI thread with heavy engine computations (like map compilation or lighting passes).
- **QtConcurrent:** Use `QtConcurrent::run` and `QFutureWatcher` for offloading background tasks (like VMF parsing or ray tracing).

## 5. Directory Structure for Ported Tools
- Segregate the Qt UI layer from the core Source Engine logic.
- Place UI classes in a `qt/` or `ui/` subdirectory, ensuring headers do not expose Qt types to the core engine headers to avoid massive compilation bloat.
