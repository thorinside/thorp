# Thorp Arpeggiator

Thorp is a powerful and flexible 8-step MIDI arpeggiator designed for the disting NT platform. It allows for the creation and sequencing of complex arpeggios, featuring 16 programmable slots, a wide variety of scales and patterns, and a song mode for chaining patterns together.

## Features

- **8-Step Arpeggiator:** Create intricate melodic sequences.
- **16 Programmable Arp Slots:** Each slot stores a pattern, notes, length, and offset.
- **40+ Scales:** From standard major/minor to exotic scales like Byzantine and Pelog.
- **23 Rhythmic Patterns:** A diverse collection of patterns including ascending, descending, random, and syncopated rhythms.
- **4 Main Pages:**
    - **Slot:** Configure individual arpeggiator slots.
    - **Pattern:** Assign rhythmic patterns to slots.
    - **Scale:** Set the root note and scale for quantization.
    - **Song:** Chain arp slots together to create a song.
- **Multiple Play Modes:**
    - **Off:** The arpeggiator is inactive.
    - **Jam:** Play live using latched MIDI notes.
    - **Song:** Play back a sequence of arp slots.
- **Multiple Sequence Modes:**
    - **Seq:** Plays through the song chain sequentially.
    - **Ping-Pong:** Plays the song chain forwards and then backwards.
    - **Rnd-Walk:** Randomly walks through the song chain.
    - **Random:** Jumps to a random step in the song chain.
- **On-Device Help:** A built-in help screen explains the controls for each page.

## UI Overview

The UI is divided into four main pages, which can be cycled through using the `+ Page` and `- Page` buttons. Each page provides access to different parameters and functions of the arpeggiator.

### Page 1: Slot

This is the main page for configuring the 16 arpeggiator slots.

- **Controls:**
    - **Encoder 1 (Select Slot):** Selects the active arp slot (1-16).
    - **Encoder 2 (Length / Offset):**
        - **Turn:** Adjusts the length or offset of the arpeggio.
        - **Push:** Toggles between editing the length and the offset.
    - **Pot 2 (Save Latched Notes):**
        - **Push:** Saves the currently latched MIDI notes to the selected slot.
    - **Pot 3 (Gate Length):** Adjusts the gate length of the MIDI notes.

### Page 2: Pattern

This page is for assigning rhythmic patterns to the arpeggiator slots.

- **Controls:**
    - **Pot 1 (Select Pattern):** Selects a rhythmic pattern from the list.
    - **Pot 2 (Assign Pattern):**
        - **Push:** Assigns the selected pattern to the current arp slot.
    - **Pot 3 (Gate Length):** Adjusts the gate length of the MIDI notes.

### Page 3: Scale

This page is for setting the musical scale and root note for quantization.

- **Controls:**
    - **Encoder 1 (Select Root):** Selects the root note of the scale.
    - **Encoder 2 (Select Scale):** Selects a scale from the list.
    - **Pot 3 (Gate Length):** Adjusts the gate length of the MIDI notes.

### Page 4: Song

This page is for creating and managing the song chain.

![Song Page](thorp_ui_song.svg)


- **Controls:**
    - **Encoder 1 (Select Slot to Add):** Selects an arp slot to add to the chain.
        - **Push:** Adds the selected slot to the end of the chain.
    - **Encoder 2 (Select Play Position):**
        - **Turn:** Moves the playback position within the chain.
        - **Push:** Removes the currently selected slot from the chain.
    - **Pot 2 (Cycle Play Mode):**
        - **Push:** Cycles through the play modes (Off, Jam, Song).
    - **Pot 3 (Select Seq Mode):**
        - **Turn:** Selects the sequence mode (Seq, Ping-Pong, Rnd-Walk, Random).

## Getting Started

1.  **Select a Slot:** Navigate to the **Slot** page and use **Encoder 1** to choose an arp slot.
2.  **Latch Notes:** While in **Jam** mode (selected on the **Song** page), play some notes on your MIDI controller. The notes will be latched.
3.  **Save Notes to Slot:** On the **Slot** page, push **Pot 2** to save the latched notes to the selected slot.
4.  **Choose a Pattern:** Go to the **Pattern** page, select a pattern with **Pot 1**, and push **Pot 2** to assign it to the current slot.
5.  **Set the Scale:** On the **Scale** page, choose a root note and scale using the encoders.
6.  **Create a Song:** Go to the **Song** page and add slots to the chain using **Encoder 1**.
7.  **Play:** On the **Song** page, set the **Play Mode** to **Song** to begin playback.
