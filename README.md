# GridTracker 🎹

Terminal music tracker with real-time synthesis. Built with Zig + PortAudio + PortMidi.

## Features

- **Pattern-based sequencing**: Classic tracker interface with rows and channels (64 rows × 8 channels per pattern)
- **Pattern bank**: 256 patterns per song; navigate, clone, and chain them
- **Song mode**: Arrange patterns into a song sequence with per-slot transpose and loop point
- **Parameter locks**: Per-note locks for pitch bend, filter cutoff/resonance, volume, pan, waveform, duty cycle, detune, and portamento
- **Mixer**: 8 channel strips with volume, pan, mute, solo, and master volume
- **Real-time synthesis**: Sine, square (variable duty), sawtooth, triangle, and noise, plus a state-variable filter (lowpass/highpass/bandpass)
- **MIDI input**: Note on/off from external MIDI keyboards (gracefully disabled when no device is present)
- **Polyphonic**: 32 voices with ADSR envelopes and quietest-first voice stealing
- **Save/Load**: Full song persistence (patterns, locks, song arrangement, BPM) to a binary `.song` file
- **Terminal UI**: Keyboard-driven, line-based interface with pattern, song, instrument, and mixer input modes

> Note: the UI is intentionally minimal (line-based, no drawn grid). The
> `draw*` functions in `ui/screen.zig` are stubs reserved for a future
> full-screen TUI; all editing and playback functionality is driven by the
> controls below.

## Building

```bash
# Install dependencies (Arch)
sudo pacman -S portaudio portmidi

# Build
zig build

# Run
zig build run
```

Requires Zig 0.16.0 or newer.

## Testing

```bash
zig build test
```

Runs the unit-test suite for the pure-logic modules (`synthalorian 🎹🤺/voice.zig`,
`tracker/pattern.zig`, `audio/mixer.zig`) via `src/tests.zig`. The tests are
fully headless: no audio hardware, MIDI devices, or terminal required.

## Controls

Note entry uses the lower row of the keyboard (LSDJ-style). Cursor movement is
**uppercase** `WASD` or the arrow keys.

| Key | Action |
|-----|--------|
| `z y c v b n w` | Enter notes C-4 to B-4 |
| `,` `.` `/` | Enter notes C-5, D-5, E-5 |
| `e j k` | Enter notes E-3, G-3, A#3 |
| `u ; o q s` | Enter notes C#4, D#4, F#4, G#4, A#4 |
| `WASD` (uppercase) / arrows | Move cursor |
| `Space` | Play/stop pattern |
| `+` / `-` | BPM up/down |
| `0` | Clear note at cursor |
| `T` / `G` / `I` / `M` | Pattern / Song / Instrument / Mixer input mode |
| `R` | Toggle song mode (pattern chaining) |
| `P` / `X` | Previous / next pattern in bank |
| `N` | Clone current pattern into next slot |
| `1`-`9` | Song screen: set slot pattern number · Mixer screen: toggle channel mute |
| `F` | Save song to `gridtracker.song` |
| `L` | Load song from `gridtracker.song` |
| `Q` | Quit |

## Save/Load Format

`F` writes `gridtracker.song` in the current directory; `L` reads it back.
The binary format (`GTRK` magic, version 3) stores BPM, the full song
arrangement (slots, transpose, loop point), and every pattern in the bank
including all parameter locks. Saves and loads are lossless.

## Architecture

```
src/
├── main.zig          # Entry point
├── tests.zig         # Unit test entry point (zig build test)
├── audio/
│   ├── engine.zig    # PortAudio engine, voice allocation/stealing
│   └── mixer.zig     # Channel strips: volume/pan/mute/solo/master
├── midi/
│   └── input.zig     # PortMidi input (optional, headless-safe)
├── synthalorian 🎹🤺/
│   └── voice.zig     # Polyphonic voice: waveforms, ADSR, filter, locks
├── tracker/
│   └── pattern.zig   # Patterns, pattern bank, song arrangement, sequencer, save/load
└── ui/
    └── screen.zig    # Terminal UI and input handling
```

## License

MIT

---

## ☕ Support the Developer

If this project saved you time, solved a problem, or just made your day a little more neon, you can fuel the next one:

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/synthalorian)
