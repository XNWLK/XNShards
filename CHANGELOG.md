# Changelog

## v1.1

- Destroys the extra shards on your **next key press** out of combat (moving counts): WoW: Forever only lets addons
  destroy items right after a key press, so destroying on its own when the bags change never worked.
- `/shards` destroys **all** extra shards at once instead of one per press.
- `/shards reset` tries the automatic mode again.

## v1.0

- First version: keeps 2 Soul Shards (or the number set with `/shards keep`), soul bag first, and destroys the rest
  with `/shards`. Only an item that is surely a Soul Shard is ever destroyed, never in combat.
