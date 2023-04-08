
# ffmpeg experiment with bitmap and TPaintbox in Lazarus free pascal

This is the best I can do using decoding to bitmap and showing it in 'classic' components like TImage or TPaintbox.

I reach just below 60 fps on i7 2600K with Radeon RX570.

I'm definitely no ffmpeg expert, just glad got this working with lots of searching and experimenting. So maybe there are much faster and simpler solutions...

This is just a study project, not very GUI responsive, probably with memory leaks. 

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


  
