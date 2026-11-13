# Using Timamp

Timamp opens as three windows docked in a stack: **Player**, **Equalizer** and **Playlist**. The startup sound plays only when the playlist is empty.

## Add music

- **File → Add Files…** (`L`) or **Add Folder…** (`⇧L`); folders are scanned recursively
- Drag files or folders onto the playlist
- The eject button on the player
- **File → Load Playlist… / Save Playlist…** for M3U files
- From Finder: **Open With → Timamp**, a drop on the Dock icon, or a double-click when Timamp is the default app for the file type

Supported formats: MP3, FLAC, WAV, MPEG-4 audio (AAC and Apple Lossless in `.m4a` and `.m4b`), AAC and AIFF.

A file opened from Finder goes to the end of the playlist. It starts playing if Timamp was launched to open it or the playlist was empty; otherwise playback is left alone.

## Windows

- **Move:** drag a window by its title bar. Dragging the Player moves the windows docked to it; dragging the Equalizer or the Playlist moves that window alone, which undocks it. Windows snap to each other and to the screen edges.
- **Title bar buttons:** minimize (Player only), collapse/expand, close. Double-clicking the title bar also collapses or expands the window. Closing the Player quits Timamp.
- **Collapsed windows** keep the essentials: the mini visualizer, time and transport on the Player, volume and balance on the Equalizer, the current track on the Playlist.
- **Show/hide:** the **EQ** and **PL** buttons on the player, or the **View** menu.
- **Window menu:** **Timamp** brings all windows back, **Collapse/Expand Module** (`⌥⌘C`) and **Close** (`⌘W`) act on the focused window.

## Player

- Transport buttons, seek bar, volume and balance, **Shuffle** and **Repeat**
- **Time display:** click it or press `⌘T` to switch between elapsed and remaining time.
- **Mini visualizer:** click to cycle through its 8 modes. Right-click to choose a mode or a color palette.
- **Menu button:** add files, load or save a playlist, playback commands and Quit.

## Equalizer

- 10 bands (60 Hz to 16 kHz) plus preamp, ±12 dB
- **ON** enables the EQ. **AUTO** lowers the preamp when bands are boosted, to limit clipping.
- **PRESETS** has built-in presets, **Load EQF…** and **Reset**.

## Playlist

- Double-click or `Return` plays a track. Click, `⇧`-click and `⌘`-click to select. Drag a row to move it.
- Footer menus: **ADD** (file, directory), **REM** (remove, crop, clear), **SEL** (all, none, invert), **MISC** (sort, reverse, randomize, file info), **LIST OPTS** (new, save, load).
- Right-click a row for Play, Get Info, Remove from Playlist and Remove from Disk.
- Drag the bottom-right corner to resize.

## Keyboard shortcuts

| Key | Action |
|---|---|
| `Space` | Play / pause |
| `X` | Play (restarts a playing track) |
| `C` | Pause / unpause |
| `V` | Stop |
| `Z` / `B` | Previous / next track |
| `S` / `R` | Shuffle / repeat |
| `←` / `→` | Seek −/+ 5 s (also with the playlist focused) |
| `↑` / `↓` | Volume |
| `L` / `⇧L` | Add files / add folder |
| `⌘O` / `⌘S` | Load / save playlist |
| `⌥3` | File info (selected track in the playlist, otherwise the current track) |
| `⌘T` | Elapsed / remaining time |
| `⌥⌘C` / `⌘W` | Collapse or expand / close the focused window |

With the playlist focused:

| Key | Action |
|---|---|
| `↑` `↓` `Home` `End` `PgUp` `PgDn` | Move the selection (add `⇧` to extend it) |
| `Return` | Play |
| `Delete` | Remove selected |
| `⌘⌫` / `⌘⇧⌫` | Crop to selection / clear playlist |
| `⌥↑` / `⌥↓` | Move selected tracks |
| `⌘A` / `⌘I` | Select all / invert |
| `⌘⇧1` / `⌘⇧2` / `⌘⇧3` | Sort by title / file name / path |
| `⌘R` / `⌘⇧R` | Reverse / randomize |

## Troubleshooting

- **A file won't play:** make sure it is in a supported format and check the volume and system output device. Copy-protected files, such as Apple Music downloads (`.m4p`) and protected audiobooks, cannot be played; a protected `.m4b` is added to the playlist but stays silent.
- **A file can't be opened:** add it with Add Files or Add Folder so macOS grants access.
- **Tracks from an M3U file are missing:** when the M3U is opened from Finder or dropped on the playlist, Timamp loads only the tracks it is allowed to read (Music, Downloads and folders added before) and skips the rest without a message. Add the folder with Add Folder first.
