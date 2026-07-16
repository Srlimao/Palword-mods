# Mod Development TODO List

This document tracks upcoming features, bug fixes, and architectural improvements for both the **Accessory Toggler** and **HUD Locator** mods.

## Shared Architecture
- [ ] **Configurable Shortcuts**: Implement a standardized keybinding architecture for both mods. Allow users to fully customize and remap their hotkeys (e.g., reading string values from `config.json` and dynamically parsing `Key.*` mappings).

## Accessory Toggler

### Bug Fixes & Safety
- [ ] **Screen Bounds Clamping**: Add limits to `HUDX` and `HUDY` during HUD Edit Mode so the UI cannot be pushed outside the visible screen resolution.
- [x] **Auto-Reset Shortcut**: Implement a hotkey (e.g., `Home` or `Backspace`) while in Edit Mode to instantly reset the HUD to its default bottom-center position.

### Architecture & Performance
- [ ] **Refactor Monoliths**: Break down large files (like `toggler.lua` or `renderer.lua`) into smaller, more focused components.
- [ ] **Performance Audit**: Review the background scanner loop and `ReceiveDrawHUD` hooks to ensure minimal garbage collection spikes and CPU usage.

## HUD Locator

### Features
- [ ] **Junk vs. Chest Separation**: Add an option to either completely disable tracking for "Junk" piles, or visually separate them from valuable Chests (e.g., using different colors or icons).
- [ ] **Tracker-Specific Settings (HTML Config Refactor)**: Refactor the HTML config page to separate each tracker into its own dedicated settings section. This will allow users to toggle settings like the "background box", custom colors, or scan radius individually for Chests, Players, Relics, Spheres, etc.
- [ ] **Lootable Spheres Tracking**: Add functionality to track Pal Spheres that are spawned on the ground for looting.

### Architecture & Maintenance
- [ ] **Refactor Monoliths**: Identify and split up large, complex files into manageable sub-modules.
- [ ] **Code Deduplication**: Find and consolidate repeated code snippets (e.g., coordinate math, actor validation) to improve maintainability.
- [ ] **Optimization Pass**: Audit the codebase for performance bottlenecks, ensuring that heavy operations like `FindAllOf` are gated behind slow background timers rather than running every frame.

---
*Feel free to add new ideas or feature requests to this list as they come up!*
