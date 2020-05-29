# ✂️ trim.lua
> mpv script to create a "precise" clip of video files without transcoding.

### ❓ Differences from the other similar scripts
- **trim.lua** is aimed only for extraction of clips with **no-transcoding**. Encodings will never be occured.
- Without encoding, precise video trimming becomes quite tricky and there is a limit what can be done due to keyframe issues.
    - Tested several softwares on macOS and as far as I know there is no software that can do it accurately. Well, there is, but none were perfect.
    - This script is here to achieve accuracy as much as possible — **Making a clip from a file within minimum keyframe distance, without transcoding**.

> In short, `trim.lua` turns mpv into a simple lossless video editor.

## 📦 Install
```
curl https://raw.githubusercontent.com/aerobounce/trim.lua/master/trim.lua >> ~/.config/mpv/scripts/trim.lua
```

## ⚠️ Dependencies

- `ffmpeg`
- `ffprobe`
- `osascript` (to post notification on completion. Only on macOS.)

## ✂️ Usage

<table>
    <tr>
        <th colspan="2">
            <b>Save Trim Positions (Enables Trim Mode on the first press)</b>
            <blockquote>
                <p>To write out a clip, press either of the keys twice, with the same start / end position.<br>
                   To quit Trim Mode, close mpv instance.
               </p>
           </blockquote>
        </th>
    </tr>
    <tr>
        <td><kbd>h</kbd></td>
        <td>Save trim start position</td>
    </tr>
    <tr>
        <td><kbd>k</kbd></td>
        <td>Save trim end position</td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="2">
            <b>Seeking</b>
        </th>
    </tr>
    <tr>
        <td><kbd>shift</kbd> + <kbd>h</kbd></td>
        <td>Seek to trim start position</td>
    </tr>
    <tr>
        <td><kbd>shift</kbd> + <kbd>k</kbd></td>
        <td>Seek to trim end position</td>
    </tr>
</table>

<table>
    <tr>
        <th colspan="2">
            <b>Adjust Current Keyframe</b>
        </th>
    </tr>
    <tr>
        <td><kbd>shift</kbd> + <kbd>LEFT</kbd></td>
        <td>Seek backwards relatively by minimum keyframes</td>
    </tr>
    <tr>
        <td><kbd>shift</kbd> + <kbd>RIGHT</kbd></td>
        <td>Seek forwards relatively by minimum keyframes</td>
    </tr>
</table>


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

## Known Issues
- Any embedded media other than video / audio will be lost, such as embedded subtitles.

## Todo
- [ ] Make `osascript` optional (as it's macOS only feature)
- [ ] More accurate keyframe fetching
- [ ] `ffmpeg` and `ffprobe` paths are hard-coded to `/usr/local/bin/`...
