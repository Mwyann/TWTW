unit CCM_Ani;

interface

uses Windows, SysUtils, Classes, Graphics, MMSystem, StdCtrls, ExtCtrls, GIFImage, FTGifAnimate;

type
  TCCMAni = class(TThread)
  private
    f:TStream;
    Sound:TMemoryStream;
    FrameRate:word;
    SoundDuration:cardinal; // en millisecondes
    SoundRate:word;
    offsetX,offsetY:integer;
    GIFFramems:word;
    ThisAniSaveToDisk:boolean;
    ThisAniSavePrefix:string;
    DiffPicture:TPicture; // utilisé pour la sauvegarde du GIF
    procedure InitAnim;
    procedure OpenAnim(FileName:string);
    procedure ExtractSound;
    procedure PlayTheSound;
    procedure StopTheSound;
    procedure SeekFrame;
    procedure LoadFrame;
    procedure CentralControl;
    procedure SaveGIFFrame;
    procedure Refresh;
  public
    PlayStart,PlayEnd,PlayPos:integer;
    constructor Create(FileName:string;X,Y:integer);
     destructor Destroy; override;
  protected
    procedure Execute; override;
  end;

  TCCMWav = class(TThread)
  private
    Sound:TMemoryStream;
    SoundDuration:cardinal;
    ThisAniSaveToDisk:boolean;
    ThisAniSavePrefix:string;
    procedure PlayTheSound;
    procedure StopTheSound;
  public
    constructor Create(FileName:string);
     destructor Destroy; override;
  protected
    procedure Execute; override;
  end;

procedure CCMPlayAni(FileName:string;X,Y:integer;isControlBar:boolean);
procedure CCMStopAni;
procedure CCMAddControlBar(x,y:smallint);
procedure CCMPlayWav(FileName:string);
procedure CCMStopWav;
procedure CCMRefresh;
function CCMIsPlaying:boolean;

type callbackProc=procedure;

var CCMCanvas:TCanvas;
    OnCCMFinished:callbackProc;
    CCMBufferImage:TBitmap;
    AniRect:TRect;
    AniSaveToDisk:boolean;
    AniSavePrefix:string;

implementation

uses CCM_Zip;

{$R CCM_Ani.res}

var colors:array[0..255] of longint;
    aniControlBar:boolean;
    cbx,cby:smallint; //Control bar position

procedure InitColors;
var palette:TBitmap;
    i:byte;

begin
  palette:=TBitmap.Create;
  palette.LoadFromResourceName(hinstance,'PALETTE');
  for i:=0 to 255 do colors[i]:=palette.Canvas.Pixels[i,0];
  palette.Free;
end;

procedure CCMAddControlBar(x,y:smallint);
var controlbar:TBitmap;
    pos:TRect;
begin
  controlbar:=TBitmap.Create;
  controlbar.LoadFromResourceName(hinstance,'CONTROLBAR');
  pos:=Rect(x,y,x+controlbar.Width,y+controlbar.Height);
  CCMBufferImage.Canvas.CopyRect(pos,controlbar.Canvas,controlbar.Canvas.ClipRect);
  controlbar.Free;
  cbx:=x;
  cby:=y;
end;


procedure TCCMAni.InitAnim;
var buf:array[0..30] of char;
    numframes,preloadsecs:word;

begin
  f.Seek(0,soFromBeginning);
  f.Read(buf,$1e);
  numframes:=ord(buf[3])*256+ord(buf[2]);
  FrameRate:=ord(buf[7])*256+ord(buf[6]);
  preloadsecs:=ord(buf[9])*256+ord(buf[8]);
  PlayStart:=FrameRate*preloadsecs;
  SoundRate:=ord(buf[19])*256+ord(buf[18]);
  PlayEnd:=PlayStart+numframes;
  PlayPos:=PlayStart;
end;

procedure TCCMAni.ExtractSound;
var buf:array[0..2047] of char;
    totalsize:cardinal;
    i,j:longint;

procedure copyftog(l:longint);
var mybuf:array[0..2047] of char;
    r:longint;
begin
  inc(totalsize,l);
  while l>0 do begin
    if l>2048 then r:=f.Read(mybuf,2048) else r:=f.Read(mybuf,l);
    Sound.WriteBuffer(mybuf,r);
    dec(l,r);
  end;
