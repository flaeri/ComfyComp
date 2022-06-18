# ComfyComp

### What is this???

* ComfyComp

Will compress video files with what I would deem reasonably high quality, and maximize compression, in a quick manner using nvenc.
It will attempt take *any* files in the input folder, and spit out hevc nvenc compressed files (using VBR-CQ), and possibly with b-frames if you have support for it. It also logs certain information, and gives you time to completion.

This will *only* work for people with nvidia cards that support HEVC.
That means minimum 3rd gen (Maxwell GM20x, somewhat limited). 4th gen (pascal) would be preffered.

* StingerStacker

Will *attempt* to horizontally stack two files, with alpha channel intact. Useful for track matte stingers in [OBS Studio](https://github.com/obsproject/obs-studio)

----

**You now have an option to have the script auto download FFMPEG to a specified location, and use that. Nice and simple!**

If you would like to download or use your own build, and add it to your path, feel free to do so. Make sure you're up to date so you have the latest Nvenc API.
Make sure the following is in place:

Requires ffmpeg in your path, which has the new nvenc API. You can grab it from here if you need it:
https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z

Make sure you've added ffmpeg to your envoirenment path.

----

## How to
 
1. Download the latest release, and extract it anywhere. https://github.com/flaeri/ComfyComp/releases

   a. Optionally edit the ComfyComp script if you would like different in/output names etc. Do so towards the top.
3. Add some video files to the input folder (01 input, by default)
4. Run the powershell script "ComfyComp.ps1" (right click > run in powershell)

If you get powershell errors complaing about script not being signed, you need to allow running unsigned powershell scripts on your local computer.
Please read this: https://docs.microsoft.com/previous-versions//bb613481(v=vs.85)

**TLDR: run powershell as admin, and run the following**
```
set-executionpolicy remotesigned
```
The script will offer to auto download a compatible (recent) ffmpeg build to C:\ffmpeg and use that if you don't want to do it yourself.
