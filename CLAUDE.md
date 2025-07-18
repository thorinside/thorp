# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Thorp is a Lua-based arpeggiator sequencer plugin designed for modular synthesizer environments. It generates CV (Control Voltage) pitch and gate outputs from MIDI input, with sophisticated pattern sequencing and scale quantization capabilities.

## Architecture

### Core Components

**Main Script**: `thorp.lua` (741 lines) - Single-file Lua plugin implementing the complete arpeggiator
- **UI System**: Four-page interface (Slot, Pattern, Scale, Song) with encoder/pot controls
- **Arpeggiator Engine**: Real-time note processing with pattern application and scale quantization
- **Sequencer**: Song-mode chaining of 16 arpeggio slots with multiple playback modes
- **MIDI Handler**: Note latching system for live input and slot assignment

### Key Data Structures

- **16 Arpeggio Slots**: Each contains notes array, pattern index, length, and offset
- **40+ Musical Scales**: Comprehensive scale definitions from Ionian to exotic scales
- **23 Rhythmic Patterns**: From basic ascending/descending to complex syncopated patterns
- **Song Chain**: Sequence of slot references with playback position tracking

### Core Functions (thorp.lua)

- `quantizeToScale()` (line 170): Applies scale quantization to MIDI notes
- `drawSlotPageUI()` (line 200): Renders slot management interface
- `drawPatternPageUI()` (line 234): Pattern selection interface
- `drawScalePageUI()` (line 243): Scale/root note configuration
- `drawSongPageUI()` (line 253): Song sequencing interface
- `midiMessage()` (line 376): Handles MIDI note input and latching
- `_advance_step()` (line 411): Core arpeggiator step advancement logic

### UI Architecture

Four-page navigation system accessed via global controls:
- **Page 1 (Slot)**: Configure 16 arp slots, save latched notes, adjust length/offset
- **Page 2 (Pattern)**: Select and assign rhythmic patterns to slots
- **Page 3 (Scale)**: Set global scale quantization and root note
- **Page 4 (Song)**: Chain slots into sequences with various playback modes

## Development

### File Structure
```
/
├── thorp.lua              # Main plugin script
├── README.md              # User documentation
├── UI_FLOWCHART.md        # Detailed UI interaction flowchart
├── thorp_ui_*.svg         # UI mockup graphics for each page
```

### No Build System
This is a single Lua script plugin - no compilation, build tools, or dependency management required. The plugin is used directly in compatible host applications that support Lua scripting.

### Testing
No automated test framework. Testing is performed by loading the plugin in a compatible host application and verifying MIDI input/CV output behavior.

### Key Constants
- Pages: `PAGE_SLOT=1, PAGE_PATTERN=2, PAGE_SCALE=3, PAGE_SONG=4`
- Play modes: `PLAY_MODE_OFF=1, PLAY_MODE_JAM=2, PLAY_MODE_SONG=3`
- Sequence modes: `MODE_SEQ=1, MODE_PINGPONG=2, MODE_RNDWALK=3, MODE_RANDOM=4`

## Recent Changes (Latest)

### UI Improvements
- **Pattern Page**: Replaced duplicate pattern control with gate probability (G.Prob) on Pot 1
- **Scale Page**: Moved octave controls from encoders to pots for cleaner hierarchy:
  - Pot 1: Oct Jump (octave jump chance 0-100%)
  - Pot 2: Oct Range (octave jump range ±1-3)
  - Encoder 1: Root (clean, no overloaded functions)
  - Encoder 2: Scale (clean, no overloaded functions)
- **Notifications**: Moved user notification text to top-right corner as tiny text

### Current UI Layout
- **SLOT**: Individual slot configuration (Slot, Length/Offset, Gate Length)
- **PATTERN**: Rhythm and velocity patterns + gate probability
- **SCALE**: Musical scales and octave jump behavior  
- **SONG**: Sequencing and performance

## Plugin Integration

Thorp integrates with modular synthesizer environments by:
- Receiving MIDI note input for arpeggio source material
- Outputting CV pitch (V/Oct), gate, and velocity signals (0-10V)
- Syncing to host application clock for timing
- Supporting real-time parameter automation via MIDI CC or host controls