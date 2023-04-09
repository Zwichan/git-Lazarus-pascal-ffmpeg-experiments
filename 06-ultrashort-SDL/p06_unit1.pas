unit p06_unit1;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  SDL2, dateutils, libavformat, libavutil,libavcodec_codec_par, libavcodec_codec, libavcodec_packet,
  libavutil_rational, libavutil_error, Windows, Graphics, libavcodec, libavutil_frame;
type
  TForm1 = class(TForm)
    Button1: TButton;
    Panel1: TPanel;
    Panel2: TPanel;
    procedure Button1Click(Sender: TObject);
  private
    function main: integer;
  end;
var
  Form1: TForm1;
implementation
{$R *.lfm}
function TForm1.main: integer;
var
  myPAVFrame: PAVFrame;
  myPAVPacket: PAVPacket;
  myPAVFormatContext: PAVFormatContext;
  myPAVCodec: PAVCodec;
  myPAVCodecContext: PAVCodecContext;
  vidId: integer;
  vheight, vwidth: integer;
  TimeDiff: double;
  myPSDL_Window: PSDL_Window;
  myPSDL_Renderer: PSDL_Renderer;
  myPSDL_Texture: PSDL_Texture;
  SourceRect: TSDL_Rect;
  TargetRect: TSDL_Rect;
  Timebase: double;
  filename: pansichar;
  TimeNow: int64;
  TimerStartTick: int64;
  QPF1000: int64;//queryperformanceFrequency;
begin
filename := '.\big-buck-bunny-1080p-60fps-30s.mp4';
  Result := 0;
  QueryPerformanceFrequency(QPF1000);
  QPF1000 := round(QPF1000 / 1000);
  myPAVFormatContext := avformat_alloc_context();
  avformat_open_input(@myPAVFormatContext, filename, nil, nil);
  vidId := av_find_best_stream(myPAVFormatContext, AVMEDIA_TYPE_VIDEO, -1, -1, @myPAVCodec, 0);   {=find_stream_info + find_decoder}
  Timebase := av_q2d(myPAVFormatContext^.streams[vidId]^.time_base);
  myPAVCodecContext := avcodec_alloc_context3(myPAVCodec);
  avcodec_parameters_to_context(myPAVCodecContext, myPAVFormatContext^.streams[vidId]^.codecpar);
  avcodec_open2(myPAVCodecContext, myPAVCodec, nil);
  vheight := myPAVFormatContext^.streams[vidId]^.codecpar^.Height;
  vwidth := myPAVFormatContext^.streams[vidId]^.codecpar^.Width;
  SDL_Init(SDL_INIT_VIDEO);    {SDL init}
  myPSDL_Window := SDL_CreateWindowFrom(pointer(form1.Panel1.Handle));
  myPSDL_Renderer := SDL_CreateRenderer(myPSDL_Window, -1, SDL_RENDERER_ACCELERATED);
  myPSDL_Texture := SDL_CreateTexture(myPSDL_Renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING or SDL_TEXTUREACCESS_TARGET, vwidth, vheight);
  SourceRect.x := 0;  SourceRect.y := 0;  SourceRect.w := vwidth; SourceRect.h := vheight;
  TargetRect.x := 0; TargetRect.y := 0; TargetRect.w := form1.panel1.Width; TargetRect.h := form1.panel1.Height;
  myPAVFrame := av_frame_alloc();
  myPAVPacket := av_packet_alloc();
  QueryPerformanceCounter(TimerStartTick);
  while (av_read_frame(myPAVFormatContext, myPAVPacket) >= 0) do  {main loop that reads all frames/packets}
  begin
    if myPAVPacket^.stream_index = vidId then
    begin
      if avcodec_send_packet(myPAVCodecContext, myPAVPacket) < 0 then  Continue; {next iteration if not succesful}
      if avcodec_receive_frame(myPAVCodecContext, myPAVFrame) < 0 then  Continue;
      SDL_UpdateYUVTexture(myPSDL_Texture, @SourceRect, myPAVFrame^.Data[0], myPAVFrame^.linesize[0], myPAVFrame^.Data[1], myPAVFrame^.linesize[1], myPAVFrame^.Data[2], myPAVFrame^.linesize[2]);
      SDL_RenderClear(myPSDL_Renderer);
      SDL_RenderCopy(myPSDL_Renderer, myPSDL_Texture, nil, @TargetRect);
      SDL_RenderPresent(myPSDL_Renderer);
      QueryPerformanceCounter(TimeNow);
      TimeDiff := (myPAVFrame^.best_effort_timestamp * 1000 * Timebase) - ((TimeNow - TimerStartTick) / QPF1000);
      if TimeDiff > 0 then
        sleep(round(TimeDiff));
    end;
    av_packet_unref(myPAVPacket);
  end;
  SDL_DestroyTexture(myPSDL_Texture);
  SDL_DestroyRenderer(myPSDL_Renderer);
  SDL_DestroyWindow(myPSDL_Window);
  av_packet_free(@myPAVPacket);
  av_frame_free(@myPAVFrame);
  avcodec_free_context(@myPAVCodecContext);
  avformat_close_input(@myPAVFormatContext);
  avformat_free_context(myPAVFormatContext);
end;
procedure TForm1.Button1Click(Sender: TObject);
begin
  main;
end;
end.