end;

procedure shiftchars(n:word);
var i:word;
begin
  for i:=pred(n) downto 1 do buf[i]:=buf[pred(i)];
end;

procedure writeheader();
var mybuf:array[0..11] of char;
begin
  mybuf[0]:='R';
  mybuf[1]:='I';
  mybuf[2]:='F';
  mybuf[3]:='F';
 {mybuf[4]:=#$D0;
  mybuf[5]:=#$EA;
  mybuf[6]:=#$04;
  mybuf[7]:=#$00;}  // Taille totale du fichier
  mybuf[8]:='W';
  mybuf[9]:='A';
  mybuf[10]:='V';
  mybuf[11]:='E';
  Sound.WriteBuffer(mybuf,12);
end;

procedure writeformat(smprate:longint);
var mybuf:array[0..31] of char;
begin
  mybuf[0]:='f';   // ID
  mybuf[1]:='m';
  mybuf[2]:='t';
  mybuf[3]:=' ';
  mybuf[4]:=#$10;  // Size
  mybuf[5]:=#$00;
  mybuf[6]:=#$00;
  mybuf[7]:=#$00;
  mybuf[8]:=#$01;  // FormatTag
  mybuf[9]:=#$00;
  mybuf[10]:=#$01; // Channels
  mybuf[11]:=#$00;
  mybuf[12]:=chr(smprate); // Samples per Sec
  mybuf[13]:=chr(smprate shr 8);
  mybuf[14]:=chr(smprate shr 16);
  mybuf[15]:=chr(smprate shr 24);
  mybuf[16]:=chr(smprate); // AvgByte per Sec
  mybuf[17]:=chr(smprate shr 8);
  mybuf[18]:=chr(smprate shr 16);
  mybuf[19]:=chr(smprate shr 24);
  mybuf[20]:=#$01; // BlockAlign
  mybuf[21]:=#$00;
  mybuf[22]:=#$08; // Bits per Sample
  mybuf[23]:=#$00;
  mybuf[24]:='d';
  mybuf[25]:='a';
  mybuf[26]:='t';
  mybuf[27]:='a';
 {mybuf[28]:=chr(l);
  mybuf[29]:=chr(l shr 8);
  mybuf[30]:=chr(l shr 16);
  mybuf[31]:=chr(l shr 24);}     // Longueur du son, sera mis en place plus tard
  Sound.WriteBuffer(mybuf,32);
end;

begin
  totalsize:=0;
  Sound.Clear;
  writeheader();
  writeformat(SoundRate);
  f.seek($1e, soFromBeginning);
  while f.Position+1 < f.Size do begin
    f.Read(buf,2);
    f.Read(buf,2);
    i:=ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,14);
    f.Read(buf,4);
    j:=ord(buf[3])*256*65536+ord(buf[2])*65536+ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,6);
    copyftog(i);
    f.Seek(j,soFromCurrent);
  end;
  Sound.Position:=$28;
  buf[0]:=chr(totalsize);
  buf[1]:=chr(totalsize shr 8);
  buf[2]:=chr(totalsize shr 16);
  buf[3]:=chr(totalsize shr 24);
  Sound.WriteBuffer(buf,4);
  SoundDuration:=round((totalsize*1000)/SoundRate);
  inc(totalsize,36);
  Sound.Position:=4;
  buf[0]:=chr(totalsize);
  buf[1]:=chr(totalsize shr 8);
  buf[2]:=chr(totalsize shr 16);
  buf[3]:=chr(totalsize shr 24);
  Sound.WriteBuffer(buf,4);
  if ThisAniSaveToDisk then Sound.SaveToFile(ThisAniSavePrefix+'.wav');
end;

procedure TCCMAni.SeekFrame;
var buf:array[0..14] of char;
    i,j,n:longint;

begin
  f.seek($1e, soFromBeginning);
  n:=0;
  while f.Position+1 < f.Size do begin
    f.Read(buf,2);
    f.Read(buf,2);
    i:=ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,14); // To be scanned !
    f.Read(buf,4);
    j:=ord(buf[3])*256*65536+ord(buf[2])*65536+ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,6);
    if n=PlayPos then begin
      f.Seek(-28,soFromCurrent);
      break; // Here we are.
    end else begin
      inc(n);
      f.Seek(i+j,soFromCurrent);
    end;
  end;
