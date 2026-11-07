# XNShards

**Soul Shard cleanup** for World of Warcraft: Forever. XNShards keeps the number of Soul Shards you want (2 by
default) and destroys the rest, so Drain Soul never fills your bags again.

**Download it from the [Releases page](https://github.com/XNWLK/XNShards/releases).**

> Built for the WoW: Forever client (interface 16001). What changed in each version: [changelog](CHANGELOG.md).

## Install

1. Download `XNShards-x.y.zip` from the newest entry on the [Releases page](https://github.com/XNWLK/XNShards/releases).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`, so that there is a folder `AddOns\XNShards`.
3. Restart the game and tick **XNShards** in the AddOns list.

## How it works

WoW: Forever only lets addons destroy items right after you press a key, so XNShards does it then:

- **Automatic:** when you have more shards than you want, the **next key you press** out of combat destroys the
  extras. Moving with WASD counts, and the key still does its normal job.
- **On demand:** `/shards` (typed, or in a macro on a key) destroys every extra shard at once.

## Safe by design

- **Only Soul Shards:** XNShards picks the shard up, checks that the item on the cursor really is a Soul Shard, and
  only then destroys it. Anything else goes straight back.
- **Never your cursor:** if you're holding an item, XNShards leaves it alone.
- **Never in combat.**
- **Soul bag first:** the shards you keep are the ones in your soul bag.

## Commands

| | |
|---|---|
| `/shards` | destroy the extra shards now |
| `/shards keep 3` | keep a different number (0 or more) |
| `/shards auto` | turn destroying on your next key press on or off |
| `/shards reset` | try the automatic mode again if you turned it off |
| `/shards help` | list the commands |

Settings are saved per account (`XNShardsDB`).

## Files

- `XNShards/`: the addon (what goes in the zip)
- `art/make-icon.js`: draws the icon (`art/icon-400.png`, `art/icon-512.png`)

Made by Xn for WoW: Forever.
