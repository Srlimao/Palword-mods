# HUD Locator

A client-side UI mod for Palworld that displays customizable floating 3D HUD overlays for **players**, **Lifmunk Effigies (relics)**, **treasure chests**, **Pal eggs**, and **dungeon entrances**. 

---

## Key Features

- **Player Tracker**: Displays names and real-time distances server-wide (even beyond standard network replication distance). Supports nameplate backgrounds or simple text overlays.
- **Relic Finder**: Highlights nearby Lifmunk Effigies with cyan tags.
- **Chest Finder**: Highlights unopened treasure chests with yellow/gold tags.
- **Pal Egg Finder**: Displays egg size (Huge, Large, etc.) and type (e.g. Scorching Egg). Includes distance filter options (`All`, `Large+`, `HugeOnly`, `None`).
- **Dungeon Finder**: Highlights fixed dungeon cave entrances with purple tags.
- **Ground Loot & Pickup Tracker**: Highlights naturally spawned items on the ground (like wild Pal Spheres, Skill Fruits/Cards, gold coins, upgrade stones, arrows) with a light-green label. You can customize which items are shown by editing the `"Filters"` list in `config.json` (e.g. `"Filters": ["Sphere", "Flower"]`).
- **In-Game Settings Menu**: Toggle trackers, adjust egg filters, or set max tracking distance directly in-game using a built-in menu (**Alt + F6**).
- **Manual Config Reload**: Reload configurations instantly via **Alt + R** from the external settings JSON file.
- **Visual Web Configurator**: Tweak detailed styles (colors, sliders, padding, fonts) with a live HUD preview using the web editor: [https://pal-mod-configurator.dunhas.com/](https://pal-mod-configurator.dunhas.com/). Can be opened directly from the in-game menu.
- **Localization**: Supports English, Chinese, Spanish, Japanese, French, German, and 10+ other languages, auto-detected from game language settings.

---

## In-Game Controls

- **Alt + F6**: Toggle in-game settings menu.
- **Alt + Up/Down/Left/Right**: Navigate settings menu and modify values.
- **Alt + R**: Reload configuration from settings file.

---

## Requirements

- **UE4SS** (v3.0.0 or higher / compatible with the latest Palworld version)

---

## Configuration Path

- `%USERPROFILE%\Documents\My Games\Palworld\ModConfigs\HUDLocator\config.json`
*(Generated automatically on first load)*

---

## Chinese Description

在 3D 空间中定位玩家、翠叶鼠雕像、宝箱、帕鲁蛋和地下城入口。

### 主要功能

- **玩家追踪**：显示服务器范围内的玩家名牌与实时距离，支持带框背景或纯文本样式。
- **翠叶鼠雕像定位**：显示青色遗物标签。
- **宝箱追踪**：显示金色宝箱标签。
- **帕鲁蛋定位**：显示蛋的类型及尺寸（巨大、大型等），支持过滤设置（全部、大型+、仅限巨大、无）。
- **地下城追踪**：显示紫色地下城入口标签。
- **地面掉落与拾取物追踪**：显示地面上自然生成的道具（如野生帕鲁球、技能果实/技能卡、金币、属性提升药、箭矢等），配有淡绿色标签。您可以通过编辑 `config.json` 里的 `"Filters"` 列表自定义要显示的物品（例如 `"Filters": ["Sphere", "Flower"]`）。
- **游戏内设置菜单 (Alt + F6)**：无需退出游戏，即可在游戏中开启/关闭追踪器、调整蛋过滤和追踪距离。
- **配置快速重载 (Alt + R)**：快速重新加载配置文件。
- **网页可视化配置**：通过菜单可直接访问网页端工具 [https://pal-mod-configurator.dunhas.com/](https://pal-mod-configurator.dunhas.com/) 调整样式并提供实时 HUD 预览。
- **多语言支持**：根据游戏语言自动切换翻译（支持英文、中文、日文、西班牙文、德文、法文等10多种语言）。

### 快捷键

- **Alt + F6**：开启/关闭内置设置菜单。
- **Alt + 方向键**：在菜单中选择项目并调整参数。
- **Alt + R**：从配置文件重新加载配置。

### 配置文件路径

- `%USERPROFILE%\Documents\My Games\Palworld\ModConfigs\HUDLocator\config.json`

