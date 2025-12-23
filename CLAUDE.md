# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a collection of Lua scripts for ComputerCraft / CC:Tweaked (Minecraft mod). The scripts create a wireless mining turtle fleet with central monitoring and control.

## Architecture

### Scripts and Their Roles

| Script | Runs On | Purpose |
|--------|---------|---------|
| `selective_miner.lua` | Mining Turtle | Main mining program - mines tunnels, collects ores, returns home |
| `monitor_receiver.lua` | Computer + Monitor | Displays status of up to 9 turtles, recall controls |
| `recall.lua` | Any Computer | CLI tool to recall turtles: `recall` or `recall <id>` |
| `wireless_repeater.lua` | Computer | Extends wireless range by relaying messages |
| `startup.lua` | Mining Turtle | Auto-starts miner on boot/chunk load |
| `clear_area.lua` | Mining Turtle | Clears rectangular area (configurable dimensions), returns home |

### Wireless Communication

All scripts communicate on **channel 100** (configurable). Message types:
- `miner_status` - Turtle sends position, fuel, ores, progress
- `recall` - Recall all turtles
- `recall_id` - Recall specific turtle by ID

### Miner Behavior

The miner uses **branch mining**: mines 64-block tunnels, returns home, shifts left 5 blocks, repeats. Key design constraints:
- Tunnel length (64 blocks) matches wireless modem range
- All movement tracked via `posX, posY, posZ, facing` variables
- **Critical**: Always use `forward()`, `back()`, `up()`, `down()`, `turnLeft()`, `turnRight()` wrapper functions - never raw `turtle.*` movement to maintain position tracking

### Ore Detection

Uses keyword matching for mod compatibility:
- `ORE_KEYWORDS`: "ore", "debris", "cluster"
- `JUNK_KEYWORDS`: "cobblestone", "stone", "dirt", etc.

## Lua/ComputerCraft Specifics

- Variables must be declared before functions that use them (Lua reads top-to-bottom)
- Use `sleep()` after digging to handle falling blocks (gravel/sand)
- `parallel.waitForAny()` runs multiple coroutines (mining + recall listener)
- Advanced Turtles support colors via `term.isColor()`

## Deployment

Scripts are copied to turtles/computers via:
1. Pastebin: `pastebin get <code> <filename>`
2. Manual: `edit <filename>` and paste

Place chest **behind** turtle's starting position for auto-deposit.
