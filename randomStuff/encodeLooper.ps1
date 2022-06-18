#bitrate list
$br1 = "7500K"
$br2 = "6000K"

#resolution list
$res1 = 720
$res2 = 864
$res3 = 936
$res4 = 1080

#vars
$inputVid = "C:\temp\testvideos\trial"
$outputPath = "C:\temp\videoDump"
$fps = 60
$gop = $fps*2
$ow = 'n' #overwrite videos?

#lists
$brList = $br1, $br2
$resList = $res1, $res2, $res3, $res4

#videos
$videos = get-childitem -path "$inputVid\*" -Include *.mp4

foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.

    foreach ($res in $resList) {

        $output = "$res-$fps"
    
        foreach ($br in $brList) {
            write-host "processing $shortName at $res at $br"

            ffmpeg -$ow -i "$video" -vf scale=-1:$res -c:v libx264 -preset veryfast -pix_fmt yuv420p `
            -b:v $br -maxrate $br -bufsize $br -g $gop -nal-hrd cbr -x264-params "no-scenecut=1" `
            -profile:v high -level:v 4.2 `
            "$outputPath\$shortName-$res`p$fps-$br.mp4"
        }
    }
}