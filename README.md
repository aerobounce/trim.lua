# ✂️ trim.lua
> mpv script to create a "precise" clip of video files without transcoding.

### Differences from the other similar scripts
- **trim.lua** is aimed only for extraction of clips with **no-transcoding**. Encodings will never be occured.
- Without encoding, precise video trimming becomes quite tricky and there is a limit what can be done due to keyframe issues.
    - Tested several softwares on macOS and as far as I know there is no software that can do it accurately. Well, there is, but none were perfect.
    - This script is here to achieve accuracy as much as possible — **Making a clip from a file within minimum keyframe distance, without transcoding**.

### Install
```
curl https://raw.githubusercontent.com/aerobounce/trim.lua/master/trim.lua >> ~/.config/mpv/scripts/trim.lua
```

### Dependencies

- `ffmpeg`
- `ffprobe`
- `osascript` (to post notification on completion. Only on macOS.)

### Usage

> #### Enable Trim Mode (on the First Press)
> > To write out a clip, **press either of the keys twice, with the same start / end position**.<br>
> > To quit Trim Mode, close `mpv` instance.

- <kbd>h</kbd> → `Save Trim Start Position`<br>
- <kbd>k</kbd> → `Save Trim End Position`<br>


> #### Seeking

- <kbd>shift</kbd> + <kbd>h</kbd> → `Seek to Trim Start Position`<br>
- <kbd>shift</kbd> + <kbd>k</kbd> → `Seek to Trim End Position`<br>

> #### Adjust Current Keyframe

- <kbd>shift</kbd> + <kbd>LEFT</kbd> → `Seek Backwards Relatively by Minimum Keyframes`<br>
- <kbd>shift</kbd> + <kbd>RIGHT</kbd> → `Seek Forwards Relatively by Minimum Keyframes`


### Concat with `ffmpeg`
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

### Known Issues
- Any embedded media other than video / audio will be lost, such as embedded subtitles.

### Todo
- [ ] Make `osascript` optional (as it's macOS only feature)
- [ ] More accurate keyframe fetching
- [ ] `ffmpeg` and `ffprobe` paths are hard-coded to `/usr/local/bin/`...
