## 2026-07-20 - UE4SS FVector C++ Reflection Overhead
**Learning:** In UE4SS Lua mods, accessing properties on Unreal FVector userdata (like .X, .Y, .Z) triggers heavy C++ reflection lookups, which is a massive bottleneck when done inside high-frequency scanning loops (e.g., looping over thousands of items).
**Action:** Convert frequently accessed FVector properties into native Lua tables (e.g., `local pos = { X = uePos.X, Y = uePos.Y, Z = uePos.Z }`) *before* entering scanning loops to change O(n) reflection lookups into O(1) native Lua property lookups.

## 2026-07-21 - Defer Table Allocation in Scanner Distance Checks
**Learning:** Allocating temporary Lua tables inside high-frequency `FindAllOf` scanning loops (e.g., thousands of items) causes significant garbage collection (GC) pressure and CPU overhead.
**Action:** Unpack properties from Unreal FVector userdata directly into local variables (e.g., `local rX, rY, rZ = uePos.X, uePos.Y, uePos.Z`) and perform distance checks inline. Only create the native Lua table if the distance check passes and the item needs to be added to the result list.
