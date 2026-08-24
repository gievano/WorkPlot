WallpaperCAML template (WorkPlot/Resources/WallpaperCAML)
======================================================

This folder is the descriptor template used only by the **video -> wallpaper**
feature (WallpaperVideoHandler.createCaml). It is copied at runtime and the
main.caml / index.xml files are regenerated from the imported video frames,
so the placeholder versions here are fine.

IMPORTANT: `providerInfo.plist` is an NSKeyedArchiver binary plist and could
not be reconstructed by hand. Copy the real one (and, if unsure, the entire
VideoCAML folder) from the original Pocket Poster source:

  Pocket Poster/Resources/VideoCAML/   ->   WorkPlot/Resources/WallpaperCAML/

You only need this for the video wallpaper feature. Importing/applying
.tendies packages and the Cowabunga catalogue do NOT use this folder.