end;

procedure TCCMAni.LoadFrame;
var buf:array[0..655359] of char;
    i,j,k:longint;
    x,y,a,b,px,py:longint;
    onemore,skip:boolean;

procedure shiftchars(n:word);
var i:word;
begin
  for i:=pred(n) downto 1 do buf[i]:=buf[pred(i)];
end;

begin
  onemore:=false;
  skip:=true;
  if (f.Position+1 < f.Size) then begin
    f.Read(buf,2);
    f.Read(buf,2);
    i:=ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,14); // To be scanned !
    x:=offsetX+ord(buf[3])*256+ord(buf[2]);    // X start
    y:=offsetY+ord(buf[5])*256+ord(buf[4]);    // Y start
    a:=offsetX+ord(buf[7])*256+ord(buf[6]);    // X end
    b:=offsetY+ord(buf[9])*256+ord(buf[8]);    // Y end
    k:=ord(buf[13])*256*65536+ord(buf[12])*65536+ord(buf[11])*256+ord(buf[10]); // Number of pixels
    f.Read(buf,4);
    j:=ord(buf[3])*256*65536+ord(buf[2])*65536+ord(buf[1])*256+ord(buf[0]);
    f.Read(buf,6);
    f.seek(i, soFromCurrent);
    f.Read(buf,j);  // Read image data
    i:=0;
    px:=x;
    py:=y;
    if ((a-x)*(b-y))<>k then onemore:=true;  // If we got one more pixel line
    while i<j do begin
      b:=ord(buf[i]);
      inc(i);
      if b<$80 then begin  // Multiple pixels
        k:=colors[ord(buf[i])];    // Color (+19 ?)
        while b>0 do begin
          if (px=x) and ((not skip) and onemore) then begin
            skip:=true;
          end else begin
            if (px >= pred(AniRect.Left)) and (py >= pred(AniRect.Top)) and (px <= pred(AniRect.Right)) and (py <= AniRect.Bottom) then begin
                if ThisAniSaveToDisk then if CCMBufferImage.Canvas.Pixels[px,py] <> k then DiffPicture.Bitmap.Canvas.Pixels[px,py]:=k;
                CCMBufferImage.Canvas.Pixels[px,py]:=k;
              end;
            inc(px);
            skip:=false;
          end;
          dec(b);
          if px=a then begin; px:=x; inc(py); end;
        end;
        inc(i);
      end else begin  // Singular pixels
        while b>$80 do begin
          if (px=x) and ((not skip) and onemore) then begin
            skip:=true;
          end else begin
            if (px >= pred(AniRect.Left)) and (py >= pred(AniRect.Top)) and (px <= pred(AniRect.Right)) and (py <= pred(AniRect.Bottom)) then begin
              k:=colors[ord(buf[i])];
              if ThisAniSaveToDisk then if CCMBufferImage.Canvas.Pixels[px,py] <> k then DiffPicture.Bitmap.Canvas.Pixels[px,py]:=k;
              CCMBufferImage.Canvas.Pixels[px,py]:=k;
            end;
            inc(px);
            skip:=false;
          end;
          inc(i);dec(b);
          if px=a then begin; px:=x; inc(py); end;
        end;
      end;
    end;
  end;
end;

procedure TCCMAni.OpenAnim(FileName:string);
begin
  f:=OpenFile(FileName);
  if f <> nil then begin
    InitAnim;
    ExtractSound;
  end;
end;

constructor TCCMAni.Create(FileName:string;X,Y:integer);
var fullname:string;
    i:word;
begin
  inherited Create(true);
  Sound:=TMemoryStream.Create;
  offsetX:=X;
  offsetY:=Y;
  ThisAniSaveToDisk:=AniSaveToDisk;
  ThisAniSavePrefix:=AniSavePrefix;
  if (ThisAniSavePrefix = 'res?') then begin
    fullname:=GetCurrentDir()+'\res\'+filename;
    i:=length(fullname);
    while (i>0) and (fullname[i]<>'.') do dec(i);
    ThisAniSavePrefix:=copy(fullname,1,i-1);
    ForceDirectories(ExtractFileDir(ThisAniSavePrefix+'.gif'));
  end;
  OpenAnim(FileName);
  FreeOnTerminate:=true;
  Priority:=tpNormal;
  DiffPicture := nil;
