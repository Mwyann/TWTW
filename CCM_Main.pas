unit CCM_Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, DIB, MMSystem, clipbrd, Menus;

type
  TTWTW = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    pbp: TPanel;
    pbx: TPaintBox;
    IndexEdit: TEdit;
    IndexList: TListBox;
    NextPageTimer: TTimer;
    Edit1: TEdit;
    CancelButton: TButton;
    ScrollBox: TScrollBox;
    ImageScrolled: TImage;
    PopupMenu1: TPopupMenu;
    MenuSauveAnim: TMenuItem;
    N1: TMenuItem;
    MenuAPropos: TMenuItem;
    MenuRestart: TMenuItem;
    MenuRandomPage: TMenuItem;
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure pbxPaint(Sender: TObject);
    procedure pbxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure pbxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure IndexListDblClick(Sender: TObject);
    procedure NextPageTimerTimer(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure MenuSauveAnimClick(Sender: TObject);
    procedure MenuAProposClick(Sender: TObject);
    procedure MenuRestartClick(Sender: TObject);
    procedure MenuRandomPageClick(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  TWTW: TTWTW;

implementation

uses CCM_Png, CCM_Ani, CCM_Zip;

type TLINK=record
    linktype:smallint;
    x1,y1,x2,y2:smallint;
    fx1,fy1,fx2,fy2:smallint;
    xoffset,yoffset:smallint;
    cursor:IDPOINTER;
    numactions:smallint;
    actions:array[0..1] of TACTION;
    anim:string;
    anim_skip:IDPOINTER;
    sound:string;
    letter:smallint;
  end;

type TDISPLAY=record
    actualPage:IDPOINTER;
    links:array[0..100] of TLINK;
    numlinks:smallint;
    actualItems:array[0..100] of TITEM;
    actualNumitems:smallint;
    actualBasedir:string;
    xoff,yoff:smallint;
    actualrelated_principles_popup:IDPOINTER;
    actualmachines_page:IDPOINTER;
    actualinventors_page:IDPOINTER;
    actualtimeline_page:IDPOINTER;
    x1,y1,x2,y2:smallint;
    PageImage:TBitmap;
  end;

var nextpage_ani:IDPOINTER;
    nextpage_load:IDPOINTER;
    actualletter:smallint;
    BufferImage:TBitmap;
    actualPages:array[0..7] of TDISPLAY; // 0 = main frame, 1 to 7 = popups
    actualPageLevel:smallint;
    predPageLevel:smallint;
    history:array[0..1000] of IDPOINTER;
    numhistory:smallint;
    debug:boolean;

{$R *.dfm}

procedure centerizeform(f:TForm);
begin
  f.Top:=(Screen.WorkAreaHeight-f.Height) div 2;
  if f.Top<0 then f.Top:=0;
  f.Left:=(Screen.WorkAreaWidth-f.Width) div 2;
  if f.Left<0 then f.Left:=0;
end;

function dec2hex(b:byte):string;
const hex:string[16]='0123456789ABCDEF';
begin
  dec2hex:=hex[succ(b shr 4)]+hex[succ(b and 15)];
end;

procedure setCursor(idcursor:smallint);
var cursortype:string;
begin
  if idcursor >= 0 then begin
    cursortype:=strings.strings[idcursor];
    if (cursortype = 'normal') then begin
      TWTW.pbx.Cursor:=crDefault;
    end;
    if (cursortype = 'Hand') then begin
      TWTW.pbx.Cursor:=crHandPoint;
    end;
  end else begin
    if (idcursor = -1) then begin
      TWTW.pbx.Cursor:=crDefault;
    end;
    if (idcursor = -2) then begin
      TWTW.pbx.Cursor:=crHourGlass;
    end;
  end;
end;

procedure simulateMouseMove;
var pt : TPoint;
begin
  GetCursorPos(pt);
  SetCursorPos(pt.x+1, pt.y+1);
  Application.ProcessMessages;
  GetCursorPos(pt);
  SetCursorPos(pt.x-1, pt.y-1);
  Application.ProcessMessages;
end;

procedure displayPicture(filename:string;xoffset,yoffset:smallint);
var bmp:TBitmap;
    bmpto:TRect;
    bmpstream:TStream;
begin
  bmpstream:=OpenFile(filename);
  bmp:=TBitmap.Create();
  bmp.LoadFromStream(bmpstream);
  bmpstream.free;
  bmpto:=Rect(xoffset,yoffset,xoffset+bmp.Canvas.ClipRect.Right,yoffset+bmp.Canvas.ClipRect.Bottom);
  with actualPages[actualPageLevel] do begin
    {if (x1 = -1) or (x1 > xoffset) then }x1:=xoffset;
    {if (y1 = -1) or (y1 > yoffset) then }y1:=yoffset;
    {if (x2 = -1) or (x2 < xoffset+bmp.Canvas.ClipRect.Right) then }x2:=xoffset+bmp.Canvas.ClipRect.Right;
    {if (y2 = -1) or (y2 < yoffset+bmp.Canvas.ClipRect.Bottom) then }y2:=yoffset+bmp.Canvas.ClipRect.Bottom;
    AniRect:=Rect(x1,y1,x2,y2);
  end;
  BufferImage.Canvas.CopyRect(bmpto,bmp.Canvas,bmp.Canvas.ClipRect);
  bmp.free;
end;

procedure addItems(page:TPAGE;basedir:string;xoff_,yoff_:smallint);
var item:smallint;
    filename:string;
    bmp:TBitmap;
    bmpto:TRect;
    bmpstream:TStream;
begin
  actualletter:=-1;
  with actualPages[actualPageLevel] do begin
  with page do
    for item:=1 to numitems do with items[item-1] do begin
      actualItems[actualNumitems]:=items[item];
      inc(actualNumitems);
      links[numlinks].x1:=xoff_+x1;
      links[numlinks].y1:=yoff_+y1;
      links[numlinks].x2:=xoff_+x2;
      links[numlinks].y2:=yoff_+y2;
      links[numlinks].xoffset:=xoff_;
      links[numlinks].yoffset:=yoff_;
      links[numlinks].cursor:=cursor;
      links[numlinks].linktype:=itemtype;
      if (itemtype = 601) then begin
        filename:=basedir+strings.strings[image]+'.DIB';
        if (debug) then twtw.memo1.lines.add('Background image '+filename+' '+inttostr(xoff_)+' '+inttostr(yoff_));
        displayPicture(filename,xoff_,yoff_);
      end;
      links[numlinks].fx1:=actualPages[actualPageLevel].x1;
      links[numlinks].fy1:=actualPages[actualPageLevel].y1;
      links[numlinks].fx2:=actualPages[actualPageLevel].x2;
      links[numlinks].fy2:=actualPages[actualPageLevel].y2;
      if (itemtype = 602) then begin
        CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
        CCMaddControlbar(xoff_+x1,yoff_+y1);
        BufferImage.Canvas.CopyRect(CCMBufferImage.Canvas.ClipRect,CCMBufferImage.Canvas,BufferImage.Canvas.ClipRect);
        //TWTW.memo1.Lines.add('Animation with control bar');
        filename:=basedir+strings.strings[anim]+'.ANI';
        links[numlinks].anim:=filename;
        links[numlinks].anim_skip:=actualPage;
        if (autostart = 0) then begin
          AniRect:=Rect(links[numlinks].fx1,links[numlinks].fy1,links[numlinks].fx2,links[numlinks].fy2);
          CCMPlayAni(filename,xoff_,yoff_,true);
          setCursor(-2);
          nextpage_ani:=-2;
          links[numlinks].anim_skip:=-2;
          dec(numhistory); // Doesn't count in the history
        end;
        inc(numlinks);
      end;
      if (itemtype = 603) then begin
        // item_props : 4 (mainly) or 5 or 1
        if (debug) then twtw.memo1.lines.add('Link: '+inttostr(links[numlinks].x1)+':'+inttostr(links[numlinks].y1)+'/'+inttostr(links[numlinks].x2)+':'+inttostr(links[numlinks].y2));
        links[numlinks].numactions:=numactions;
        links[numlinks].actions[0]:=actions[0];
        links[numlinks].actions[1]:=actions[1];
        inc(numlinks);
      end;
      if (itemtype = 604) then begin
        links[numlinks].numactions:=0;
        links[numlinks].letter:=letter;
        links[numlinks].anim_skip:=page_skip;
        actualletter:=0;
        inc(numlinks);
      end;
      if (itemtype = 606) then begin
        filename:=basedir+strings.strings[anim]+'.ANI';
        //TWTW.memo1.Lines.add('NAV bar '+filename);
        links[numlinks].anim:=filename;
        links[numlinks].anim_skip:=page_skip;
        //TWTW.Memo1.lines.add('(Theorically) Link '+inttostr(item_id)+' to '+inttostr(page_skip));
        // The order in the file is wrong!!
        links[numlinks].anim_skip:=fixedNavBar(item_id, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page);
        inc(numlinks);
      end;
      if (itemtype = 607) then begin
        filename:=basedir+strings.strings[anim]+'.ANI';
        if (debug) then twtw.memo1.lines.add('Animation ('+inttostr(item_props)+' '+filename+': '+inttostr(links[numlinks].x1)+':'+inttostr(links[numlinks].y1)+'/'+inttostr(links[numlinks].x2)+':'+inttostr(links[numlinks].y2));
        //setCursor(cursor);
        if (item_props = 32) then begin
          nextpage_ani:=nextpage;
          CCMPlayAni(filename,xoff_,yoff_,false);
          setCursor(-2);
          dec(numhistory); // Doesn't count in the history
        end;
        if (item_props = 0) or (item_props = 16) then begin
          links[numlinks].anim:=filename;
          if (page_skip = 1) then begin
            links[numlinks].anim_skip:=nextpage;
          end else begin
            links[numlinks].anim_skip:=-1;
          end;
        end;
        inc(numlinks);
      end;
      if (itemtype = 608) then begin
        TWTW.CancelButton.Left:=links[numlinks].x1;
        TWTW.CancelButton.Top:=links[numlinks].y1;
        TWTW.CancelButton.Width:=links[numlinks].x2-links[numlinks].x1;
        TWTW.CancelButton.Height:=links[numlinks].y2-links[numlinks].y1;
        TWTW.CancelButton.Visible:=true;
        inc(numlinks);
      end;
      if (itemtype = 609) then begin
        filename:=basedir+strings.strings[image]+'.DIB';
        bmpstream:=OpenFile(filename);
        bmp:=TBitmap.Create();
        bmp.LoadFromStream(bmpstream);
        bmpstream.free;
        bmpto:=Rect(0,0,bmp.Canvas.ClipRect.Right,bmp.Canvas.ClipRect.Bottom);
        TWTW.ImageScrolled.Width:=500;
        TWTW.ImageScrolled.Height:=2000; // Get enough space for all the future images
        TWTW.ScrollBox.Visible:=true;
        TWTW.ScrollBox.VertScrollBar.Position:=0;
        TWTW.ImageScrolled.Canvas.CopyRect(bmpto,bmp.Canvas,bmpto);
        TWTW.ImageScrolled.Width:=bmp.Canvas.ClipRect.Right;
        TWTW.ImageScrolled.Height:=bmp.Canvas.ClipRect.Bottom;
        bmp.free;
      end;
    end;
    if (actualletter = 0) then displayPicture(actualBaseDir+'AZAZ0MAA.DIB',255,105);
  end;
end;

procedure displayFrame(idframe,typepage:smallint);
var i,j:smallint;
    frame:TPAGE;
begin
  with actualPages[actualPageLevel] do
  for i:=0 to info.numframes-1 do with info.frames[i] do if (id_frame = idframe) then begin
    for j:=0 to numinfos-1 do with infos[j] do begin
      if (id_frame2 = 1) then begin
        if (typepage = 102) then begin
          xoff:=offset_x;
          yoff:=offset_y;
        end;
      end else begin
        if (typeframe2 <> 202) then begin
          frame:=ReadPagePNG(idpointer_frame);
          addItems(frame,'',imageoffset_x,imageoffset_y);
        end;
      end;
    end;
  end;
end;

procedure displayPage(idpage:IDPOINTER);
var page:TPAGE;
    basedir:string;
begin
  if CCMIsPlaying then CCMStopAni;
  while CCMIsPlaying do;
  TWTW.Edit1.Text:=inttostr(idpage);
  TWTW.IndexEdit.Visible:=(idpage = CCMIndex);
  TWTW.IndexList.Visible:=(idpage = CCMIndex);
  TWTW.CancelButton.Visible:=false;
  TWTW.ScrollBox.Visible:=false;
  TWTW.MenuSauveAnim.Checked:=AniSaveToDisk;
  CCMStopAni;
  page:=ReadPagePNG(idpage);
  if (page.typepage <> 102) then
   if (actualPageLevel = 0) and (actualPages[actualPageLevel].actualPage <> idpage) and (actualPageLevel = predPageLevel) then
    inc(actualPageLevel) else
   else actualPageLevel:=0;
  with actualPages[actualPageLevel] do begin
  actualPage:=idpage;
  nextpage_ani:=-1;
  numlinks:=0;
  actualNumitems:=0;
  actualrelated_principles_popup:=-1;
  actualmachines_page:=-1;
  actualinventors_page:=-1;
  actualtimeline_page:=-1;
  x1:=-1;
  y1:=-1;
  x2:=-1;
  y2:=-1;
  if (debug) then twtw.memo1.lines.add('Reading page #'+inttostr(idpage));
  with page do begin
    if (debug) then twtw.memo1.lines.add('Page type: '+inttostr(typepage));
    if (debug) then twtw.memo1.lines.add('Frame: '+inttostr(id_frame));
    basedir:=strings.strings[basedirectory];
    if ((basedir <> '\HELP\') or (actualPageLevel <> predPageLevel)) then begin
      // - Aide : problèmes avec quelques pages (gros souk des offsets). Résultat : les liens entre les pages "molécules" par ex changent
      //   la position de la fenêtre (même déplacée), mais pas les pages d'aide (si déplacement de la fenêtre, on reste)...
      xoff:=actualPages[0].xoff;
      yoff:=actualPages[0].yoff;
    end;
    if (typepage=101) then begin  // Popup
      BufferImage.Canvas.CopyRect(actualPages[pred(actualPageLevel)].PageImage.Canvas.ClipRect,actualPages[pred(actualPageLevel)].PageImage.Canvas,BufferImage.Canvas.ClipRect);
    end;
    if (typepage=102) then begin  // Full page
      if (numhistory >= 0) then begin
        if history[numhistory] <> idpage then begin
          inc(numhistory);
          if (numhistory >= 0) then history[numhistory]:=idpage;
        end;
      end else begin
        inc(numhistory);
        if (numhistory >= 0) then history[numhistory]:=idpage;
      end;
      if (more_infos = 1) and (links_infos = 0) then begin
        actualrelated_principles_popup:=related_principles_popup;
        actualmachines_page:=machines_page;
        actualinventors_page:=inventors_page;
        actualtimeline_page:=timeline_page;
      end;
    end;
    if (typepage = 103) then begin
      BufferImage.Canvas.CopyRect(actualPages[pred(actualPageLevel)].PageImage.Canvas.ClipRect,actualPages[pred(actualPageLevel)].PageImage.Canvas,BufferImage.Canvas.ClipRect);
    end;
    displayFrame(id_frame,typepage);
    if ((basedir <> '\HELP\') or (actualPageLevel <> predPageLevel)) then begin
      inc(xoff,xoffset);
      inc(yoff,yoffset);
    end;
    if (debug) then twtw.memo1.lines.add('Base directory: '+basedir);
    actualBasedir:=basedir;
    if (debug) then twtw.memo1.lines.add('Loading items: '+inttostr(numitems));
    addItems(page,basedir,xoff,yoff);
  end;
  CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
  actualPages[actualPageLevel].PageImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,actualPages[actualPageLevel].PageImage.Canvas.ClipRect);
  TWTW.pbx.Refresh;
  simulateMouseMove;
  if (numhistory < 0) and (idpage = CCMWorkshop) then numhistory:=0;
  end;
  predPageLevel:=actualPageLevel;
end;

procedure FinishedAnimation;
begin
  nextpage_load:=-1;
  if (nextpage_ani > -1) then nextpage_load:=nextpage_ani
    else if (nextpage_ani = -1) then nextpage_load:=actualPages[actualPageLevel].actualPage;
  TWTW.NextPageTimer.Enabled:=true;
end;

procedure TTWTW.Button1Click(Sender: TObject);
begin
  displayPage(strtoint(Edit1.Text));
end;

procedure TTWTW.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if CCMIsPlaying then begin
    CCMStopAni;
  end;
  if (debug) then memo1.lines.add('Closing...');
  ClosePNG;
  if (TWTWZip <> nil) then begin
    TWTWZip.Close;
    TWTWZip.Free;
  end;
  if (debug) then memo1.lines.add('Bye!');
end;

procedure TTWTW.FormShow(Sender: TObject);
var i:word;
    s,param:string;
begin
  memo1.Lines.Clear;
  param:='TWTW';
  debug:=false;
  if (paramstr(1) = '--debug') then debug:=true;
  if (paramcount > 0) then param:=paramstr(paramcount);
  if FileExists(param+'.ZIP') then begin
    TWTWZip:=TZipFile.Create;
    TWTWZip.OpenFromFile(param+'.ZIP');
    TWTWZip.LoadZip;
  end else begin
    TWTWZip:=nil;
  end;
  actualPageLevel:=0;
  numhistory:=-10;history[0]:=CCMWorkshop;
  if ((paramcount > 0) and (TWTWZip = nil)) then s:=param else s:='.';
  while (s<>'') and (s[length(s)] = '\') do delete(s,length(s),1);
  cdroot:=s;
  if (debug) then memo1.lines.add('Loading...');
  if not OpenPNG('DKCODE\TWTW.PNG') then begin
    Application.MessageBox('Fichier TWTW.ANI non trouvé ou illisible, spécifiez le chemin en ligne de commande.','Erreur',mb_ICONSTOP);
    Application.Terminate;
    exit;
  end;
  if (debug) then memo1.lines.add('Loaded OK');
  edit1.Text:=inttostr(info.page_start);
  BufferImage:=TBitmap.Create;
  BufferImage.Width:=info.screenwidth-2; // 638
  BufferImage.Height:=info.screenheight-20; // 460
  for i:=0 to 7 do begin
    actualPages[i].PageImage:=TBitmap.Create;
    actualPages[i].PageImage.Width:=info.screenwidth-2; // 638
    actualPages[i].PageImage.Height:=info.screenheight-20; // 460
  end;
  for i:=0 to index.indexlen-1 do IndexList.Items.Add(strings.strings[index.indexitems[i].indexword]);
  TWTW.Width:=info.screenwidth+6;
  pbx.width:=info.screenwidth;
  if (not debug) then begin
    TWTW.Height:=info.screenheight+5;
    Button1.Click;
  end;
  pbx.height:=info.screenheight;
  IndexEdit.Visible:=false;
  IndexList.Visible:=false;
  ScrollBox.Left:=CCMScrollBoxPos[0];
  ScrollBox.Top:=CCMScrollBoxPos[1];
  ScrollBox.Width:=CCMScrollBoxPos[2];
  ScrollBox.Height:=CCMScrollBoxPos[3];
  centerizeform(TWTW);
end;

procedure TTWTW.FormCreate(Sender: TObject);
begin
  CCMCanvas:=pbx.Canvas;
  OnCCMFinished:=FinishedAnimation;
  pbp.DoubleBuffered:=true;
end;

procedure TTWTW.pbxPaint(Sender: TObject);
begin
  CCMRefresh;
end;

procedure TTWTW.pbxMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var i:smallint;
    linkFound:boolean;
begin
  with actualPages[actualPageLevel] do begin
  if not (CCMIsPlaying) then begin
    linkFound:=false;
    for i:=0 to numlinks-1 do with links[i] do begin
      if (x >= x1) and (y >= y1) and (x <= x2) and (y <= y2) then begin
        linkFound:=true;
        //CCMCanvas.Brush.Color:=$cc0000; CCMCanvas.Pen.Color:=$cc0000; CCMCanvas.Rectangle(x1,y1,x2,y2);
        setCursor(cursor);
      end;
    end;
    if not linkFound then setCursor(-1);
  end;
  end;
end;

procedure TTWTW.pbxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var i,j,k:smallint;
    filename:string;
    nextpage:IDPOINTER;
    nextlevel:smallint;
    actionTaken:boolean;

begin
  if Button <> mbLeft then exit;
  if CCMIsPlaying then begin
    CCMStopAni;
  end else with actualPages[actualPageLevel] do begin
    nextpage:=-1;
    nextpage_ani:=-1;
    nextlevel:=actualPageLevel;
    actionTaken:=false;
    if (actualPageLevel > 0) and (not ((x >= x1) and (y >= y1) and (x <= x2) and (y <= y2))) then begin
      dec(nextlevel);
      nextpage:=actualPages[nextlevel].actualPage;
    end else
    for i:=1 to numlinks do if not actionTaken then with links[i-1] do begin
      if (x >= x1) and (y >= y1) and (x <= x2) and (y <= y2) then begin
        if (debug) then twtw.memo1.lines.add(inttostr(linktype));
        if (linktype = 602) then begin
          actionTaken:=true;
          nextpage_ani:=anim_skip;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          CCMPlayAni(anim,xoff,yoff,true);
          setCursor(-2);
        end;
        if (linktype = 603) then begin
          for j:=1 to numactions do with actions[j-1] do begin
            if (typeaction = 1) then begin
              inc(nextlevel);
              //nextlevel:=actualPageLevel+1;
              nextpage:=popup_id;
            end;
            if (typeaction = 2) then begin
              for k:=0 to actualNumitems-1 do if (actualItems[k].item_id = item_id) then begin
                if (actualItems[k].itemtype = 602) then begin
                  if (debug) then twtw.memo1.lines.add('Animation with control bar');
                  filename:=actualBaseDir+strings.strings[actualItems[k].anim]+'.ANI';
                  actionTaken:=true;
                  if (actualItems[k].autostart = 0) then nextpage_ani:=-2;
                  AniRect:=Rect(fx1,fy1,fx2,fy2);
                  CCMPlayAni(filename,xoff,yoff,true);
                  setCursor(-2);
                end;
              end;
            end;
            if (typeaction = 3) then begin
              nextpage:=linkto;
            end;
            if (typeaction = 4) then begin
              filename:=actualBaseDir+strings.strings[soundtoplay]+'.WAV';
              setCursor(-2);
              CCMPlayWav(filename);
            end;
            if (typeaction = 7) then begin
              filename:=actualBaseDir+strings.strings[anim]+'.ANI';
              actionTaken:=true;
              AniRect:=Rect(fx1,fy1,fx2,fy2);
              CCMPlayAni(filename,xoff,yoff,false);
              setCursor(-2);
            end;
            if (typeaction = 11) then begin
              if (command = 1) then begin // Copier
                clipboard.assign(actualPages[0].PageImage);
                Application.MessageBox('Image copiée dans le presse-papiers !','CCM',mb_ICONINFORMATION);
                //dec(nextlevel);
                //nextpage:=actualPages[nextlevel].actualPage;
              end;
              if (command = 2) then begin // Imprimer
                Application.MessageBox('Non supporté','Non supporté',mb_ICONSTOP);
              end;
              if (command = 3) then begin // Configurer impression
                Application.MessageBox('Non supporté','Non supporté',mb_ICONSTOP);
              end;
            end;
            if (typeaction = 12) then begin
              //nextlevel:=actualPageLevel-1;
              dec(nextlevel);
              nextpage:=actualPages[nextlevel].actualPage;
            end;
          end;
        end;
        if (linktype = 604) then begin
          actionTaken:=true;
          if (letter >= 0) and (letter < 26) then begin
            actualletter:=letter;
          end else begin
            if (letter = 26) then begin
              dec(actualletter);
              if (actualletter < 0) then actualletter:=25;
            end;
            if (letter = 27) then begin
              inc(actualletter);
              if (actualletter > 25) then actualletter:=0;
            end;
            if (letter = 28) then begin
              if (debug) then twtw.memo1.lines.add('Other letter movement: OK');
              for j:=1 to numlinks do if (links[j-1].letter = actualletter) then nextpage_ani:=links[j-1].anim_skip;
              AniRect:=Rect(fx1,fy1,fx2,fy2);
              CCMPlayAni(actualBaseDir+'AZAZ0M'+chr(ord('A')+actualletter)+'A.ANI',xoff,yoff,false);
              setCursor(-2);
            end;
          end;
          if (nextpage_ani = -1) then begin
            if (debug) then twtw.memo1.lines.add('Current letter: '+chr(ord('A')+actualletter));
            PlaySound(TMemoryStream(OpenFile(actualBaseDir+'DIAL.WAV')).Memory,0,SND_ASYNC or SND_MEMORY);
            displayPicture(actualBaseDir+'AZAZ0M'+chr(ord('A')+actualletter)+'A.DIB',255,105);
            CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
            actualPages[actualPageLevel].PageImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,actualPages[actualPageLevel].PageImage.Canvas.ClipRect);
            TWTW.pbx.Refresh;
          end;
        end;
        if (linktype = 606) then begin
          nextpage_ani:=anim_skip;
          if (anim_skip = -51) and (numhistory > 0) then begin
            dec(numhistory);
            nextpage_ani:=history[numhistory];
          end;
          actionTaken:=true;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          CCMPlayAni(anim,xoffset,yoffset,false);
          setCursor(-2);
        end;
        if (linktype = 607) then begin
          nextpage_ani:=anim_skip;
          actionTaken:=true;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          CCMPlayAni(anim,xoffset,yoffset,false);
          setCursor(-2);
        end;
        if (linktype = 608) then begin
          //nextlevel:=actualPageLevel-1;
          dec(nextlevel);
          nextpage:=actualPages[nextlevel].actualPage;
        end;
      end;
    end;
    if (nextpage > -1) then begin
      actualPageLevel:=nextlevel;
      displayPage(nextpage);
    end;
  end;
end;

procedure TTWTW.IndexListDblClick(Sender: TObject);
var indexitem:TINDEXITEM;
    i:smallint;
begin
  indexitem:=index.indexitems[IndexList.ItemIndex];
  displayPage(indexitem.idpage);
  for i:=1 to indexitem.nbpopups do begin
    inc(actualPageLevel);
    displayPage(indexitem.popups[i-1]);
  end;
end;

procedure TTWTW.NextPageTimerTimer(Sender: TObject);
var np:IDPOINTER;
begin
  NextPageTimer.Enabled:=false;
  np:=nextpage_load;
  nextpage_load:=-1;
  simulateMouseMove;
  if (np > -1) then begin
    if (debug) then memo1.lines.add('Skip to:'+inttostr(np));
    displayPage(np);
  end;
end;

procedure TTWTW.CancelButtonClick(Sender: TObject);
begin
  dec(actualPageLevel);
  displayPage(actualPages[actualPageLevel].actualPage);
end;

procedure TTWTW.MenuSauveAnimClick(Sender: TObject);
begin
  AniSaveToDisk:=not AniSaveToDisk;
  MenuSauveAnim.Checked:=AniSaveToDisk;
  if AniSaveToDisk then Application.MessageBox('La prochaine animation à être jouée sera sauvegardée sous le nom de Ani.gif et Ani.wav. Sélectionnez cette option à nouveau pour annuler.','Activé !',mb_ICONINFORMATION);
end;

procedure TTWTW.MenuAProposClick(Sender: TObject);
begin
  Application.MessageBox('CCM Emulator, écrit par Yann Le Brech. Contact : yann@le-brech.fr','A propos...',mb_ICONINFORMATION);
end;

procedure TTWTW.MenuRestartClick(Sender: TObject);
begin
  actualPageLevel:=0;
  numhistory:=-10;history[0]:=CCMWorkshop;
  edit1.Text:=inttostr(info.page_start);
  Button1.Click;
end;

procedure TTWTW.MenuRandomPageClick(Sender: TObject);
var randomitem:word;
    indexitem:TINDEXITEM;
    i:smallint;
begin
  randomitem:=random(IndexList.Count);
  indexitem:=index.indexitems[randomitem];
  displayPage(indexitem.idpage);
  for i:=1 to indexitem.nbpopups do begin
    inc(actualPageLevel);
    displayPage(indexitem.popups[i-1]);
  end;
end;

end.
