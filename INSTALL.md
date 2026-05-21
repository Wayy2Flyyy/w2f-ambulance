# Installation

1. Put the resource in your server resources folder as `w2f-ambulance`.
2. Ensure dependencies:
   - `ox_lib`
   - `oxmysql`
3. Import SQL: `sql/w2f_ambulance.sql`.
4. Add to `server.cfg`:
   - `ensure ox_lib`
   - `ensure oxmysql`
   - `ensure w2f-ambulance`
5. Configure files in `config/`.

## Notes
- Pick your framework in `config/framework.lua`.
- Tune injury/death settings in `config/death.lua` and `config/injuries.lua`.
