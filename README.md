# ComfyComp

### What is this???

Its a pretty basic script that will take *any* files in the input folder, and spit out hevc nvenc compressed files (using VBR-CQ), and possibly with b-frames if you have support for it. It also logs certain information, and gives you time to completion.

This *only* work for people with nvidia cards that support HEVC.
That means minimum 3rd gen (Maxwell GM20x, somewhat limited). 4th gen (pascal) would be preffered.

**You now have an option to have the script auto download FFMPEG to a specified location, and use that. Very neat and easy!**

If you would like to download your own build, and add it to your path, feel free to do so. Make sure you're up to date so you have the new Nvenc API.
Make sure the following is in place:

Requires ffmpeg in your path, which has the new nvenc API. You can grab it from here if you need it:
https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-essentials.7z

Make sure you've added ffmpeg to your envoirenment path.

----
 
1. Download the zip files from releases, and extract them where you would like the folders and videos to be.
2. Adjust the script and $rootLocation to the location from step 1.
    
    a. If you plan on changing the folder names, make sure the folder names match what is written in the top of the script.

3. Run the powershell script "ComfyComp.ps1" (right click > run in powershell)

If you get powershell errors complaing about script not being signed, you need to allow running unsigned powershell scripts on your local computer.
Please read this: https://docs.microsoft.com/previous-versions//bb613481(v=vs.85)

**TLDR: run powershell as admin, and run "set-executionpolicy remotesigned"**

The script will offer to auto download a compatible (recent) ffmpeg build to C:\ffmpeg and use that if you dont want to do it yourself.