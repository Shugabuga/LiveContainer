# zContainer's default wallpaper

The halo behind the phone on Zeus's social banner (getzeus.app/banner.png),
without the phone, framed for a screen. `wallpaper_halo.py` builds it in
Blender 5.2 (Cycles, CPU) from the banner script's own BACKGROUND section, so
the colors, the lens blur and the bloom match the banner. The only change is
where the banner never looked: below the arch's center, each ring's colors
wrap around, and the script joins them there so no seam shows.

    blender -b -P wallpaper_halo.py -- <out.png> <width> <height> <samples> <frame width cm> <center x cm> <center y cm>

The frame is measured on the plane where the banner's phone stood: (0, 0) is
the middle of the banner, which is 25.8 by 13.5 cm there, and y goes up. The
output is a 16-bit PNG, so the slow, dark gradients don't band.

The renders zContainer uses (each takes a few minutes on 8 cores):

    mkdir -p build/wallpaper && cd build/wallpaper
    blender -b -P ../../Scripts/zc/art/wallpaper/wallpaper_halo.py -- $PWD/zContainer-Wallpaper-iPhone.png 1320 2868 128 18 0 -4
    blender -b -P ../../Scripts/zc/art/wallpaper/wallpaper_halo.py -- $PWD/zContainer-Wallpaper-iPad.png 2752 2752 128 25.8 0 -3.5
    blender -b -P ../../Scripts/zc/art/wallpaper/wallpaper_halo.py -- $PWD/Zeus-Halo-Banner.png 2400 1260 128 25.8 0 0

The iPad one is square, so it fills the screen in both orientations. The last
one is the banner itself without the phone.

The app bundles 8-bit copies with an ordered dither, which keeps the gradients
smooth at a fraction of the size, as the `DefaultWallpaperPhone` and
`DefaultWallpaperPad` imagesets (the iPad one at 2048 pixels, which the soft
gradients don't miss):

    magick zContainer-Wallpaper-iPhone.png -ordered-dither o8x8,256 -depth 8 -strip PNG24:../../Resources/Assets.xcassets/DefaultWallpaperPhone.imageset/DefaultWallpaperPhone.png
    magick zContainer-Wallpaper-iPad.png -filter Lanczos -resize 2048x2048 -ordered-dither o8x8,256 -depth 8 -strip PNG24:../../Resources/Assets.xcassets/DefaultWallpaperPad.imageset/DefaultWallpaperPad.png
