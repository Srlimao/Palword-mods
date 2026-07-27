## 2026-07-20 - UE4SS FVector C++ Reflection Overhead
**Learning:** In UE4SS Lua mods, accessing properties on Unreal FVector userdata (like .X, .Y, .Z) triggers heavy C++ reflection lookups, which is a massive bottleneck when done inside high-frequency scanning loops (e.g., looping over thousands of items).
**Action:** Convert frequently accessed FVector properties into native Lua tables (e.g., `local pos = { X = uePos.X, Y = uePos.Y, Z = uePos.Z }`) *before* entering scanning loops to change O(n) reflection lookups into O(1) native Lua property lookups.
## 2024-07-27 - Deferred FVector Property Access in Projection Loops
**Learning:** Checking the `.Z` property (representing screen depth/visibility) on an Unreal `FVector` returned by `hud:Project()` first before accessing `.X` and `.Y` avoids unnecessary C++ reflection overhead for items that are off-screen.
**Action:** In rendering or projection loops, read the `.Z` property of projected vectors first. Conditionally read the `.X` and `.Y` properties only if `.Z > 0.0` (i.e., the item is visible).
