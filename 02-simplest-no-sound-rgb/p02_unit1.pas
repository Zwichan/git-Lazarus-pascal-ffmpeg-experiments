unit p02_unit1;

{$mode objfpc}
{$H+}
//{$mode delphi}


interface
uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  Grids, SDL2, dateutils, ctypes, libavformat, libavutil, fftypes, BGRABitmap, BGRABITMAPTYPES, BGRAOpenGL, BGRAGraphicControl, BGRAVirtualScreen, GR32_Image,
  libavcodec_codec_par, libavcodec_codec, libavcodec_codec_id, libavcodec_packet,
  libavcodec_codec_defs, libavutil_rational, libavutil_error, libavutil_pixfmt, OpenGLContext, Windows, Graphics,
  libavutil_imgutils, libavutil_mem, libswscale, libavcodec, libavutil_frame;
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
    img32: TImage32;
    Memo1: TMemo;
    Memo2: TMemo;
    OpenGLControl1: TOpenGLControl;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    RadioGroup2: TRadioGroup;
    StringGrid1: TStringGrid;
    StringGrid2: TStringGrid;
    procedure Button1Click(Sender: TObject);
    procedure CheckGroup1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OpenGLControl1Paint(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
  private
    procedure RenderRelevantBitmap(MethodIndex: integer);
    procedure ShowDLLInfo;
    procedure WorkOnMyFrame(pFrame: PAVFrame; pCodecCtx: PAVCodecContext; Approach: integer);

  public

  end;


var
  Form1: TForm1;
  G_FileFrameRate: integer;
  G_RunningFramecount: integer;
  G_Startset: boolean;
  G_screen: PSDL_Window;
  G_renderer: PSDL_Renderer;
  G_texture: PSDL_Texture;
  G_rect: TSDL_Rect;
  G_windowID: uint32;
  G_timebase: double;
  G_QPF1000: int64;//queryperformanceFrequency;
  G_TimerStartTick: int64;
  {variables for RGB approach}
  G_RGBFrame24: PAVFrame = nil;
  G_RGBFrame32: PAVFrame = nil;
  G_MyBitmap24: TBitmap; {from graphics unit, in 'uses' graphics should come after windows}
  G_MyBitmap32: TBitmap; {from graphics unit, in 'uses' graphics should come after windows}
  G_MyBGLBitmap: TBGLBitmap;  //in BGRAOpenGL
  G_OpenGLTexture: IBGLTexture;
  swsCtx24: PSwsContext;
  swsCtx32: PSwsContext;
  BitmapBuffer: array of pbyte; // pre-allocated buffer for storing bitmap data

procedure WorkOnVideoPacket01(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame; Approach: integer);
procedure WorkOnVideoPacket02(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame);
procedure WorkOnAudioPacket(ctx: PAVCodecContext; pkt: PAVPacket);
function main(filename: pansichar): integer;
function CheckSDLStillRunning: boolean;
function SDL_memset(dst: Pointer; c: integer; len: size_t): Pointer; cdecl; external 'SDL2.dll';
function ReadingPackets01(packet: PAVPacket; vframe: PAVFrame; pFormatCtx: PAVFormatContext; vidId, audId: integer; vidCtx, audCtx: PAVCodecContext): boolean;
procedure ShowYUVFrameInSDL(frame: PAVFrame);
procedure PrintFrameInfoAtIntervals(locvframe: PAVFrame; nu: double);
function decode(dec_ctx: PAVCodecContext; frame: PAVFrame; mypkt: PAVPacket; const filename: string): boolean;
function TimerStart: boolean;
procedure VideoFrameDelay(locvframe: PAVFrame; nu: double);
function SetUpSDLStandAlone(swidth, sheight: integer): integer;
function SetUpSDLEmbedded(swidth, sheight: integer): integer;
procedure InitializeRGBFrame24(awidth, aheight: integer);
procedure InitializeRGBFrame32(awidth, aheight: integer);

implementation

{$R *.lfm}
{ AVFrame is typically allocated once and then reused multiple times to hold
 different data (e.g. a single AVFrame to hold frames received from a
 decoder). In such a case, av_frame_unref() will free any references held by
 the frame and reset it to its original clean state before it
 is reused again.}

procedure sdl_zero(var x: Pointer; size: SizeUInt);
begin
  SDL_memset(x, 0, size);
end;

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

  if Form1.RadioGroup2.ItemIndex = 0 then
    ret := SetUpSDLEmbedded(vwidth, vheight);if ret <> -1 then Exit(ret);


  {setup some stuff now that heigth and width are known:}
  G_MyBitmap24 := TBitmap.Create;  {for RGB approach}
  G_MyBitmap24.PixelFormat := pf24bit;
  G_MyBitmap24.SetSize(vWidth, vHeight);
  InitializeRGBFrame24(vwidth, vheight);


  G_MyBitmap32 := TBitmap.Create;
  G_MyBitmap32.PixelFormat := pf32bit;
  G_MyBitmap32.SetSize(vWidth, vHeight);
  InitializeRGBFrame32(vwidth, vheight);

  if Form1.RadioGroup2.ItemIndex <>0 then
  begin
    G_MyBGLBitmap := TBGLBitmap.Create;
    G_MyBGLBitmap.SetSize(vWidth, vHeight);
    BGLViewPort(vWidth, vHeight); {works on the only single OpenGL stuff present in the app, like a TOpenGLControl added to the Form}
  end;




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
  SDL_DestroyTexture(G_texture);
  SDL_DestroyRenderer(G_renderer);
  SDL_DestroyWindow(G_screen);
  av_packet_free(@packet);
  av_frame_free(@vframe);
  av_frame_free(@aframe);
  avcodec_free_context(@vidCtx);
  avcodec_free_context(@audCtx);
  avformat_close_input(@pFormatCtx);
  avformat_free_context(pFormatCtx);
end;




function ReadingPackets01(packet: PAVPacket; vframe: PAVFrame; pFormatCtx: PAVFormatContext; vidId, audId: integer; vidCtx, audCtx: PAVCodecContext): boolean;
var
  Approach: integer;
begin

  while (av_read_frame(pFormatCtx, packet) >= 0) do  {here starts the BIG outer loop that reads all frames/packets}
  begin
    if form1.RadioGroup2.ItemIndex = 0 then
      if (vframe^.coded_picture_number mod 20 = 0) then {only check every so many frames...}
        if CheckSDLStillRunning = False then Break;
    if packet^.stream_index = vidId then  WorkOnVideoPacket01(vidCtx, packet, vframe, form1.RadioGroup2.ItemIndex);
    if packet^.stream_index = audId then  WorkOnAudioPacket(audCtx, packet);
    av_packet_unref(packet);

  end;
end;

function CheckSDLStillRunning: boolean;
var
  evt: TSDL_Event;
begin
  Result := True;
  while SDL_PollEvent(@evt) > 0 do
    case evt.type_ of
      SDL_WINDOWEVENT:
        if evt.window.windowID = G_windowID then
          case evt.window.event of
            SDL_WINDOWEVENT_CLOSE:
            begin
              evt.type_ := SDL_QUITEV;
              Result := False;
              SDL_PushEvent(@evt);
            end;
          end;
      SDL_QUITEV:        //originally SDL_QUIT, but changed, cause theres a method called SDL_QUI
        Result := False;
    end;
end;


procedure PrintFPS(nu: double);
begin
  if G_RunningFramecount <> 0 then
    form1.edit3.Caption := FloatToStrF(G_RunningFramecount * 1000 / nu, ffFixed, 3, 3);
  form1.edit3.Refresh;
end;

procedure WorkOnVideoPacket01(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame; Approach: integer);
var
  nu: double;
begin
  if avcodec_send_packet(ctx, pkt) < 0 then  Exit;
  if avcodec_receive_frame(ctx, locvframe) < 0 then  Exit;
  form1.WorkOnMyFrame(locvframe, ctx, Approach);
  Inc(G_RunningFramecount);
  nu := GetTimer;
  PrintFPS(nu);
  if form1.CheckBox1.Checked then
    VideoFrameDelay(locvframe, nu);  //<-----------------DELAY !!!!!!!!!!!!!
  PrintFrameInfoAtIntervals(locvframe, nu);
end;

procedure WorkOnVideoPacket02(ctx: PAVCodecContext; pkt: PAVPacket; locvframe: PAVFrame);
begin
  {avcodec_send_packet: Supply raw packet data as input to a decoder. Internally, this call will copy relevant AVCodecContext fields,
  which can influence decoding per-packet, and apply them when the packet is actually decoded.}

  {todo: finish this with if (ret = AVERROR_EAGAIN) or (ret = AVERROR_EOF), official flow}
  if avcodec_send_packet(ctx, pkt) < 0 then  Exit;
  if avcodec_receive_frame(ctx, locvframe) < 0 then  Exit;
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


procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  G_MyBGLBitmap.Free;
end;



procedure TForm1.RadioGroup1Click(Sender: TObject);
begin

end;


procedure TForm1.Button1Click(Sender: TObject);
var
  ret: integer;
  s: string;
begin
  G_Startset := False;
  SDL_Init(SDL_INIT_EVERYTHING);
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
  SDL_DestroyTexture(G_texture);
  SDL_DestroyRenderer(G_renderer);
  SDL_DestroyWindow(G_screen);
  SDL_Quit();
end;

procedure TForm1.CheckGroup1Click(Sender: TObject);
begin

end;

{for RGB approach}
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

{procedure convert_yuv420p_to_rgb_var(pFrame: PAVFrame; awidth, aheight: integer; pix_fmt: TAVPixelFormat);
begin
  //if not Assigned(swsCtx24) then
   // InitializeScalingContext24(awidth, aheight, TAVPixelFormat(pFrame^.format), pix_fmt);
  sws_scale(swsCtx24, @pFrame^.Data, @pFrame^.linesize, 0, aheight, @G_RGBFrame24^.Data, @G_RGBFrame24^.linesize);
end; }



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


procedure Frame32ToBGLBitmap(const aWidth, aHeight: integer);
var
  y: integer;
  RGBPtr, BitmapPtr: pbyte;
  BytesPerScanline: integer;
begin
  BytesPerScanline := aWidth * 4; {TBGLBitmap is like pf32bit, 24 not possibl I think}
  {comment: G_MyBGLBitmap.Bitmap.BeginUpdate(False); etc does not seem to speed up stuff}
  for y := 0 to aHeight - 1 do
  begin
    RGBPtr := pbyte(G_RGBFrame32^.Data[0] + y * G_RGBFrame32^.linesize[0]);
    BitmapPtr := pbyte(G_MyBGLBitmap.ScanLine[y]);
    Move(RGBPtr^, BitmapPtr^, BytesPerScanline);
  end;

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

procedure TForm1.WorkOnMyFrame(pFrame: PAVFrame; pCodecCtx: PAVCodecContext; Approach: integer);
//const
// Approach = 1;   //CHOOSE HERE!!
var
  y: integer;
begin
  if G_Startset = False then {IMPORTANT, start timer when first frame gets displayed}
  begin
    TimerStart;
    G_Startset := True;
  end;

  if Approach = 0 then
  begin
    ShowYUVFrameInSDL(pFrame);
  end;

  if Approach = 1 then
  begin
    sws_scale(swsCtx24, @pFrame^.Data, @pFrame^.linesize, 0, pCodecCtx^.Height, @G_RGBFrame24^.Data, @G_RGBFrame24^.linesize);
    Frame24ToBitmap24; {works on the global G_MyBitmap24}
    SwapRedBlue(G_MyBitmap24); //WITH SWAP!!!
  end;

  if Approach = 2 then
  begin
    sws_scale(swsCtx32, @pFrame^.Data, @pFrame^.linesize, 0, pCodecCtx^.Height, @G_RGBFrame32^.Data, @G_RGBFrame32^.linesize);
    Frame32ToBitMap32;
  end;

  if Approach = 3 then
  begin
    sws_scale(swsCtx32, @pFrame^.Data, @pFrame^.linesize, 0, pCodecCtx^.Height, @G_RGBFrame32^.Data, @G_RGBFrame32^.linesize);
    Frame32ToBGLBitmap(pCodecCtx^.Width, pCodecCtx^.Height); {works on the global G_MyBGLBitmap}
  end;
  RenderRelevantBitmap(Approach);//4 needs G_MyBGLBitmap
end;

procedure TForm1.RenderRelevantBitmap(MethodIndex: integer);
begin
  if MethodIndex = 7 then
  begin
    PaintBox1.Canvas.draw(0, 0, G_MyBitmap24);
    PaintBox1.Invalidate;
  end;

  if MethodIndex = 7 then
  begin
    image1.Picture.Assign(G_MyBitmap24);
    image1.Refresh;
  end;


  if MethodIndex = 3 then
  begin
    G_MyBGLBitmap.Bitmap.Handle; {does nothing, by coincidence I found you have to do something with the Bitmap, like get the handle, else not working}
    G_OpenGLTexture := G_MyBGLBitmap.Texture;// not  MakeTextureAndFree because that frees the G_MyBGLBitmap
    G_OpenGLTexture.Draw(0, 0, 255);
    OpenGLControl1.SwapBuffers;
  end;

  {draw the regular bitmap to the  TBGLBitmap, than use get texture from it}
  if MethodIndex = 1 then
  begin
    G_MyBGLBitmap.CanvasBGRA.Draw(0, 0, G_MyBitmap24);
    G_OpenGLTexture := G_MyBGLBitmap.Texture;// not  MakeTextureAndFree because that frees the G_MyBGLBitmap
    G_OpenGLTexture.Draw(0, 0, 255);
    OpenGLControl1.SwapBuffers;
  end;

end;


function SetUpSDLStandAlone(swidth, sheight: integer): integer;
begin
  Result := -1;
  G_screen := SDL_CreateWindow('Fplay', SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, swidth, sheight, SDL_WINDOW_OPENGL);
  if not Assigned(G_screen) then Exit(7);
  G_renderer := SDL_CreateRenderer(G_screen, -1, SDL_RENDERER_ACCELERATED);
  if not Assigned(G_renderer) then Exit(8);
  G_texture := SDL_CreateTexture(G_renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING or SDL_TEXTUREACCESS_TARGET, swidth, sheight);
  if not Assigned(G_texture) then Exit(9);
  G_rect.x := 0;
  G_rect.y := 0;
  G_rect.w := swidth;
  G_rect.h := sheight;
  G_windowID := SDL_GetWindowID(G_screen);
end;

function SetUpSDLEmbedded(swidth, sheight: integer): integer;
begin
  Result := -1;
  G_screen := SDL_CreateWindowFrom(pointer(form1.Panel1.Handle));
  G_renderer := SDL_CreateRenderer(G_screen, -1, SDL_RENDERER_ACCELERATED);
  G_texture := SDL_CreateTexture(G_renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING or SDL_TEXTUREACCESS_TARGET, swidth, sheight);

  G_rect.x := 0;
  G_rect.y := 0;
  G_rect.w := swidth;
  G_rect.h := sheight;

 G_windowID := SDL_GetWindowID(G_screen);
end;

procedure ShowYUVFrameInSDL(frame: PAVFrame);
var
  small:TSDL_Rect;
begin
   small.x := 0;
  small.y := 0;
  small.w := form1.panel1.Width;
  small.h := form1.panel1.height;
  SDL_UpdateYUVTexture(G_texture, @G_rect, frame^.Data[0], frame^.linesize[0], frame^.Data[1], frame^.linesize[1], frame^.Data[2], frame^.linesize[2]);
  SDL_RenderClear(G_renderer);
  //SDL_RenderCopy(G_renderer, G_texture, nil, @G_rect);
  SDL_RenderCopy(G_renderer, G_texture, nil, @small);
  form1.panel1.BoundsRect;
  SDL_RenderPresent(G_renderer);
  if G_Startset = False then {IMPORTANT}
  begin
    TimerStart;
    G_Startset := True;
  end;
end;



procedure TForm1.OpenGLControl1Paint(Sender: TObject);
begin
 { if Assigned(G_OpenGLTexture) then
    G_OpenGLTexture.Draw(0, 0, 255);
  OpenGLControl1.SwapBuffers;}
end;


{decode and main2 below: never got it to work using parse...}

function decode(dec_ctx: PAVCodecContext; frame: PAVFrame; mypkt: PAVPacket; const filename: string): boolean;
var
  outfile: string;
  ret: integer;
begin
  ret := avcodec_send_packet(dec_ctx, mypkt);
  if ret < 0 then
  begin
    form1.memo1.Lines.add('Error sending a packet for decoding');
    Result := False;
    Exit;
  end;

  while ret >= 0 do
  begin
    ret := avcodec_receive_frame(dec_ctx, frame);
    if (ret = AVERROR_EAGAIN) or (ret = AVERROR_EOF) then
    begin
      Result := True;
      Exit;
    end
    else if ret < 0 then
      begin
        form1.memo1.Lines.add('Error during decoding');
        Result := False;
        Exit;
      end;

    form1.memo1.Lines.add(Format('saving %sframe %3d', [dec_ctx^.frame_number]));
    // fflush(stdout);

    (* the picture is allocated by the decoder, no need to free it *)
    //outfile := ChangeFileExt(filename, '');
    //pgm_save(@frame.data[0], frame.linesize[0], frame.width, frame.height, Format('%s-%d%s', [outfile, dec_ctx.frame_number, ExtractFileExt(filename)]));
  end;
  Result := True;
end;




end.
