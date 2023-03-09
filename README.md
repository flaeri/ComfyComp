# ComfyComp

## Overview

<p align="center"> A suite of powershell scripts relying on FFmpeg to achieve different tasks. Intended for Windows </p>

## Getting Started

1. Download the latest release from [here](https://github.com/flaeri/ComfyComp/releases)
2. Unzip to any location
3. Run (double click) "01help-fix.cmd"
5. Try running any of the scripts by right clicking it > run with powershell

	a. In order to test most of them, you need to place some files in the `01 Input` folder

BONUS: Cutesy PS one-liner: 
```
iwr https://github.com/flaeri/ComfyComp/archive/refs/heads/experimental.zip -OutFile "cc.zip"; expand-archive -path "cc.zip"; explorer "cc\ComfyComp-experimental"
```

<br>

You'll be prompted for a location where you would like the media files to be stored, so that they can be seperate from where the scripts are. This is only for the first run, and will be stored.

If you choose to move them later, you can delete the "config.json" file, and you'll get prompted again for the location.

If you dont have FFmpeg in your `PATH`, you'll be offered to download it to a predetermined location (C:\ffmpeg). Its a cut down version of [Gyan's release build](https://www.gyan.dev/ffmpeg/builds/)

----------------------

### Settings

If you edit any of the scripts, you'll often find some settings towards the top.

There you can change some behaviors, like if files in the output folder should get overwritten, more verbose log output etc

----------------------

## Script overview

### ComfyComp

Will compress video files with reasonably high quality, and maximize compression, in a quick manner using nvenc.
It will attempt take *any* files in the input folder, and output HEVC compressed files (using VBR-CQ), possibly with b-frames if supported. It also logs certain information, and gives you time to completion.

This will *only* work for people with nvidia cards that support HEVC.
That means minimum 3rd gen (Maxwell GM20x, somewhat limited). 4th gen (pascal) would be preferred.

### discoCompress
Quickly create (1pass, VBV constrained crf/cq) videos that will embed on discord, and adhere to the size selected. Capable of VP9 or h264 (nvenc, x264 if not avaliable).

Able to handle HDR files, and will automatically reduce the resolution if it is deemed to large for the target bitrate.

### audioSplitter

Takes all the files in the input folder, and separates out a single file per audio track. Sometimes useful for video editors without multi track audio support.'

### StingerStacker

Will *attempt* to horizontally stack two files, with alpha channel intact. Useful for track matte stingers in [OBS Studio](https://github.com/obsproject/obs-studio)

### StingerFixer

Tries to encode files with alpha into vp9 coded webm files. Useful for existing vp9 encodes that are wonky, or if you want to convert your files to vp9 webm with alpha channel.

### ComfyConc

concatenates (merge/stitch) all the files in the input folder into a single output file. It will not re-encode, just smash them together. All the input files *must* be identical in terms of format, codec, container etc, or it will fail.

Useful for software that outputs video in segments, and you would like a single file.

----------------------

## FAQ / Support

### Unable to run the powershell scripts
![image](https://user-images.githubusercontent.com/50419942/178776849-ce997b2e-d35d-44e3-8310-63e1d02bcc64.png)

Answer: Please run the "01help-fix.cmd" file. This will allow the bare minimum of powershell scripts to run, and unblock any scripts in the folder.

