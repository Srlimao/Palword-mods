## 2026-07-20 - UE4SS FVector C++ Reflection Overhead
**Learning:** In UE4SS Lua mods, accessing properties on Unreal FVector userdata (like .X, .Y, .Z) triggers heavy C++ reflection lookups, which is a massive bottleneck when done inside high-frequency scanning loops (e.g., looping over thousands of items).
**Action:** Convert frequently accessed FVector properties into native Lua tables (e.g., `local pos = { X = uePos.X, Y = uePos.Y, Z = uePos.Z }`) *before* entering scanning loops to change O(n) reflection lookups into O(1) native Lua property lookups.
## 2024-07-27 - Deferred FVector Property Access in Projection Loops
**Learning:** Checking the `.Z` property (representing screen depth/visibility) on an Unreal `FVector` returned by `hud:Project()` first before accessing `.X` and `.Y` avoids unnecessary C++ reflection overhead for items that are off-screen.
**Action:** In rendering or projection loops, read the `.Z` property of projected vectors first. Conditionally read the `.X` and `.Y` properties only if `.Z > 0.0` (i.e., the item is visible).
## 2024-07-28 - FVector Sequential Axis Evaluation for Distance Checks
**Learning:** During distance checks inside high-frequency scanning loops, evaluating all three axes (`.X`, `.Y`, `.Z`) of an Unreal FVector simultaneously incurs unnecessary C++ reflection overhead for items that are clearly out of range based on just one or two axes.
**Action:** Extract distance checks into a helper function (e.g., `IsWithinDistanceSq`) that evaluates axes sequentially. Calculate the squared distance for the X-axis first; if it exceeds `maxDistSq`, return early before reading `.Y` or `.Z`. This short-circuiting significantly improves performance when looping over thousands of actors where most are distant.
