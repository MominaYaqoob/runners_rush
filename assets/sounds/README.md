# Sound assets

All eight primary clips below live in this folder. Missing preferred files
resolve at runtime to the listed fallback (legacy clips stay in the repo).

## Primary files (shipped)

| File | Purpose |
|------|---------|
| `bgm_menu.mp3` | Looping music on home / menus |
| `bgm_game.mp3` | Looping music during gameplay |
| `jump.mp3` | Player jump |
| `coin.mp3` | Coin collect |
| `button_tap.mp3` | UI button taps |
| `collision.mp3` | Hit / game-over collision |
| `shield_pickup.mp3` | Shield collected |
| `shield_break.mp3` | Shield absorbs a hit |

## Fallbacks (kept on purpose)

| Preferred | Fallback | Notes |
|-----------|----------|-------|
| `bgm_menu.mp3` / `bgm_game.mp3` | `bgm.mp3` | Old single BGM track |
| `coin.mp3` | `coin.wav` | Old coin SFX |
| `jump.mp3` | `jump.mp3` | Self (always present once shipped) |
| `collision.mp3` | `collision.mp3` | Self |
| `button_tap.mp3` | `button_tap.mp3` | Self |
| `shield_pickup.mp3` | `button_tap.mp3` | Used only if pickup clip missing |
| `shield_break.mp3` | `collision.mp3` | Used only if break clip missing |

`AudioService` picks preferred vs fallback via `resolveSoundFile` / `pickAsset`.
Do not remove `bgm.mp3` or `coin.wav` unless you also update the service.
