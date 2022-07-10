# ComfyComp

## This dosent even work!!

If this is the first time running any powershell scripts on this computer, you'll need to setup an execution policy (and potentially unblock files).

Quick fix to this is to run (double click) the "01help-fix.cmd" file. It will setup the safest policy it can while still allowing you to run the scripts in this folder.

You may also run this if you've recently updated the scripts, and one of them no longer works (due to update).

### What is this???

* ComfyComp

Will compress video files with what I would deem reasonably high quality, and maximize compression, in a quick manner using nvenc.
It will attempt take *any* files in the input folder, and spit out hevc nvenc compressed files (using VBR-CQ), and possibly with b-frames if you have support for it. It also logs certain information, and gives you time to completion.

This will *only* work for people with nvidia cards that support HEVC.
That means minimum 3rd gen (Maxwell GM20x, somewhat limited). 4th gen (pascal) would be preffered.

* audioSplitter

Takes all the files in the input folder, and seperates out a single file per audio track. Sometimes usefuly for video editors without multi track audio support.'

* StingerStacker

Will *attempt* to horizontally stack two files, with alpha channel intact. Useful for track matte stingers in [OBS Studio](https://github.com/obsproject/obs-studio)


* ComfyComp-vp9

Tries to encode files with alpha into vp9 coded webm files. Useful for existing vp9 encodes that are wonky, or if you just want to convert your files to vp9 webm.

* ComfyConc

concatenates (merge/stitch) all the files in the input folder into a single output file. It will not re-encode, just smash them togehtger. All the input files *must* be as identical in terms of format, codec, container etc, or it will fail.

Useful for software that outputs video in segments.

----

**You have the option to have the script auto download FFMPEG to a specified location, and use that**

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
4. Run "01help-fix.cmd" first (unless you're confident you can run downloaded ps)
5. Run the powershell scripts (right click > run in powershell)

If you get powershell errors complaing about script not being signed, you need to allow running unsigned powershell scripts on your local computer.
Please read this: https://docs.microsoft.com/previous-versions//bb613481(v=vs.85)

**TLDR: run "01-help-fix.cmd"**

The script will offer to auto download a compatible (recent) ffmpeg build to C:\ffmpeg and use that if you don't want to do it yourself.
