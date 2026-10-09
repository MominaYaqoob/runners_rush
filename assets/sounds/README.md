# Sound assets

Place these files in this folder. The app falls back to the legacy name when a
new file is missing (so older builds keep working).

| Role | Preferred | Fallback (legacy) |
|------|-----------|-------------------|
| Menu BGM | `bgm_menu.mp3` | `bgm.mp3` |
| Gameplay BGM | `bgm_game.mp3` | `bgm.mp3` |
| Jump | `jump.mp3` | `jump.mp3` |
| Coin collect | `coin.mp3` | `coin.wav` |
| Collision / hit | `collision.mp3` | `collision.mp3` |
| UI button tap | `button_tap.mp3` | `button_tap.mp3` |
| Shield pickup | `shield_pickup.mp3` | `button_tap.mp3` |
| Shield break | `shield_break.mp3` | `collision.mp3` |

Do not commit large drafts here until the final clips are ready; missing preferred
files are resolved at runtime to the fallback.
