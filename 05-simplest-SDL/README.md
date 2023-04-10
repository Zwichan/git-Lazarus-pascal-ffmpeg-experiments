# Experiment with ffmpeg and SDL2

With SDL2 I can reach 140 fps on i7 2600K with Radeon 570. The fastest of all experiments.
This code is just to show you what I have come up with after searching and experimenting. I am no expert in this field, it just might help you along...
Now including demonstration of av_log_set_callback to log the ffmpeg messages inside the API GUI application (I tried piping of stdout and stderr, did not work...)

Clear from this: SDL is the simplest and fastest...

## Sources and licenses  
FFMPEG binaries from:  
ffmpeg-n5.1-latest-win64-gpl-shared-5.1  
https://github.com/BtbN/FFmpeg-Builds/releases  
  
  
FFMpeg headers from:  
A modified part of FFVCL - Delphi FFmpeg VCL Components.
Copyright (c) 2008-2022 DelphiFFmpeg.com
http://www.DelphiFFmpeg.com
  
  
SDL2 from:  
https://github.com/PascalGameDevelopment/SDL2-for-Pascal  
You may license the Pascal SDL2 units either with the MPL license or with the zlib license.  
BtbN/FFmpeg-Builds is licensed under the MIT License  

Movie 'Big Buck Bunny' from:  
The results of the Peach open movie project has been licensed under the Creative Commons Attribution 3.0 license.  
Full license info: https://peach.blender.org/about/  
The makers: https://peach.blender.org/the-team/  


  
