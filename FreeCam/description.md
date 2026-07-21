# Free Camera (Native Spectator)

A client-side mod for Palworld that detaches the camera component from the player character during construction and dismantling, allowing you to fly freely and build/dismantle without collision constraints within Base Camp boundaries.

---

## Key Features

- **Free Flight Construction & Dismantling**: Build and dismantle freely around your base camp by detaching the camera from your character.
- **Collision-Free Building**: No more struggling with character collisions while trying to place structures.
- **Gamepad & Keyboard Support**: Full support for both Keyboard and Gamepad flight, elevation (Fly Up/Down), and mode toggling.
- **ModConfigurator Integration**: In-game GUI configuration support for keybinds, speed settings, and automatic mode switching.
- **Adjustable Flight Speed**: Change camera flight speed on the fly using `Page Up` / `Page Down` keys.
- **Auto Toggle Option**: Automatically enables spectator mode when selecting a construction blueprint inside your base camp.
- **Dynamic Reticle Placement**: Construction objects and dismantle targets can be placed/selected precisely at the reticle instead of locking onto the player character.

---

## How It Works

1. Select a construction blueprint or enter Dismantle mode while within your Base Camp boundaries (or press **F8** / **Gamepad LT + Select**).
2. The mod automatically disables character collision and detaches the camera, entering Free Camera (Spectator) mode.
3. Fly the camera using your movement keys/analog stick. Your character model will be hidden and teleported to follow your look location.
4. Deselect the blueprint or press **ESC** to automatically re-attach the camera, re-enable collision, and return to your original position.

---

## Requirements

- **UE4SS** (Compatible with the latest Palworld version)
- **ModConfigurator** (Optional, for in-game GUI settings)

---

## Chinese Description

自由视角建筑 (Free Camera / Native Spectator)

Palworld 的客户端模组。在建造和拆除模式下，模组会自动将摄像机与玩家角色分离，使你能够在据点范围内自由飞行，不受角色碰撞限制地进行建造和拆除。

---

### 主要功能

- **自由飞行建造与拆除**：在据点内建造或拆除时，摄像机脱离角色，让你全方位自由飞行。
- **无碰撞建筑**：放置建筑时不再被角色自身碰撞体积阻挡。
- **手柄与键盘全面支持**：支持键盘和手柄飞行、垂直升降（上升/下降）以及快捷键切换。
- **ModConfigurator 整合**：支持游戏内图形化配置菜单，可设置按键绑定、飞行速度及自动切换选项。
- **动态调整飞行速度**：通过 `Page Up` / `Page Down` 快捷键在飞行过程中实时调整摄像机移动速度。
- **自动切换选项**：在据点范围内选择建筑蓝图时，自动进入自由视角（旁观者）模式。
- **动态准星放置**：建造与拆除目标可以直接定位在准星指示的位置，而不是锁定在玩家角色附近。

### 工作原理

1. 在据点范围内选择一个建筑蓝图或进入拆除模式（或按下 **F8** / 手柄 **LT + Select**）。
2. 模组会自动禁用角色碰撞、分离摄像机，并进入自由视角模式。
3. 使用常规移动键/摇杆自由飞行，角色模型将隐藏并自动跟随你的视线位置。
4. 取消选择蓝图或按下 **ESC** 键后，摄像机将自动重新附加，恢复碰撞体积并回到初始位置。

### 运行环境需求

- **UE4SS** (兼容最新版本的 Palworld)
- **ModConfigurator** (可选，用于游戏内 GUI 配置)
