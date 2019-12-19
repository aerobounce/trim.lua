# trim.lua
mpv script to create a trim of video files without transcoding.\
Utilizes ffprobe to fetch accurate keyframes.


# Install
```
cp trim.lua ~/.config/mpv/scripts
```


# Todo
- [ ] More accurate keyframe fetching.


# Differences from other similar scripts
- This script is aimed only for extraction of clips with **no-transcoding**.
- Without encoding, precise video trimming becomes quite tricky with ffmpeg.
    - As far as I know there is no software that can do it accurately.
    - This script is here to achieve that.
