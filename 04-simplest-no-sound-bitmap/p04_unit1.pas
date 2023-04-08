unit p04_unit1;

{$mode objfpc}
{$H+}
//{$mode delphi}


interface
uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  Grids, dateutils, libavformat, libavutil, libavcodec_codec_par, libavcodec_codec, libavcodec_packet,
   libavutil_rational, libavutil_error, libavutil_pixfmt, Windows, Graphics,
  libavutil_imgutils, libswscale, libavcodec, libavutil_frame;
type

  { TForm1 }
  TForm1 = class(TForm)
    Button1: TButton;
    CheckBox1: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Memo1: TMemo;
    Memo2: TMemo;
    PaintBox1: TPaintBox;
    RadioGroup2: TRadioGroup;
    RadioGroup3: TRadioGroup;
    StringGrid1: TStringGrid;
    StringGrid2: TStringGrid;
    procedure Button1Click(Sender: TObject);
  private
    procedure RenderRelevantBitmap;
    procedure ShowDLLInfo;
    procedure WorkOnMyFrame(pFrame: PAVFrame; pCodecCtx: PAVCodecContext);

  public

  end;


var
  Form1: TForm1;
  G_FileFrameRate: integer;
  G_RunningFramecount: integer;
  G_Startset: boolean;
  G_timebase: double;
  G_QPF1000: int64;//queryperformanceFrequency;
  G_TimerStartTick: int64;
  {variables for RGB approach}
  G_RGBFrame24: PAVFrame = nil;
  G_RGBFrame32: PAVFrame = nil;
  G_MyBitmap24: TBitmap; {from graphics unit, in 'uses' graphics should come after windows}
  G_MyBitmap32: TBitmap; {from graphics unit, in 'uses' graphics should come after windows}
  G_pCurrentBitmap: ^TBitmap;
  swsCtx24: PSwsContext;
  swsCtx32: PSwsContext;

procedure WorkOnVideoPacket01(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame);
procedure WorkOnAudioPacket(ctx: PAVCodecContext; pkt: PAVPacket);
function main(filename: pansichar): integer;
function ReadingPackets01(packet: PAVPacket; vframe: PAVFrame; pFormatCtx: PAVFormatContext; vidId, audId: integer; vidCtx, audCtx: PAVCodecContext): boolean;

procedure PrintFrameInfoAtIntervals(locvframe: PAVFrame; nu: double);
function TimerStart: boolean;
procedure VideoFrameDelay(locvframe: PAVFrame; nu: double);
procedure InitializeRGBFrame24(awidth, aheight: integer);
procedure InitializeRGBFrame32(awidth, aheight: integer);

implementation

{$R *.lfm}
{ AVFrame is typically allocated once and then reused multiple times to hold
 different data (e.g. a single AVFrame to hold frames received from a
 decoder). In such a case, av_frame_unref() will free any references held by
 the frame and reset it to its original clean state before it
 is reused again.}

function TimerStart: boolean;
begin
  QueryPerformanceCounter(G_TimerStartTick);
end;
function GetTimer: double;
var
  nunu: int64;
begin
  QueryPerformanceCounter(nunu);
  Result := (nunu - G_TimerStartTick) / G_QPF1000;
end;
function GetStreamIDs01(pFormatCtx: PAVFormatContext; out vidId, audId: integer): integer;
var
  i: integer;
begin
  Result := -1;
  if (avformat_find_stream_info(pFormatCtx, nil) < 0) then Exit(2);
  vidId := -1; audId := -1;
  for i := 0 to pFormatCtx^.nb_streams - 1 do
    if (pFormatCtx^.streams[i]^.codecpar^.codec_type = AVMEDIA_TYPE_VIDEO) then
      if (vidId = -1) then vidId := i;
  for i := 0 to pFormatCtx^.nb_streams - 1 do
    if (pFormatCtx^.streams[i]^.codecpar^.codec_type = AVMEDIA_TYPE_AUDIO) then
      if (audId = -1) then audId := i;
end;
function SetUpVideoContext(pFormatCtx: PAVFormatContext; vidId: integer; out vidCtx: PAVCodecContext): integer;
var
  vidCodec: PAVCodec;
begin
  Result := -1;
  vidCodec := avcodec_find_decoder(pFormatCtx^.streams[vidId]^.codecpar^.codec_id);
  vidCtx := avcodec_alloc_context3(vidCodec);
  form1.edit2.Caption := vidCodec^.long_name;
  if (avcodec_parameters_to_context(vidCtx, pFormatCtx^.streams[vidId]^.codecpar) < 0) then Exit(3);
  if (avcodec_open2(vidCtx, vidCodec, nil) < 0) then Exit(5);
