# PallyPowerAudit

Companion addon for World of Warcraft Classic/TBC Classic that records a local changelog of PallyPower assignment changes.

This addon is intentionally separate from PallyPower so it can be installed alongside the CurseForge version without overwriting it.

Only the person who wants the changelog needs to install PallyPowerAudit. Other raid members only need regular PallyPower for their assignment changes to be visible.

By default, audit messages appear in a dedicated in-game audit window instead of the chat frame. The window will try to dock beside PallyPower when a visible PallyPower frame can be found; otherwise it behaves like a small movable companion panel.

## Install for Local Testing

1. Copy the `PallyPowerAudit` folder into your WoW AddOns directory:

   `World of Warcraft/_classic_/Interface/AddOns/PallyPowerAudit`

2. Keep your existing `PallyPower` folder installed as usual.
3. Launch/reload WoW.
4. Enable both `PallyPower` and `PallyPowerAudit` on the character select AddOns screen.

## Commands

- `/ppaudit` - show the audit window
- `/ppaudit show` - show the audit window
- `/ppaudit hide` - hide the audit window
- `/ppaudit window` - toggle docking to PallyPower when it is visible
- `/ppaudit clear` - clear local audit history
- `/ppaudit raw` - toggle raw addon message logging
- `/ppaudit status` - show whether PallyPower is loaded, whether the local hook attached, and whether the window is shown/docked

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
