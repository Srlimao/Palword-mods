# Free Camera (Native Spectator)

A client-side mod for Palworld that detaches the camera component from the player character during construction and dismantling, allowing you to fly freely and build/dismantle without collision constraints within Base Camp boundaries.
---
## Key Features

- **Free Flight Construction & Dismantling**: Build and dismantle freely around your base camp by detaching the camera from your character.
- **Collision-Free Building**: No more struggling with character collisions while trying to place structures.
- **Gamepad & Keyboard Support**: Full support for both Keyboard and Gamepad flight, elevation (Fly Up/Down), and mode toggling.
- **Adjustable Flight Speed**: Change camera flight speed on the fly using `Page Up` / `Page Down` keys.
- **Extended Dismantle & Snap Range**: Snapping and dismantling distances are increased by 15x while in FreeCam, allowing you to remodel your base easily from high above.
- **Dynamic Reticle Placement**: Construction objects and dismantle targets can be placed/selected precisely at the reticle instead of locking onto the player character.
- **Base-Camp Restricted Activation**: Activation is restricted to base camps only to prevent accidental out-of-bounds spectator triggers.
- **Horizontal Boundary Limits**: Restricts flight movement to a horizontal 1.5x base camp radius cylinder centered on your character to prevent getting lost, with infinite vertical height limits.
- **Optimized Performance**: Zero runtime table allocations in the tick loop, ensuring zero frame stutters or garbage collection lag during camera movement.
---
## How It Works

1. Press **Alt + F8** (Keyboard) or **Gamepad LT + Start** (Gamepad) while within your Base Camp boundaries.
2. The mod automatically disables character collision and detaches the camera, entering Free Camera (Spectator) mode.
3. Fly the camera using your movement keys/analog stick. Your character model will be hidden and teleported to follow your look location.
4. Press **Alt + F8** (Keyboard) or **Gamepad LT + Start** (Gamepad) to exit Free Camera mode, re-attach the camera, re-enable collision, and return to your original position.

*Note: Keyboard and Gamepad bindings can be fully customized in `%LOCALAPPDATA%/Pal/Saved/Mods/FreeCam/config.json`.*
---
## Requirements

- **UE4SS** (Compatible with the latest Palworld version)
---
## Chinese Description

自由视角建筑 (Free Camera / Native Spectator)
Palworld 的客户端模组。在建造和拆除模式下，模组会自动将摄像机与玩家角色分离，使你能够在据点范围内自由飞行，不受角色碰撞限制地进行建造 and 拆除。
---
### 主要功能

- **自由飞行建造与拆除**：在据点内建造 or 拆除时，摄像机脱离角色，让你全方位自由飞行。
- **无碰撞建筑**：放置建筑时不再被角色自身碰撞体积阻挡。
- **手柄与键盘全面支持**：支持键盘和手柄飞行、垂直升降（上升/下降）以及快捷键切换。
- **动态调整飞行速度**：通过 `Page Up` / `Page Down` 快捷键在飞行过程中实时调整摄像机移动速度。
- **超远拆除与对齐距离**：在自由视角下，建筑对齐 and 拆除的最大距离提升了 15 倍，站在高处也能轻松重构据点。
- **动态准星放置**：建造与拆除目标可以直接定位在准星指示的位置，而不是锁定在玩家角色附近。
- **据点激活限制**：限制只能在据点范围内开启自由视角，防止在野外意外触发。
- **水平边界限制**：限制飞行范围为玩家初始位置水平 1.5 倍据点半径的圆柱体内，防止迷路，垂直高度不受限制。
- **极致性能优化**：飞行和更新循环中实现零运行时表分配与垃圾回收 (GC) 开销，确保无任何帧率抖动或延迟。

### 工作原理

1. 在据点范围内按下 **Alt + F8**（键盘）或手柄 **LT + Start**。
2. 模组会自动禁用角色碰撞、分离摄像机，并进入自由视角模式。
3. 使用常规移动键/摇杆自由飞行，角色模型将隐藏并自动跟随你的视线位置。
4. 再次按下 **Alt + F8**（键盘）或手柄 **LT + Start** 键退出自由视角模式，摄像机将自动重新附加，恢复碰撞体积并回到初始位置。

*注：键盘与手柄快捷键绑定均可在 `%LOCALAPPDATA%/Pal/Saved/Mods/FreeCam/config.json` 配置文件中完全自定义。*

### 运行环境需求

- **UE4SS** (兼容最新版本的 Palworld)
