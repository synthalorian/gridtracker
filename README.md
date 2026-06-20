# GridTracker 🎹

Terminal music tracker with real-time synthesis. Built with Zig + PortAudio + PortMidi.

## Features

- **Pattern-based sequencing**: Classic tracker interface with rows and channels
- **Real-time synthesis**: Multiple waveforms (sine, square, sawtooth, triangle, noise)
- **MIDI input**: Support for external MIDI keyboards and controllers
- **Polyphonic**: 32-voice polyphony with ADSR envelopes
- **Terminal UI**: Keyboard-driven interface with vim-like controls

## Building

```bash
# Install dependencies (Arch)
sudo pacman -S portaudio portmidi

# Build
zig build

# Run
zig build run
```

## Controls

| Key | Action |
|-----|--------|
| `z-m` | Enter notes (C-4 to C-5) |
| `wasd` | Move cursor |
| `Space` | Play/Stop pattern |
| `0` | Clear note |
| `q` | Quit |

## Architecture

```
src/
├── main.zig          # Entry point
├── audio/
│   └── engine.zig    # PortAudio audio engine
├── midi/
│   └── input.zig     # PortMidi MIDI input
├── synth/
│   └── voice.zig     # Polyphonic voice with ADSR
├── tracker/
│   └── pattern.zig   # Pattern sequencer
└── ui/
    └── screen.zig    # Terminal UI
```

## License

MIT
