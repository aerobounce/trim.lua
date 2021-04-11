# ✂️ trim.lua
> mpv script to create a "precise" clip of audio / video files without transcoding.


## Differences from the other similar scripts

- **trim.lua** is aimed only for extraction of clips with **no-transcoding**. Encodings will never be occured.
- Without encoding, video trimming becomes tricky.
    - A point you can specify to trim is limited to keyframes.
    - Tested several softwares on macOS and as far as I know there is no software that can do it accurately. Well, there is, but none were perfect nor lightweight.
    - This script is to achieve accuracy as much as possible — Making a clip from a file within minimum keyframe distance, without transcoding.

In short, `trim.lua` turns mpv into a simple lossless audio / video editor.


## Install

```sh
# macOS, *nix
curl https://raw.githubusercontent.com/aerobounce/trim.lua/master/trim.lua >> ~/.config/mpv/scripts/trim.lua
```

### Requirements

`ffmpeg`

- If your shell has `PATH` to `ffmpeg` you're ready to use.
    - If not, rewrite `ffmpeg_bin` accordingly.
- All Windows users likely have to specify full path to `ffmpeg`.
    - Or copy the standalone binary into the script directory (not tested).

```lua
-- trim.lua

-- macOS, *nix
ffmpeg_bin = "ffmpeg"

-- Windows
ffmpeg_bin = "ffmpeg.exe"
```


## Usage

#### Enable trim mode

- <kbd>h</kbd> or <kbd>k</kbd>

> If initialized with <kbd>h</kbd>, default trim positions will be: `Current time position` to `End of file`.<br>
> If initialized with <kbd>k</kbd>, default trim positions will be: `Head of file` to `Current time position`.


#### Toggle strip metadata mode (After initializing trim mode)

> Stripping metadata can fix certain corrupted files.

- <kbd>t</kbd>


#### Save Trim Positions

> To write out a clip, press either of the keys twice with the same start / end position.<br>
> To quit Trim Mode, close mpv instance.

- <kbd>h</kbd> `Save Trim Start Keyframe`
- <kbd>k</kbd> `Save Trim End Position`

#### Seeking

> Seek to saved positions

- <kbd>shift</kbd> + <kbd>h</kbd> `Seek to the saved Trim start position`
- <kbd>shift</kbd> + <kbd>k</kbd> `Seek to the saved Trim end position`

> With video file

- <kbd>LEFT</kbd> `Seek backward by keyframe (Minimum distance)`
- <kbd>RIGHT</kbd> `Seek forward by keyframe (Minimum distance)`
- <kbd>UP</kbd> `Seek forward by keyframe (Larger distance)`
- <kbd>DOWN</kbd> `Seek backward by keyframe (Larger distance)`
- <kbd>shift+LEFT</kbd>  `Seek backward exactly by seconds (-0.1 seconds)`
- <kbd>shift+RIGHT</kbd>  `Seek forward exactly by seconds (0.1 seconds)`
- <kbd>shift+UP</kbd>  `Seek backward exactly by seconds (0.5 seconds)`
- <kbd>shift+DOWN</kbd>  `Seek forward exactly by seconds (-0.5 seconds)`

> With audio file

- <kbd>LEFT</kbd> `Seek backward by seconds (-1 seconds)`
- <kbd>RIGHT</kbd> `Seek forward by seconds (1 seconds)`
- <kbd>UP</kbd> `Seek forward by seconds (5 seconds)`
- <kbd>DOWN</kbd> `Seek backward by seconds (-5 seconds)`
- <kbd>shift+LEFT</kbd> `Seek backward by seconds (-10 seconds)`
- <kbd>shift+RIGHT</kbd> `Seek forward by seconds (10 seconds)`
- <kbd>shift+UP</kbd> `Seek forward by seconds (30 seconds)`
- <kbd>shift+DOWN</kbd> `Seek backward by seconds (-30 seconds)`


#### To create a valid video file

- Beggining of the trim position __must be a keyframe__.
- End position can be any point.


## Concat with `ffmpeg`
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