end;

destructor TCCMAni.Destroy;
begin
  if DiffPicture <> nil then DiffPicture.Free;
  f.Free;
  Sound.Free;
  inherited;
end;

procedure CCMRefresh;
begin
  CCMCanvas.CopyRect(CCMCanvas.ClipRect,CCMBufferImage.Canvas,CCMCanvas.ClipRect);
end;

procedure TCCMAni.Refresh;
begin
  CCMRefresh;
end;

procedure TCCMAni.PlayTheSound;
begin
  if (not ThisAniSaveToDisk) then PlaySound(Sound.Memory,0,SND_ASYNC or SND_MEMORY);
end;

procedure TCCMAni.StopTheSound;
begin
  PlaySound(nil,0,SND_ASYNC);
end;

procedure TCCMAni.CentralControl;
var PerctPos,i,j:smallint;
begin
  CCMRefresh;
  LoadFrame;
  inc(PlayPos);
  if aniControlBar then begin
    CCMAddControlBar(cbx,cby);
    PerctPos:=(30*(PlayPos-PlayStart)) div (PlayEnd-PlayStart);
    for i:=0 to PerctPos-1 do
      for j:=0 to 8 do begin
        if (i = 0) or (j = 0) then
          CCMBufferImage.Canvas.Pixels[cbx+i+39,cby+j+7]:=$BB
        else
          CCMBufferImage.Canvas.Pixels[cbx+i+39,cby+j+7]:=$DD;
        if ThisAniSaveToDisk then
          if (i = 0) or (j = 0) then
            DiffPicture.Bitmap.Canvas.Pixels[cbx+i+39,cby+j+7]:=$BB
          else
            DiffPicture.Bitmap.Canvas.Pixels[cbx+i+39,cby+j+7]:=$DD;
      end;
  end;
end;

var Ani:TCCMAni;
    Wav:TCCMWav;

procedure CCMFinishedPlaying;
begin
  Ani:=nil;
  Wav:=nil;
  If (Assigned(OnCCMFinished)) then OnCCMFinished;
end;

procedure TCCMAni.Execute;
var AnimBegin,AnimEnd:cardinal;
    WaitFor,c:longint;
    GIF:TGIFImage; // GIF
begin
  Synchronize(SeekFrame);
  Synchronize(PlayTheSound);
  AnimBegin:=GetTickCount();
  if ThisAniSaveToDisk then begin
    GifAnimateBegin(638, 458);
    GIFFramems:=0;
    Synchronize(SaveGIFFrame);
    GIFFramems:=trunc(1000/FrameRate);
  end;
  repeat
    Synchronize(CentralControl);
    WaitFor:=trunc((PlayPos-PlayStart)*1000/FrameRate)-(GetTickCount()-AnimBegin);
    if ThisAniSaveToDisk then begin
      if (PlayPos=PlayEnd) then GIFFramems:=60000;
      Synchronize(SaveGIFFrame);
      WaitFor:=0;
    end;
    if WaitFor>0 then Sleep(WaitFor);
  until (PlayPos=PlayEnd) or (Terminated);
  Synchronize(Refresh);
  AnimEnd:=GetTickCount();
  WaitFor:=SoundDuration-(AnimEnd-AnimBegin);
  if ThisAniSaveToDisk then begin
    GIF:=GifAnimateEndGif;
    GIF.SaveToFile(ThisAniSavePrefix+'.gif');
    GIF.Free;
    WaitFor:=0;
  end;
  while (not Terminated) and (Waitfor > 0) do begin
    if (WaitFor > 300) then c:=300 else c:=WaitFor;
    dec(WaitFor,c);
    Sleep(c);
  end;
  Synchronize(StopTheSound);
  if (ThisAniSaveToDisk) then AniSaveToDisk:=false;
  CCMFinishedPlaying;
end;