end;

function SetUpAudioContext(pFormatCtx: PAVFormatContext; audId: integer; out audCtx: PAVCodecContext): integer;
var
  audCodec: PAVCodec;
begin
  Result := -1;
  audCodec := avcodec_find_decoder(pFormatCtx^.streams[audId]^.codecpar^.codec_id);
  audCtx := avcodec_alloc_context3(audCodec);
  form1.edit1.Caption := audCodec^.long_name;
  if (avcodec_parameters_to_context(audCtx, pFormatCtx^.streams[audId]^.codecpar) < 0) then Exit(4);
  if (avcodec_open2(audCtx, audCodec, nil) < 0) then  Exit(6);
end;


function main(filename: pansichar): integer;
var
  vframe, aframe: PAVFrame;
  packet: PAVPacket;
  pFormatCtx: PAVFormatContext;
  vidId, audId: integer;
  vidCtx, audCtx: PAVCodecContext;
  ret: integer;
  vheight, vwidth: integer;
begin
  QueryPerformanceFrequency(G_QPF1000);
  G_QPF1000 := round(G_QPF1000 / 1000);

  Result := 0;
  pFormatCtx := avformat_alloc_context();
  if (avformat_open_input(@pFormatCtx, filename, nil, nil) < 0) then Exit(1);
  ret := GetStreamIDs01(pFormatCtx, vidId, audId); if ret <> -1 then Exit(ret);  {vidId, audId are out values to get}
  G_timebase := av_q2d(pFormatCtx^.streams[vidId]^.time_base);
  G_FileFrameRate := round(pFormatCtx^.streams[vidId]^.avg_frame_rate.num / pFormatCtx^.streams[vidId]^.avg_frame_rate.den);

  ret := SetUpVideoContext(pFormatCtx, vidId, vidCtx);if ret <> -1 then Exit(ret);
  ret := SetUpAudioContext(pFormatCtx, audId, audCtx);if ret <> -1 then Exit(ret);
  vheight := pFormatCtx^.streams[vidId]^.codecpar^.Height;
  vwidth := pFormatCtx^.streams[vidId]^.codecpar^.Width;

  {setup some stuff now that heigth and width are known:}
  G_MyBitmap24 := TBitmap.Create;  {for RGB approach}
  G_MyBitmap24.PixelFormat := pf24bit;
  G_MyBitmap24.SetSize(vWidth, vHeight);
  InitializeRGBFrame24(vwidth, vheight);


  G_MyBitmap32 := TBitmap.Create;
  G_MyBitmap32.PixelFormat := pf32bit;
  G_MyBitmap32.SetSize(vWidth, vHeight);
  InitializeRGBFrame32(vwidth, vheight);


  {here I assume AV_PIX_FMTY_UV420P source format. You can get it from frame.pixelformat, but then you would first have to read frame...}
  swsCtx24 := sws_getContext(vwidth, vheight, AV_PIX_FMT_YUV420P, vwidth, vheight, AV_PIX_FMT_RGB24, SWS_BILINEAR, nil, nil, nil);
  swsCtx32 := sws_getContext(vwidth, vheight, AV_PIX_FMT_YUV420P, vwidth, vheight, AV_PIX_FMT_BGRA, SWS_BILINEAR, nil, nil, nil);
  {alloc and the main loop:}
  vframe := av_frame_alloc(); //note this only allocates the AVFrame itself, NOT the data buffers
  aframe := av_frame_alloc();
  packet := av_packet_alloc();
  G_RunningFramecount := 0;
  ReadingPackets01(packet, vframe, pFormatCtx, vidID, audId, vidCtx, audCtx);

  {cleaning up}
  av_packet_free(@packet);
  av_frame_free(@vframe);
  av_frame_free(@aframe);
  avcodec_free_context(@vidCtx);
  avcodec_free_context(@audCtx);
  avformat_close_input(@pFormatCtx);
  avformat_free_context(pFormatCtx);
end;




function ReadingPackets01(packet: PAVPacket; vframe: PAVFrame; pFormatCtx: PAVFormatContext; vidId, audId: integer; vidCtx, audCtx: PAVCodecContext): boolean;
begin

  while (av_read_frame(pFormatCtx, packet) >= 0) do  {here starts the BIG outer loop that reads all frames/packets}
  begin
    if packet^.stream_index = vidId then  WorkOnVideoPacket01(vidCtx, packet, vframe);
    //if packet^.stream_index = audId then  WorkOnAudioPacket(audCtx, packet);
    av_packet_unref(packet);

  end;
