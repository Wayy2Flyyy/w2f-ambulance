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
```

w2f-ambulance will also try to stop these on start if they are still running.

### 3. Match the EMS job in Qbox

`qbx_core/shared/jobs.lua` must define an `ambulance` job with `type = 'ems'` and grades **0–8**. Replace the existing `ambulance` entry (or add one) with:

```lua
['ambulance'] = {
    label = 'EMS',
    type = 'ems',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Trainee EMT',       payment = 180 },
        [1] = { name = 'EMT Basic',        payment = 240 },
        [2] = { name = 'Advanced EMT',     payment = 300 },
        [3] = { name = 'Paramedic',        payment = 360 },
        [4] = { name = 'Senior Paramedic', payment = 420 },
        [5] = { name = 'Flight Medic',     payment = 480 },
        [6] = { name = 'Physician',        payment = 550 },
        [7] = { name = 'Medical Director', payment = 650 },
        [8] = {
            name = 'Chief of EMS',
            payment = 780,
            isboss = true,
            bankAuth = true,
        },
    },
},
```

Grade names and payments mirror `config/ranks.lua`. If you use different rank names, update both files to match.

### 4. Add ox_inventory items

w2f-ambulance ships item icons under `assets/images/`. Copy them into ox_inventory, then add the item definitions below.

#### Copy item images

Copy every PNG from:

```
w2f-ambulance/assets/images/
```

into:

```
ox_inventory/web/images/
```

| Image | Item |
|-------|------|
| `radio.png` | Radio (armory) |
| `bandage.png` | Bandage |
| `painkillers.png` | Painkillers |
| `firstaid.png` | First Aid Kit |
| `ifaks.png` | IFAK |
| `medical_prescription.png` | Medical Prescription |
| `ems_command_tablet.png` | EMS Command Tablet |
| `ems_training_dummy.png` | CPR Training Dummy (Freddy) |
| `haveitol.png` | Haveitol |
| `dead_tired.png` | Dead Tired |
| `fentanyl.png` | Fentanyl |
| `oxycodone.png` | Oxycodone |
| `wakey_wakey.png` | Wakey Wakey |

Filenames must match the item name exactly (e.g. `bandage` → `bandage.png`).

#### Add to `ox_inventory/data/items.lua`

Medical and pharmacy items must export into **w2f-ambulance**. On startup the resource checks for:

`radio`, `bandage`, `painkillers`, `firstaid`, `ifaks`, `medical_prescription`, `ems_command_tablet`, `haveitol`, `dead_tired`, `fentanyl`, `oxycodone`, `wakey_wakey`

`radio` is only required to exist (used by the EMS armory). `ems_training_dummy` is optional but needed for the Freddy CPR dummy placeable.

Add or update this block in `ox_inventory/data/items.lua`:

```lua
-- ── w2f-ambulance ─────────────────────────────────────────────────────

['bandage'] = {
    label = 'Bandage',
    weight = 115,
    consume = 1,
    client = {
        export = 'w2f-ambulance.useBandage',
    },
},

['painkillers'] = {
    label = 'Painkillers',
    weight = 400,
    consume = 1,
    client = {
        export = 'w2f-ambulance.usePainkillers',
    },
},

['firstaid'] = {
    label = 'First Aid Kit',
    weight = 2500,
    consume = 1,
    client = {
        export = 'w2f-ambulance.useFirstaid',
    },
},

['ifaks'] = {
    label = 'Individual First Aid Kit',
    weight = 2500,
    consume = 1,
    client = {
        export = 'w2f-ambulance.useIfaks',
    },
},

['medical_prescription'] = {
    label = 'Medical Prescription',
    weight = 1,
    stack = false,
    description = 'A medical prescription for a specific drug.',
    client = {
        export = 'w2f-ambulance.usePrescription',
    },
},

['ems_command_tablet'] = {
    label = 'EMS Command Tablet',
    weight = 200,
    stack = false,
    close = true,
    client = {
        export = 'w2f-ambulance.useCommandTablet',
    },
},

['ems_training_dummy'] = {
    label = 'CPR Training Dummy (Freddy)',
    weight = 5000,
    stack = false,
    close = true,
    client = {
        export = 'w2f-ambulance.useTrainingDummy',
    },
},

['haveitol'] = {
    label = 'Haveitol',
    weight = 5,
    stack = true,
    close = true,
    consume = 1,
    description = 'Keeps progression feeling lighter for a window.',
    client = {
        export = 'w2f-ambulance.useHaveitol',
    },
},

['dead_tired'] = {
    label = 'Dead Tired',
    weight = 5,
    stack = true,
    close = true,
    consume = 1,
    description = 'Keeps sights steadier — at a cost.',
    client = {
        export = 'w2f-ambulance.useDeadTired',
    },
},

['fentanyl'] = {
    label = 'Fentanyl',
    weight = 2,
    stack = true,
    close = true,
    consume = 1,
    description = 'Dangerous sedation. Extremely habit-forming.',
    client = {
        export = 'w2f-ambulance.useFentanyl',
    },
},

['oxycodone'] = {
    label = 'Oxycodone',
    weight = 2,
    stack = true,
    close = true,
    consume = 1,
    description = 'Pharma-grade painkiller. Illegal without a prescription.',
    client = {
        export = 'w2f-ambulance.useOxycodone',
    },
},

['wakey_wakey'] = {
    label = 'Wakey Wakey',
    weight = 4,
    stack = true,
    close = true,
    consume = 1,
    description = 'Keeps exhaustion at bay temporarily.',
    client = {
        export = 'w2f-ambulance.useWakeyWakey',
    },
},
```

If you still have `w2f-prescription` exports on the scripted meds (`haveitol`, `dead_tired`, etc.), change them to `w2f-ambulance.*` as shown above.

After copying images and editing `items.lua`, restart **ox_inventory**, then **w2f-ambulance**.

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