procedure TCCMAni.SaveGIFFrame;
var skipFirstFrame:boolean;
begin
  skipFirstFrame:=false;
  if DiffPicture = nil then begin
    DiffPicture := TPicture.Create;
    DiffPicture.Bitmap.Width:=638;
    DiffPicture.Bitmap.Height:=458;
    DiffPicture.Bitmap.Canvas.CopyRect(DiffPicture.Bitmap.Canvas.ClipRect,CCMBufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
    if (AniSavePrefix = 'res?') then skipFirstFrame:=true;
  end;
  if not skipFirstFrame then GifAnimateAddImage(DiffPicture.Graphic,$101010,GIFFramems,1);
  DiffPicture.Bitmap.Canvas.Brush.Color:=$101010;
  DiffPicture.Bitmap.Canvas.FillRect(DiffPicture.Bitmap.Canvas.ClipRect);
end;

function CCMIsPlaying:boolean;
begin
  Result:=((Assigned(Ani)) and (not Ani.Terminated)) or ((Assigned(Wav)) and (not Wav.Terminated));
end;

procedure CCMPlayAni(FileName:string;X,Y:integer;isControlBar:boolean);
begin
  CCMStopAni;
  aniControlBar:=isControlBar;
  Ani:=TCCMAni.Create(FileName,X,Y);
  Ani.Resume;
end;

procedure CCMStopAni;
begin
  if CCMIsPlaying then begin
    if (Ani <> nil) then begin
      if (not Ani.ThisAniSaveToDisk) then begin
        Ani.StopTheSound;
        Ani.Terminate;
      end;
    end;
    if (Wav <> nil) then begin
      Wav.StopTheSound;
      Wav.Terminate;
    end;
    While CCMIsPlaying do;
  end;
end;

constructor TCCMWav.Create(FileName:string);
var fullname:string;
    i:word;
begin
  inherited Create(true);
  Sound:=OpenFile(FileName);
  FreeOnTerminate:=true;
  Priority:=tpNormal;

  ThisAniSaveToDisk:=AniSaveToDisk;
  ThisAniSavePrefix:=AniSavePrefix;
  if (ThisAniSavePrefix = 'res?') then begin
    fullname:=GetCurrentDir()+'\res\'+filename;
    i:=length(fullname);
    while (i>0) and (fullname[i]<>'.') do dec(i);
    ThisAniSavePrefix:=copy(fullname,1,i-1);
    ForceDirectories(ExtractFileDir(ThisAniSavePrefix+'.wav'));
  end;
end;

destructor TCCMWav.Destroy;
begin
  Sound.Free;
  inherited;
end;

procedure TCCMWav.Execute;
var c:cardinal;
begin
  if ThisAniSaveToDisk then begin
    Sound.SaveToFile(ThisAniSavePrefix+'.wav');
  end else begin
    Synchronize(PlayTheSound);
    repeat
      if SoundDuration > 300 then c:=300 else c:=SoundDuration;
      dec(SoundDuration,c);
      Sleep(c);
    until (SoundDuration = 0) or Terminated;
    Synchronize(StopTheSound);
  end;
  CCMFinishedPlaying;
end;

procedure TCCMWav.PlayTheSound;
var c:cardinal;
begin
  Sound.Seek($1C,soFromBeginning);
  Sound.Read(c,4);
  SoundDuration:=trunc(1000*Sound.size/c);
  PlaySound(Sound.Memory,0,SND_ASYNC or SND_MEMORY);
end;

procedure TCCMWav.StopTheSound;
begin
  PlaySound(nil,0,SND_ASYNC);
end;

procedure CCMPlayWav(FileName:string);
begin
  CCMStopAni;
  Wav:=TCCMWav.Create(FileName);
  Wav.Resume;
end;

procedure CCMStopWav;
begin
  CCMStopAni;
end;

begin
  CCMBufferImage:=TBitmap.Create;
  CCMBufferImage.Width:=638;
  CCMBufferImage.Height:=458;
  CCMCanvas:=nil;
  Ani:=nil;
  Wav:=nil;
  OnCCMFinished:=nil;
  AniRect:=Rect(0,0,0,0);
  AniSaveToDisk:=false;
  InitColors;
end.