end;


procedure PrintFPS(nu: double);
begin
  if G_RunningFramecount <> 0 then
    form1.edit3.Caption := FloatToStrF(G_RunningFramecount * 1000 / nu, ffFixed, 3, 3);
  form1.edit3.Refresh;
end;

procedure WorkOnVideoPacket01(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame);
var
  nu: double;
begin
  if avcodec_send_packet(ctx, pkt) < 0 then  Exit;
  if avcodec_receive_frame(ctx, locvframe) < 0 then  Exit;
  form1.WorkOnMyFrame(locvframe, ctx);
  Inc(G_RunningFramecount);
  nu := GetTimer;
  PrintFPS(nu);
  if form1.CheckBox1.Checked then
    VideoFrameDelay(locvframe, nu);  //<-----------------DELAY !!!!!!!!!!!!!
  PrintFrameInfoAtIntervals(locvframe, nu);
end;


procedure WorkOnAudioPacket(ctx: PAVCodecContext; pkt: PAVPacket);
begin

end;



procedure VideoFrameDelay(locvframe: PAVFrame; nu: double);
var
  VideotimeInMs: double;
  runningdiff2: double;
begin
  VideotimeInMs := locvframe^.best_effort_timestamp * 1000 * G_timebase;
  runningdiff2 := VideotimeInMs - nu;

  if runningdiff2 > 0 then
    sleep(round(runningdiff2));
end;

procedure PrintFrameInfoAtIntervals(locvframe: PAVFrame; nu: double);
var
  VideotimeInMs: double;
begin
  if (G_RunningFramecount mod (G_FileFrameRate) = 0) then
  begin
    form1.StringGrid2.InsertRowWithValues(form1.StringGrid2.RowCount, [locvframe^.pkt_size.ToString, locvframe^.coded_picture_number.ToString, locvframe^.display_picture_number.ToString]);
    form1.StringGrid2.row := form1.StringGrid2.RowCount;

    VideotimeInMs := locvframe^.best_effort_timestamp * 1000 * G_timebase;
    form1.StringGrid1.InsertRowWithValues(form1.StringGrid1.RowCount, [FloatToStrF(VideotimeInMs / 1000, ffFixed, 3, 3), FloatToStrF(VideotimeInMs - nu, ffFixed, 3, 1)]);
    form1.StringGrid1.row := form1.StringGrid1.RowCount;
    form1.StringGrid1.Refresh;
    Application.ProcessMessages;
  end;

end;




procedure TForm1.ShowDLLInfo;
var
  myname: array[0..MAX_PATH - 1] of char;
begin
  GetModuleFileNameA(GetModuleHandleA(AVFORMAT_LIBNAME), myname, 100);
  memo2.Lines.Add(myname);
  GetModuleFileNameA(GetModuleHandleA(AVUTIL_LIBNAME), myname, 100);
  memo2.Lines.Add(myname);
  GetModuleFileNameA(GetModuleHandleA(AVCODEC_LIBNAME), myname, 100);
  memo2.Lines.Add(myname);
end;


procedure TForm1.Button1Click(Sender: TObject);
var
  ret: integer;
  s: string;
begin
  G_Startset := False;
  ShowDLLInfo;
  ret := main('.\big-buck-bunny-1080p-60fps-30s.mp4');
  case ret of
    1: s := 'cannot open the file';
    2: s := 'Cannot find stream info. Quitting.';
    3: s := 'error with: avcodec_parameters_to_context(vidCtx, vidpar)';
    4: s := 'error with: avcodec_parameters_to_context(audCtx, audpar)';
    5: s := 'error with: avcodec_open2(vidCtx, vidCodec, nil)';
    6: s := 'error with: avcodec_open2(audCtx, audCodec, nil)';
    7: s := ' Could not make a screen variable screen := SDL_CreateWindow(...';
    8: s := ' Could not make a renderer := SDL_CreateRenderer(';
    9: s := ' Could not make a texture := SDL_CreateTexture(';
  end;
  memo1.Lines.add(s);
end;
procedure InitializeRGBFrame24(awidth, aheight: integer);
begin
  if not Assigned(G_RGBFrame24) then
    G_RGBFrame24 := av_frame_alloc();
  av_image_alloc(G_RGBFrame24^.Data, G_RGBFrame24^.linesize, awidth, aheight, AV_PIX_FMT_RGB24, 1);

  G_RGBFrame24^.Width := awidth;
  G_RGBFrame24^.Height := aheight;


  G_RGBFrame24^.format := longint(AV_PIX_FMT_RGB24);
end;

