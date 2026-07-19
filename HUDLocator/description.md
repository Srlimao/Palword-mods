# HUD Locator

A client-side UI mod for Palworld that displays customizable floating 3D HUD overlays for **players**, **Lifmunk Effigies (relics)**, **treasure chests**, **Pal eggs**, **dungeons**, and **ground loot**.

🎨 **Visual Web Configurator**: Tweak colors, sliders, padding, and fonts with a live HUD preview at [https://pal-mod-configurator.dunhas.com/](https://pal-mod-configurator.dunhas.com/) (can be opened directly from the in-game menu!).

---

## Key Features

- **Player Tracker**: Server-wide names and real-time distances.
- **Relic Finder**: Cyan overlays for Lifmunk Effigies.
- **Chest Finder**: Yellow/gold overlays for treasure chests.
- **Pal Egg Finder**: Displays size/type with filters (All, Large+, HugeOnly, None).
- **Dungeon Finder**: Purple overlays for dungeon cave entrances.
- **Ground Loot Tracker**: Green overlays for wild spheres, skill fruits, arrows, coins (Filter in `config.json`).
- **In-Game Menu (Alt + F6)**: Toggle trackers and adjust distances on the fly.
- **Manual Reload (Alt + R)**: Reload settings instantly from JSON config.
- **Localization**: Automated translations (English, Chinese, Spanish, Japanese, French, German, and 10+ more).

---

## In-Game Controls

- **Alt + F6**: Toggle settings menu.
- **Alt + Up/Down/Left/Right**: Navigate menu and adjust values.
- **Alt + R**: Reload configuration from settings file.

---

## Requirements

- **UE4SS** (v3.0.0 or higher / compatible with the latest Palworld version)

---

## Configuration Path

- `%LOCALAPPDATA%\Pal\Saved\Mods\HUDLocator\config.json`
*(Generated automatically on first load)*

---

## Chinese Description

在 3D 空间中定位玩家、翠叶鼠雕像、宝箱、帕鲁蛋、地下城和地面掉落道具。

🎨 **网页可视化配置工具**：提供实时 HUD 预览，支持在线调整颜色、边框、距离与间距！立即访问：[https://pal-mod-configurator.dunhas.com/](https://pal-mod-configurator.dunhas.com/)。

---

### 主要功能

- **玩家追踪**：服务器范围内的玩家名称与实时距离。
- **翠叶鼠雕像定位**：显示青色遗物标签。
- **宝箱追踪**：显示金色宝箱标签。
- **帕鲁蛋定位**：显示类型与尺寸，支持过滤（全部、大型+、仅限巨大、无）。
- **地下城追踪**：显示紫色地下城入口标签。
- **地面掉落追踪**：显示野生帕鲁球、技能果实、箭矢、金币等（可在 `config.json` 中配置过滤器）。
- **内置设置菜单 (Alt + F6)**：在游戏中开启/关闭追踪器、调整蛋过滤和距离。
- **配置快速重载 (Alt + R)**：快速重新加载配置文件。
- **多语言支持**：根据游戏语言自动切换翻译（支持英文、中文、日文、西班牙文、德文、法文等10多种语言）。

### 快捷键

- **Alt + F6**：开启/关闭内置设置菜单。
- **Alt + 方向键**：在菜单中选择项目并调整参数。
- **Alt + R**：从配置文件重新加载配置。

### 配置文件路径

- `%LOCALAPPDATA%\Pal\Saved\Mods\HUDLocator\config.json`
