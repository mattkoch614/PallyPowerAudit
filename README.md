# PallyPowerAudit

Companion addon for World of Warcraft Classic/TBC Classic that observes PallyPower addon messages and records a local changelog of assignment changes.

This addon is intentionally separate from PallyPower so it can be installed alongside the CurseForge version without overwriting it.

## Install for Local Testing

1. Copy the `PallyPowerAudit` folder into your WoW AddOns directory:

   `World of Warcraft/_classic_/Interface/AddOns/PallyPowerAudit`

2. Keep your existing `PallyPower` folder installed as usual.
3. Launch/reload WoW.
4. Enable both `PallyPower` and `PallyPowerAudit` on the character select AddOns screen.

## Commands

- `/ppaudit` - show recent audit entries
- `/ppaudit show` - show recent audit entries
- `/ppaudit clear` - clear local audit history
- `/ppaudit raw` - toggle raw addon message logging

## Current Scope

The first version listens for PallyPower comms, logs sender/timestamp/raw payload, and attempts to parse common assignment commands.

It does not block assignment changes. That should be handled later by patching PallyPower itself after we confirm message shapes in live testing.

