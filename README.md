# w2f-ambulance

Full EMS job + medical core for **Qbox**. Replaces `qbx_ambulancejob`, `qbx_medical`, and `w2f-prescription` in one resource.

Includes death/laststand, injuries, hospital check-in, EMS radial (F6), armory, garage, pharmacy, prescriptions, and scripted meds.

## Requirements

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

## Install

### 1. Add the resource

Place the folder at:

```
resources/[w2f]/w2f-ambulance/
```

### 2. Stop replaced resources

In `server.cfg`, **after** `ensure [qbx]`:

```cfg
stop qbx_ambulancejob
stop qbx_medical
stop w2f-prescription
```

w2f-ambulance will also try to stop these on start if they are still running.

### 3. Match the EMS job in Qbox

`qbx_core/shared/jobs.lua` must define an `ambulance` job with `type = 'ems'` and grades **0–8**. Example grade names:

| Grade | Rank |
|------:|------|
| 0 | Trainee EMT |
| 1 | EMT Basic |
| 2 | Advanced EMT |
| 3 | Paramedic |
| 4 | Senior Paramedic |
| 5 | Flight Medic |
| 6 | Physician |
| 7 | Medical Director |
| 8 | Chief of EMS |

This repo’s `qbx_core/shared/jobs.lua` already matches. If you use a custom jobs file, copy those grades or update `config/ranks.lua` to match yours.

### 4. Add ox_inventory items

Medical items must export into **w2f-ambulance**. Required item names:

`radio`, `bandage`, `painkillers`, `firstaid`, `ifaks`, `medical_prescription`, `ems_command_tablet`, `haveitol`, `dead_tired`, `fentanyl`, `oxycodone`, `wakey_wakey`

Example entries (see this repo’s `ox_inventory/data/items.lua` for the full block):

```lua
['bandage'] = {
    label = 'Bandage',
    weight = 115,
    consume = 1,
    client = { export = 'w2f-ambulance.useBandage' },
},

['firstaid'] = {
    label = 'First Aid Kit',
    weight = 2500,
    client = { export = 'w2f-ambulance.useFirstaid' },
},

['medical_prescription'] = {
    label = 'Medical Prescription',
    weight = 1,
    stack = false,
    client = { export = 'w2f-ambulance.usePrescription' },
},

['ems_command_tablet'] = {
    label = 'EMS Command Tablet',
    weight = 200,
    stack = false,
    close = true,
    client = { export = 'w2f-ambulance.useCommandTablet' },
},
```

After editing `items.lua`, restart **ox_inventory**, then **w2f-ambulance**.

### 5. Database

Tables are created automatically on resource start. To install manually, run:

```
sql/w2f_ambulance.sql
```

### 6. Update server.cfg

```cfg
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure ox_target
ensure ox_inventory

stop qbx_ambulancejob
stop qbx_medical
stop w2f-prescription

ensure [w2f]
ensure w2f-ambulance
```

### 7. Restart and verify

1. Restart the server.
2. Check the console for: `[w2f-ambulance][INFO] Ready — ...`
3. If you see `[ERROR] Not ready`, fix the listed missing dependency, job, or item, then restart w2f-ambulance.
4. In-game: `/setjob <id> ambulance 0`, go on duty, press **F6** for the EMS radial.

## Quick in-game reference

| Action | How |
|--------|-----|
| EMS radial | **F6** (on duty) |
| Command tablet | `/emstablet` or `ems_command_tablet` item (grade 7+) |
| Issue prescription | Radial → Issue Prescription, or ox_target on a player |
| Pharmacy | Pillbox clerk NPC (needs `medical_prescription` item) |
| Distress call | **G** while downed |

## Exports (for other resources)

Medical exports live on **w2f-ambulance**, not `qbx_medical`:

```lua
exports['w2f-ambulance']:Revive(playerId)
exports['w2f-ambulance']:GetPlayerStatus(targetSrc)
exports['w2f-ambulance']:IsDead()
```

`qbx_medical:*` events and state bags are still emitted for compatibility with admin menus and other Qbox resources.

## Config files

| File | Purpose |
|------|---------|
| `config/ranks.lua` | Grade permissions |
| `config/equipment.lua` | Armory, garage, air units |
| `config/shared.lua` | Hospitals, beds, stash locations |
| `config/prescription.lua` | Pharmacy stock and drug effects |
| `medical/config/client.lua` | Death, bleed, injury timers |

## License

MIT
