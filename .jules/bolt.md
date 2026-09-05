## 2026-07-20 - UE4SS FVector C++ Reflection Overhead
**Learning:** In UE4SS Lua mods, accessing properties on Unreal FVector userdata (like .X, .Y, .Z) triggers heavy C++ reflection lookups, which is a massive bottleneck when done inside high-frequency scanning loops (e.g., looping over thousands of items).
**Action:** Convert frequently accessed FVector properties into native Lua tables (e.g., `local pos = { X = uePos.X, Y = uePos.Y, Z = uePos.Z }`) *before* entering scanning loops to change O(n) reflection lookups into O(1) native Lua property lookups.
## 2024-07-27 - Deferred FVector Property Access in Projection Loops
**Learning:** Checking the `.Z` property (representing screen depth/visibility) on an Unreal `FVector` returned by `hud:Project()` first before accessing `.X` and `.Y` avoids unnecessary C++ reflection overhead for items that are off-screen.
**Action:** In rendering or projection loops, read the `.Z` property of projected vectors first. Conditionally read the `.X` and `.Y` properties only if `.Z > 0.0` (i.e., the item is visible).
## 2024-07-27 - Distance Check Short-Circuiting
**Learning:** Checking X, Y, and Z axes of `FVector` sequentially and short-circuiting on distance failures effectively avoids native property access for off-screen/distant objects. This saves C++ reflection time in intensive scanning loops over thousands of game actors (like items, caves, relics).
**Action:** Always sequentially evaluate `dx*dx`, `dxSq+dy*dy`, then `dxSq+dySq+dz*dz` against `maxDistSq`, reading native properties one-by-one as required.

## 2024-07-27 - Fast Distance Calculation in Lua
**Learning:** In Lua, calculating distance using `math.sqrt((x1-x2)^2 + ...)` is computationally expensive, especially inside loops iterating over many objects (like `chestRegistry`). The exponentiation operator (`^2`) and `math.sqrt` call take significantly more CPU time than simple arithmetic.
**Action:** Always use multiplication (`dx * dx`) instead of exponentiation (`dx^2`), and compare against a squared distance threshold (`minDistSq = 800 * 800`) to completely eliminate the need for `math.sqrt` inside tight loops. Only calculate the square root at the very end when logging or displaying the final value.
## 2024-03-24 - Avoid FVector Unconditional Access in Loops
**Learning:** In UE4SS Lua, unconditionally accessing properties like `.X`, `.Y`, `.Z` on Unreal Engine `FVector` userdata triggers expensive C++ reflection. In projection/rendering loops (like scanning for items across the map), this can cause severe performance bottlenecks, especially when thousands of items exist but only a few are nearby. Using `math.sqrt(dx*dx+dy*dy+dz*dz)` after unconditionally extracting `.X`, `.Y`, and `.Z` forces reflection for every item.
**Action:** Always use `utils.IsWithinDistanceSq(uePos, playerPos, maxDistSq)`. It evaluates axes sequentially, returning early if distance on the X or Y axis already exceeds the maximum squared distance, thus preventing C++ reflection for the remaining axes on distant items. Note: when doing this, be sure not to alter surrounding counter or distance tracking logic unintentionally.
## 2026-08-04 - Fast Distance Calculations and Logging Overhead in Lua Loops
**Learning:** Using `math.sqrt` repeatedly in game update loops creates measurable CPU overhead. Similarly, building large strings using concatenation (`..`) inside tight iterative loops (like scanning objects) triggers significant garbage collection (GC) pressure in Lua, causing micro-stutters.
**Action:** When filtering objects by distance, always compare squared distances (`dx*dx + dy*dy + dz*dz`) against a squared threshold limit rather than computing the square root. Strip out logging or string concatenations embedded in performance-critical execution loops.
## 2024-11-20 - [HUDLocator Scanner Optimization]
**Learning:** In UE4SS Lua, performing C++ reflection checks like `utils.IsRelicPicked` or `utils.IsChestOpened` *before* filtering by distance means expensive C++ API calls are made for thousands of objects, even those halfway across the map.
**Action:** Always defer boolean state queries on Unreal Engine actors until *after* the fast spatial/distance check (`IsWithinDistanceSq`) validates they are within tracking range.
## 2024-11-20 - [HUDLocator Scanner Optimization: Deferring C++ Reflection and String Operations]
**Learning:** In UE4SS Lua loops (like scanning thousands of Pals), extracting C++ properties via reflection (e.g., `GetCharacterID()`) and performing string manipulations/lookups are computationally expensive operations.
**Action:** When filtering objects, defer heavy C++ reflection and string processing until *after* checking basic boolean exclusion criteria (e.g., `isDead`, `isOwned`). This short-circuits evaluation and avoids reflection/string overhead on irrelevant entities.
## 2024-03-24 - Cached String Allocation in Tick Rendering
**Learning:** In UE4SS Lua mods, repeatedly concatenating strings (e.g., `distMeters .. "m"`) inside the `ReceiveDrawHUD` tick (which runs every frame) creates immense, unnecessary Garbage Collection (GC) thrashing and performance spikes over time, especially when tracking multiple entities on-screen.
**Action:** For dynamic values like distance strings that are updated every frame, cache the resulting string locally on the entity's table and only recalculate/re-concatenate when the underlying scalar integer (like the floor value of meters) changes.

## 2026-09-05 - Optimize Scanner Conditional Table Allocations
**Learning:** Unconditionally performing C++ reflection and allocating intermediate tables (like passive skill lists) inside high-frequency scanner loops causes massive Garbage Collection (GC) overhead when those arrays are ultimately discarded (e.g., when the UI configuration doesn't display them).
**Action:** Wrap expensive data extraction and table allocations in conditional checks (e.g., `if showPassives then ...`) to bypass the computation and avoid GC spikes for unused data.
