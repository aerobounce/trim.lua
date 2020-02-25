# trim.lua
mpv script to create a "precise" clip of video files without transcoding.<br>
Utilizes **ffprobe** to fetch accurate keyframes.<br>
Make sure you have **ffmpeg** with **ffprobe** installed.

#### Differences from the other similar scripts
- **trim.lua** is aimed only for extraction of clips with **no-transcoding**. Encodings will never be occured.
- Without encoding, precise video trimming becomes quite tricky and there is a limit what can be done due to keyframes issues.
    - Tested several softwares on macOS and as far as I know there is no software that can do it accurately. Well, there is, but none were perfect.
    - This script is here to achieve accuracy as much as possible — **Making a clip from a file within minimum keyframes, without transcoding**.

### Install
```
curl https://raw.githubusercontent.com/aerobounce/trim.lua/master/trim.lua >> ~/.config/mpv/scripts/trim.lua
```

### Usage
<kbd>h</kbd> — Save Trim Start Position (Enters trim-mode on the first press)<br>
<kbd>k</kbd> — Save Trim End Position (Enters trim-mode on the first press)<br>
<br>
<kbd>shift</kbd>+<kbd>h</kbd> — Seek to Trim Start Position<br>
<kbd>shift</kbd>+<kbd>k</kbd> — Seek to Trim End Position<br>
<br>
<kbd>shift</kbd>+<kbd>LEFT</kbd> — Seek Backwards Relatively by Minimum Keyframes<br>
<kbd>shift</kbd>+<kbd>RIGHT</kbd> — Seek Forwards Relatively by Minimum Keyframes

- On second press with the SAME start/end position invokes write out of a clip.

### Known Issues
- Any embedded media other than video/audio will likely be lost, such as embedded subtitles.

### Todo
- [ ] More descriptive usage section
- [ ] Keybinding to quit trim-mode
- [ ] More accurate keyframe fetching
- [ ] ffmpeg and ffprobe paths are hard-coded
