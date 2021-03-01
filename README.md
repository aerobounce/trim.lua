# ✂️ trim.lua
> mpv script to create a "precise" clip of video files without transcoding.


## ❓ Differences from the other similar scripts

- **trim.lua** is aimed only for extraction of clips with **no-transcoding**. Encodings will never be occured.
- Without encoding, video trimming becomes tricky.
    - Without transcoding, points you can specify to trim is limited to keyframes.
    - Tested several softwares on macOS and as far as I know there is no software that can do it accurately. Well, there is, but none were perfect nor lightweight.
    - This script is here to achieve accuracy as much as possible — **Making a clip from a file within minimum keyframe distance, without transcoding**.

> In short, `trim.lua` turns mpv into a simple lossless video editor.


## 📦 Install

```sh
curl https://raw.githubusercontent.com/aerobounce/trim.lua/master/trim.lua >> ~/.config/mpv/scripts/trim.lua
```

- If your shell has `PATH` to `ffmpeg` and `ffprobe` you're ready to use.
    - If not, rewrite them accordingly.

```lua
local ffmpeg_bin = "ffmpeg"
local ffprobe_bin = "ffprobe"
```


## ⚠️ Requirements

- `ffmpeg`
- `ffprobe`
- `osascript` (Only on macOS to post notification on completion)


## ✂️ Usage

#### Enable trim.lua

- <kbd>h</kbd> or <kbd>k</kbd>


#### Save Trim Positions

> To write out a clip, press either of the keys twice with the same start / end position.<br>
> To quit Trim Mode, close mpv instance.

- <kbd>h</kbd> `Save Trim Start Keyframe`
- <kbd>k</kbd> `Save Trim End Position`

#### Seeking

- <kbd>shift</kbd> + <kbd>LEFT</kbd> `Seek to the Previous Keyframe`
- <kbd>shift</kbd> + <kbd>RIGHT</kbd> `Seek to the Next Keyframe`
- <kbd>shift</kbd> + <kbd>h</kbd> `Seek to the Saved Trim Start Keyframe`
- <kbd>shift</kbd> + <kbd>k</kbd> `Seek to the Saved Trim End Position`


#### ℹ️ To create a valid file

- Beggining of the trim position __must be a keyframe__.
- End position can be any point.


## 🗜 Concat with `ffmpeg`
After splitting, you can concat them with a script something like this.

```sh
CLIPS=("example_1.mp4" "example_2.mp4")
DESTINATION="concat_example.mp4"

ffmpeg \
    -hide_banner \
    -loglevel verbose \
    -f concat \
    -safe 0 \
    -auto_convert 0 \
    -err_detect ignore_err \
    -i <(
        while read -r; do
            echo "file '$REPLY'"
        done <<< "${CLIPS[*]}"
    ) \
    -copy_unknown \
    -map_chapters 0 \
    -c copy \
    "$DESTINATION"
```


## Known Issue
- Any embedded media other than video / audio will be lost, such as embedded subtitles. This will unlikely be fixed.
