# PallyPowerAudit

Companion addon for World of Warcraft Classic/TBC Classic that records a local changelog of PallyPower assignment changes.

This addon is intentionally separate from PallyPower so it can be installed alongside the CurseForge version without overwriting it.

Only the person who wants the changelog needs to install PallyPowerAudit. Other raid members only need regular PallyPower for their assignment changes to be visible.

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
- `/ppaudit status` - show whether PallyPower is loaded and whether the local hook attached

## Current Scope

PallyPowerAudit logs:

- local assignment changes made by your client
- remote assignment changes received from other PallyPower users
- class blessing assignments
- normal/per-player blessing assignments
- mass and packed assignment updates
- aura assignments
- clear assignment events

Entries include timestamp, sender, raw message, and a readable summary. Sender attribution is based on the PallyPower addon message sender for remote changes and your character name for local changes.

It does not block assignment changes. That should be handled later by patching PallyPower itself after we confirm message shapes in live testing.

## Limitations

This is an audit addon, not an access-control addon. It shows which client sent a PallyPower update that your client received. It does not prevent updates, authenticate senders, or stop a modified addon from sending unusual PallyPower messages.
