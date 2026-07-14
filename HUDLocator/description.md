[h1]HUD Locator (Merged & Modularized Edition)[/h1]

A client-side UI mod for Palworld that adds customizable floating HUD overlays for [b]other players[/b], [b]Lifmunk Effigies (relics)[/b], and [b]Treasure Chests[/b]. 

This mod combines and refactors the functionalities of the popular PlayerLocatorHUD and RelicFinder mods into a single, light-weight, performance-tuned package.

[hr][/hr]

[h2] Key Features[/h2]
[list]
[*] [b]Player Distance Tracker[/b]: Locates all players server-wide (even beyond standard network replication distance). Displays floating nameplates with real-time distance indicators.
[*] [b]Relic Finder[/b]: Highlights nearby Lifmunk Effigies with a cyan glowing HUD overlay.
[*] [b]Chest Finder[/b]: Shows yellow/gold floating tags for unopened treasure chests.
[*] [b]In-Game Toggle Binds[/b]: Toggle different trackers or overlay styles on the fly using key binds.
[*] [b]Visual HTML Configurator[/b]: Includes a built-in configurator utility page. Simply drag-and-drop your [i]config.json[/i] file to modify colors, sliders, ranges, nameplate padding, and fonts with a [b]real-time live HUD preview[/b] before saving!
[*] [b]Safe Auto-Config[/b]: Settings are auto-generated on first load. The file is never overwritten by future mod updates, keeping your custom colors and values safe.
[/list]

[hr][/hr]

[h2] In-Game Key Bindings[/h2]
[list]
[*] [b]Alt + F7[/b]  : Toggle [b]Player Locator HUD[/b] on/off.
[*] [b]Alt + F8[/b]  : Toggle [b]Items Finder[/b] (Relics and Chests) on/off.
[*] [b]Alt + F10[/b] : Toggle [b]Player Nameplate Style[/b] (switches between standard solid borders box style and simple text overlay).
[/list]

[hr][/hr]
[h2] Setting Up Your Custom Configurations[/h2]
This mod includes a custom visual settings editor [b]config_editor.html[/b] located inside your mod folder.

[olist]
[*] Open the game at least once to auto-generate your [i]config.json[/i] inside the [i]Mods/HUDLocator[/i] folder.
[*] Double-click [b]config_editor.html[/b] inside the mod folder to open it in your web browser.
[*] Drag-and-drop your [i]config.json[/i] onto the editor page.
[*] Modify ranges, colors, padding, and text offsets. Look at the [b]live interactive preview panel[/b] to see exactly how your adjustments will look in-game.
[*] Click [b]Export config.json[/b] to save the updated settings file and replace the original [i]config.json[/i] in your mod folder.
[/olist]

[hr][/hr]
[h2] Requirements[/h2]
[list]
[*] [b]UE4SS[/b] (v3.0.0 or higher / compatible with the latest Palworld version)
[/list]

[hr][/hr]

[h2] Chinese Description[/h2]

在3D空间中利用实时距离追踪器定位玩家、翠叶鼠雕像和未打开的宝箱。

[h3] 主要功能[/h3]
[list]
[*] [b]玩家定位器[/b]：在服务器中的其他玩家上方显示漂浮的名牌和实时距离，即使他们处于渲染范围之外。
[*] [b]翠叶鼠雕像定位[/b]：在未收集的生命菇雕像（翠叶鼠雕像）上方显示漂浮的青色标签：遗物 [距离]。
[*] [b]宝箱追踪器[/b]：在未打开的宝箱上方显示漂浮的金色标签：宝箱 [距离]。
[*] [b]实时距离计[/b]：距离计数器会根据你的移动在每一帧动态更新。
[*] [b]可视化网页配置[/b]：自带网页端配置工具 [i]config_editor.html[/i]。拖入 [i]config.json[/i] 即可直观地修改名牌的颜色、边距、字号等，并提供 [b]实时HUD预览[/b]！
[*] [b]配置安全[/b]：首次加载时自动生成配置。升级或更新模组时不会覆盖或擦除您的自定义配置。
[/list]

[h3] 快捷键开关[/h3]
[list]
[*] [b]Alt + F7[/b]  ：开启或关闭 [b]玩家定位[/b] 显示。
[*] [b]Alt + F8[/b]  ：开启或关闭 [b]遗物与宝箱[/b] 显示。
[*] [b]Alt + F10[/b] ：切换名牌外观（在带背景框和纯文字之间切换）。
[/list]
