#bitrate list
$br1 = "100000K"
$br2 = "6000K"

#framerate list
$r1 = 30
$r2 = 37
$r3 = 60

#vars
$inputVid = "C:\temp\testvideos\trial"
$outputPath = "C:\temp\videoDump"
$ow = 'n' #overwrite videos?

#lists
$brList = $br1, $br2
$rList = $r1, $r2, $r3

#videos
$videos = get-childitem -path "$inputVid\*" -Include *.mp4

foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.

    foreach ($r in $rList) {
    
        foreach ($br in $brList) {
            write-host "processing $shortName at $r at $br"

            ffmpeg -$ow -i "$video" -c:v libx264 -an -preset faster `
            -b:v $br -maxrate $br -bufsize $br -r $r -g $r -nal-hrd cbr -pix_fmt yuv444p -x264-params "no-scenecut=1" `
            -profile:v high444 -level:v 5.1 `
            "$outputPath\$shortName-$res`p$r-$br.mp4"
        }
    }
}