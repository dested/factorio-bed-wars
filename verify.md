# Bed Wars — verification recipes

All headless checks use an **isolated Factorio user dir** so they work even
while a real game is running (the live game locks `%APPDATA%\Factorio`).

One-time setup (already done for the session scratchpad; recreate anywhere):

```powershell
# $work = any writable folder
New-Item -ItemType Directory -Force "$work\factorio-user\config", "$work\test-mods" | Out-Null
New-Item -ItemType Junction -Path "$work\test-mods\bed-wars" -Target "G:\code\factorio-bed-wars\mod"
Set-Content "$work\test-mods\mod-list.json" '{"mods":[{"name":"base","enabled":true},{"name":"bed-wars","enabled":true}]}'
@"
[path]
read-data=C:\Program Files (x86)\Steam\steamapps\common\Factorio\data
write-data=$work\factorio-user
"@ | Set-Content "$work\factorio-user\config\config.ini"
$exe = "C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe"
```

## [cheap] Data-stage check (prototypes valid)

```powershell
& $exe --config "$work\factorio-user\config\config.ini" --mod-directory "$work\test-mods" --dump-data
```

Pass = exit 0 and `Loading mod bed-wars` with no `Error` lines in output.

## [medium] Scenario boot check (control stage runs)

```powershell
# port 34199 avoids colliding with a live game's 34197
Start-Process $exe -ArgumentList @("--config","$work\factorio-user\config\config.ini",
  "--mod-directory","$work\test-mods","--start-server-load-scenario","bed-wars/bedwars",
  "--port","34199") -RedirectStandardOutput "$work\server-out.txt" -PassThru -NoNewWindow
# wait ~45 s, then Stop-Process it
```

Pass = log shows `Checksum for script __level__/control.lua`, reaches
`changing state ... to(InGame)`, no `Error` lines, still running at 45 s.
This exercises on_init (mapgen, furniture, markets) and the tick handlers.

## [cheap] Sprite regeneration

```powershell
pwsh -File G:\code\factorio-bed-wars\mod\tools\make-sprites.ps1
```

Pass = 11 PNGs in `mod/graphics/` + `mod/thumbnail.png`, all >200 bytes.

## [heavy — ask first] Real playtest

Launch Factorio (mod auto-detected via junction) → New Game → Bed Wars →
bedwars. Solo smoke: START works with one player; buy from both markets, break
the enemy bed (needs walking there), confirm victory GUI + REMATCH resets to
lobby. Full test needs two players (LAN/second instance).