procedure InitializeRGBFrame32(awidth, aheight: integer);
begin
  if not Assigned(G_RGBFrame32) then
    G_RGBFrame32 := av_frame_alloc();
  av_image_alloc(G_RGBFrame32^.Data, G_RGBFrame32^.linesize, awidth, aheight, AV_PIX_FMT_BGRA, 1);
  G_RGBFrame32^.Width := awidth;
  G_RGBFrame32^.Height := aheight;
  G_RGBFrame32^.format := longint(AV_PIX_FMT_BGRA);
end;

procedure InitializeScalingContext24(awidth, aheight: integer; src_fmt, dst_fmt: TAVPixelFormat);
begin
  if Assigned(swsCtx24) then
    sws_freeContext(swsCtx24);
  swsCtx24 := sws_getContext(awidth, aheight, AV_PIX_FMT_YUV420P, awidth, aheight, AV_PIX_FMT_RGB24, SWS_BILINEAR, nil, nil, nil);
  form1.memo1.Lines.add('Init InitializeScalingContext');
end;

procedure Frame24ToBitmap24;
var
  y: integer;
  RGBPtr, BitmapPtr: pbyte;
  BytesPerScanline: integer;
begin
  BytesPerScanline := G_MyBitmap24.Width * 3;
  G_MyBitmap24.BeginUpdate;
  for y := 0 to G_MyBitmap24.Height - 1 do
  begin
    RGBPtr := pbyte(G_RGBFrame24^.Data[0] + y * G_RGBFrame24^.linesize[0]);
    BitmapPtr := G_MyBitmap24.ScanLine[y];
    Move(RGBPtr^, BitmapPtr^, BytesPerScanline);
  end;
  G_MyBitmap24.EndUpdate;
end;

procedure Frame32ToBitMap32;
var
  y: integer;
  RGBPtr, BitmapPtr: pbyte;
  BytesPerScanline: integer;
begin
  BytesPerScanline := G_MyBitmap32.Width * 4;

  G_MyBitmap32.BeginUpdate;
  for y := 0 to G_MyBitmap32.Height - 1 do
  begin
    RGBPtr := pbyte(G_RGBFrame32^.Data[0] + y * G_RGBFrame32^.linesize[0]);
    BitmapPtr := G_MyBitmap32.ScanLine[y];
    Move(RGBPtr^, BitmapPtr^, BytesPerScanline);
  end;
  G_MyBitmap32.EndUpdate;
end;

procedure SwapRedBlue(Bitmap: TBitmap);
var
  x, y: integer;
  Scanline: pbyte;
  Temp: byte;
begin
  Bitmap.PixelFormat := pf24bit;
  for y := 0 to Bitmap.Height - 1 do
  begin
    Scanline := Bitmap.ScanLine[y];
    for x := 0 to Bitmap.Width - 1 do
    begin
      // Swap red and blue components
      Temp := Scanline^;
      Scanline^ := (Scanline + 2)^;
      (Scanline + 2)^ := Temp;
      Inc(Scanline, 3);
    end;
  end;
end;

procedure TForm1.WorkOnMyFrame(pFrame: PAVFrame; pCodecCtx: PAVCodecContext);
begin
  if G_Startset = False then {IMPORTANT, start timer when first frame gets displayed}
  begin
    TimerStart;
    G_Startset := True;
  end;

  if RadioGroup2.ItemIndex = 0 then
  begin
    sws_scale(swsCtx24, @pFrame^.Data, @pFrame^.linesize, 0, pCodecCtx^.Height, @G_RGBFrame24^.Data, @G_RGBFrame24^.linesize);
    Frame24ToBitmap24;
    SwapRedBlue(G_MyBitmap24);
    G_pCurrentBitmap := @G_MyBitmap24; {using pointer here for the right bitmap}
  end;

  if RadioGroup2.ItemIndex = 1 then
  begin
    sws_scale(swsCtx32, @pFrame^.Data, @pFrame^.linesize, 0, pCodecCtx^.Height, @G_RGBFrame32^.Data, @G_RGBFrame32^.linesize);
    Frame32ToBitMap32;
    G_pCurrentBitmap := @G_MyBitmap32;
  end;
  RenderRelevantBitmap;
end;

procedure TForm1.RenderRelevantBitmap;
begin
  if RadioGroup3.ItemIndex = 0 then
  begin
    PaintBox1.Canvas.draw(0, 0, G_pCurrentBitmap^);
    PaintBox1.Invalidate;
  end;

  if RadioGroup3.ItemIndex = 1 then
  begin
    image1.Picture.Assign(G_pCurrentBitmap^);
    image1.Refresh;
  end;

end;



end.
