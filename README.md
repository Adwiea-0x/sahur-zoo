# SAHUR ZOO

SAHUR ZOO is a 3D steal-a-brainrot game with a zoo theme. Brainrots parade out of a sand cave at one end of the Parade Path and stroll past twelve keeper enclosures; buy one off the path and it walks itself across the plaza and into a pen in your enclosure, where it earns you cash every second. Spend that cash on a bigger pen, faster legs and a stronger slap, seal your enclosure with the lock when rivals come sniffing, and slip into their pens to steal their best brainrots and carry them home on your back — just don't get slapped on the way. Daily-style contracts pay out for buying, penning rare brainrots, locking, stealing, selling and earning; rotating server events (STAMPEDE, GOLDEN HOUR, ANIMAL RAIN) keep the path lively; and when you are rich enough, rebirth resets your zoo for a permanent income multiplier.

## How it is built

The game is written in Luau and built with Rojo: `default.project.json` maps `src/shared` (config and the brainrot cast), `src/server` (world, conveyor, economy, stealing, contracts, events, trail) and `src/client` (the HUD) into the place, and `rojo build default.project.json --output game.rbxl` produces the publishable place file. `main.ts` (Node 22, standard library only) packages the built place, sources and screenshots for the bounty handover.

## Play it

Play SAHUR ZOO on Roblox: https://www.roblox.com/games/107649210185098

## Bounty

This game is an entry to the make.fun roblox-brainrot-01 bounty: https://make.fun/bounty/roblox-brainrot-01

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Adwiea-0x/sahur-zoo/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Adwiea-0x/sahur-zoo/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
