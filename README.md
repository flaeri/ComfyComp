# ComfyComp

What is this???
Its a pretty basic script that will take *any* files in the input folder, and spit out hevc nvenc compressed files (using VBR-CQ), and possibly with b-frames if you have support for it. It also logs certain informatino, and gives you time to completion.

This *only* works for people with nvidia cards that support HEVC.
Tat means minimum 3rd gen (starting from GM206)

Requires ffmpeg in your path, which has the new nvenc API. You can grab it from here if you need it:
https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z

Make sure you've added ffmpeg to your path, or the script will yell at you.

----
 
1. Download the zip files from releases, and extract them where you would like the folders and videos to live.
2. Adjust the script and $rootLocation to the location from step 1.
    a. If you plan on changing the folder names, make sure the folder names match what is written in the top of the script.

If you get powershell errors complaing about script not being signed, you need to allow running unsigned powershell scripts on your local computer. Please read this: https://docs.microsoft.com/previous-versions//bb613481(v=vs.85)

TLDR: run powershell as admin, and run "set-executionpolicy remotesigned"