# HoldToFire Mod - Developer Map

This mod enables players to hold down the fire trigger to shoot semi-automatic weapons (converting them to fully automatic) in Palworld.

## File Structure

- `Info.json`: Mod metadata.
- `config.json`: Mod settings (enabled, debug log, scan interval, and toggling specific weapon categories).
- `enabled.txt`: User notice for UE4SS mods configuration.
- `debugDeploy.bat`: Deployment script for debugging/development.
- `Scripts/main.lua`: Core execution code (hooks weapon attachments and scans all active weapons).
- `Scripts/HoldToFire/config.lua`: Config module handling configuration loading, default settings, and printing helpers.
- `Scripts/HoldToFire/json.lua`: Pure-Lua lightweight JSON parser/stringifier module.

## Firing Logic Modification

Under the hood, Palworld firearms inherit from `ABP_AssaultRifleBase_C` (and ultimately `APalWeaponBase`).
Semi-automatic weapons are restricted to single clicks using the boolean flag `IsTriggerOnlyFireWeapon` (`0x04E8` in `APalWeaponBase`).
When `IsTriggerOnlyFireWeapon` is `true`, the `UPalShooterComponent` only shoots once per click.
By setting `IsTriggerOnlyFireWeapon` to `false`, the weapon logic automatically fires repeatedly at the weapon's configured `GetShootInterval()` value.

### Hooks Used
- **`/Script/Pal.PalWeaponBase:OnAttachWeapon`**: Fired when a weapon actor is equipped by a character. The mod registers a post-hook that modifies the `IsTriggerOnlyFireWeapon` field.
- **Scanning Loop**: Every few seconds, the mod calls `FindAllOf("PalWeaponBase")` to capture any weapons that were spawned, loaded, or missed by the attach hook (such as when reloading the mod mid-game).
