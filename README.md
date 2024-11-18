# jellyfin-ffmpeg-proxy
Try to forward jellyfin ffmpeg calls from docker container to the host macOS ffmpeg. Handles path mapping and fail over. Currently HW acceleration is not available and it's hard to implement (the only way is to patch jellyfin server yourself), however even when using CPU transcoding it's still significantly faster and more compatible by using the macOS native ffmpeg.
