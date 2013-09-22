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
    ExportTimer: TTimer;
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
    procedure ExportTimerTimer(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  TWTW: TTWTW;

implementation

uses CCM_Png, CCM_Ani, CCM_Zip, GIFImage;

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
    actualNumitems:word;
    actualBasedir:string;
    xoff,yoff:smallint;
    actualrelated_principles_popup:IDPOINTER;
    actualmachines_page:IDPOINTER;
    actualinventors_page:IDPOINTER;
    actualtimeline_page:IDPOINTER;
    x1,y1,x2,y2:smallint;
    PageImage:TBitmap;
  end;

type TEXPORT=record
    pageexported,fullexported:boolean;
    itemexported:array[0..100] of boolean;
  end;

var nextpage_ani:IDPOINTER;
    nextpage_load:IDPOINTER;
    actualletter:smallint;
    BufferImage:TBitmap;
    actualPages:array[0..7] of TDISPLAY; // 0 = main frame, 1 to 7 = popups
    actualPageLevel,predPageLevel:smallint;  // Niveaux de pages
    history:array[0..1000] of IDPOINTER; // Historique
    numhistory:smallint;
    debug,exportres,exportjs:boolean;
    nextexportpage,nextexportitem:word;
    exportstatus:array[0..2000] of TEXPORT;
    jsexport,jstotal:string;

{$R *.dfm}

function revertandaddslashes(str:string;forceFirstSlash:boolean):string;
var i:word;
begin
  i:=length(str);
  while i > 0 do begin
    if (str[i] = '\') then begin
      str[i]:='/';
    end;
    if (str[i] = '''') or (str[i] = '"') then begin
      insert('\',str,i);
    end;
    dec(i);
  end;
  if (forceFirstSlash) and (str[1] <> '/') then str:='/'+str;
  result:=str;
end;

function replaceExt(filename,newext:string):string;
var i:word;
begin
  i:=length(filename);
  while (i>0) and (filename[i]<>'.') do dec(i);
  if newext = '' then result:=copy(filename,1,i-1)
    else result:=copy(filename,1,i)+newext;
end;

function SafeFileName(filename:string):string;
var i:word;
begin
  i:=length(filename)-1;
  while (i>0) do begin
    if (filename[i] = '\') and (filename[i+1] = '\') then delete(filename,i,1);
    dec(i);
  end;
  result:=filename;
end;

procedure writefile(filename,contenu:string);
var f:system.text;
    fullname:string;
begin
  fullname:=GetCurrentDir()+'\'+filename;
  if (exportres) then fullname:=GetCurrentDir()+'\res\'+filename;
  if (exportjs) then fullname:=GetCurrentDir()+'\js\'+filename;
  ForceDirectories(SafeFileName(ExtractFileDir(fullname)));
  assignfile(f,fullname);
  rewrite(f);
  write(f,contenu);
  closefile(f);
end;

procedure writegif(filename:string;bmp:TBitmap);
var fullname:string;
    GIF:TGIFImage;
begin
  fullname:=GetCurrentDir()+'\res\'+filename;
  fullname:=replaceExt(fullname,'gif');
  ForceDirectories(SafeFileName(ExtractFileDir(fullname)));
  GIF := TGIFImage.Create;
  GIF.ColorReduction := rmNone;  // rmQuantize rmNone
  //  GIF.DitherMode := dmNearest;  // no dither, use nearest color in palette
  GIF.DitherMode := dmNearest;       // dmNearest dmFloydSteinberg
  GIF.Add(bmp);
  GIF.SaveToFile(fullname);
  GIF.Free;
end;

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
  if (exportres or exportjs) then exit;
  GetCursorPos(pt);
  SetCursorPos(pt.x+1, pt.y+1);
  Application.ProcessMessages;
  GetCursorPos(pt);
  SetCursorPos(pt.x-1, pt.y-1);
  Application.ProcessMessages;
end;

function displayPicture(filename:string;xoffset,yoffset:smallint):string;
var bmp:TBitmap;
    bmpto:TRect;
    bmpstream:TStream;
    openbmp:smallint;
begin
  bmpstream:=OpenFile(filename);
  if (bmpstream = nil) then begin
    //raise Exception.Create('bmpstream for '+filename+' is nil');
    exit;
  end;
  openbmp:=10;
  bmp:=TBitmap.Create();
  while openbmp>0 do begin
    try
      bmp.LoadFromStream(bmpstream);
      openbmp:=-1;
    except
      on EInvalidGraphic do begin
        bmp.Free;
        bmp:=TBitmap.Create();
        dec(openbmp);
      end;
    end;
  end;
  bmpstream.free;
  if openbmp = 0 then begin
    bmp.free;
    //raise Exception.Create('bmpstream for '+filename+' cannot be opened');
    exit;
  end;
  bmpto:=Rect(xoffset,yoffset,xoffset+bmp.Canvas.ClipRect.Right,yoffset+bmp.Canvas.ClipRect.Bottom);
  with actualPages[actualPageLevel] do begin
    x1:=xoffset;
    y1:=yoffset;
    x2:=xoffset+bmp.Canvas.ClipRect.Right;
    if x2 > BufferImage.Canvas.ClipRect.Right then x2:=BufferImage.Canvas.ClipRect.Right;
    y2:=yoffset+bmp.Canvas.ClipRect.Bottom;
    if y2 > BufferImage.Canvas.ClipRect.Bottom then y2:=BufferImage.Canvas.ClipRect.Bottom;
    // Limites d'affichage des animations dans l'image actuelle
    AniRect:=Rect(x1,y1,x2,y2);
  end;
  // Insertion de l'image dans le buffer
  BufferImage.Canvas.CopyRect(bmpto,bmp.Canvas,bmp.Canvas.ClipRect);
  bmp.free;
  if (exportres) then begin
    bmp:=TBitmap.Create();
    bmp.Width:=AniRect.Right-AniRect.Left;
    bmp.Height:=AniRect.Bottom-AniRect.Top;
    bmp.Canvas.CopyRect(bmp.Canvas.ClipRect,BufferImage.Canvas,AniRect);
    writegif(filename,bmp);
    bmp.free;
  end;
  if (exportjs) then begin
    filename:=replaceExt(filename,'gif');
    result:=', src:''res'+revertandaddslashes(filename,true)+''', left:'+inttostr(AniRect.Left)+', top:'+inttostr(AniRect.Top);
  end else result:='';
end;

procedure addItems(page:TPAGE;basedir:string;xoff_,yoff_:smallint);
var item,i:smallint;
    filename,linkdata,actiondata:string;
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
      if (debug) then begin
        BufferImage.Canvas.Brush.Style:=bsClear;
        BufferImage.Canvas.Pen.Color:=$ee;
        BufferImage.Canvas.Rectangle(links[numlinks].x1, links[numlinks].y1, links[numlinks].x2, links[numlinks].y2);
      end;
      links[numlinks].xoffset:=xoff_;
      links[numlinks].yoffset:=yoff_;
      links[numlinks].cursor:=cursor;
      links[numlinks].linktype:=itemtype;
      if (exportjs) then begin
        linkdata:='x1:'+inttostr(links[numlinks].x1)+', y1:'+inttostr(links[numlinks].y1)+', x2:'+inttostr(links[numlinks].x2)+', y2:'+inttostr(links[numlinks].y2)+', type:'+inttostr(links[numlinks].linktype-600);
      end;
      if (itemtype = 601) then begin
        // Image de fond. C'est le premier item dans la liste
        links[numlinks].x1:=0;
        links[numlinks].y1:=0;
        links[numlinks].x2:=0;
        links[numlinks].y2:=0;
        linkdata:='type:1';
        filename:=basedir+strings.strings[image]+'.DIB';
        if (debug) then twtw.memo1.lines.add('Background image '+filename+' '+inttostr(xoff_)+' '+inttostr(yoff_));
        linkdata:=linkdata+displayPicture(filename,xoff_,yoff_);
        inc(numlinks);
      end;
      links[numlinks].fx1:=actualPages[actualPageLevel].x1;
      links[numlinks].fy1:=actualPages[actualPageLevel].y1;
      links[numlinks].fx2:=actualPages[actualPageLevel].x2;
      links[numlinks].fy2:=actualPages[actualPageLevel].y2;
      if (itemtype = 602) then begin
        // Animation avec barre de défilement
        CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
        CCMaddControlbar(xoff_+x1,yoff_+y1);
        BufferImage.Canvas.CopyRect(CCMBufferImage.Canvas.ClipRect,CCMBufferImage.Canvas,BufferImage.Canvas.ClipRect);
        //TWTW.memo1.Lines.add('Animation with control bar');
        filename:=basedir+strings.strings[anim]+'.ANI';
        links[numlinks].anim:=filename;
        links[numlinks].anim_skip:=actualPage;
        if (exportjs) then linkdata:=linkdata+', src:''res'+revertandaddslashes(replaceExt(filename,'gif'),true)+''', audio:''res'+revertandaddslashes(replaceExt(filename,''),true)+''', left:'+inttostr(xoff_)+', top:'+inttostr(yoff_)+', time:'+inttostr(CCMAniLength(filename))+', controlbar:true, cbx:'+inttostr(xoff_+x1)+', cby:'+inttostr(yoff_+y1);
        if (autostart = 0) then begin
          AniRect:=Rect(links[numlinks].fx1,links[numlinks].fy1,links[numlinks].fx2,links[numlinks].fy2);
          if (not exportjs) then CCMPlayAni(filename,xoff_,yoff_,true) else linkdata:=linkdata+', autostart:true';
          setCursor(-2);
          nextpage_ani:=-2;
          links[numlinks].anim_skip:=-2;
          dec(numhistory); // Doesn't count in the history
        end;
        inc(numlinks);
      end;
      if (itemtype = 603) then begin
        // Objets cliquables, possédant une ou deux actions réalisables. Voir le mouseDown pour plus d'infos
        // item_props : 4 (mainly) or 5 or 1
        if (debug) then twtw.memo1.lines.add('Link: '+inttostr(links[numlinks].x1)+':'+inttostr(links[numlinks].y1)+'/'+inttostr(links[numlinks].x2)+':'+inttostr(links[numlinks].y2));
        links[numlinks].numactions:=numactions;
        links[numlinks].actions[0]:=actions[0];
        links[numlinks].actions[1]:=actions[1];
        if (exportjs) then begin
          actiondata:='';
          for i:=0 to numactions-1 do begin
            if (actions[i].typeaction = 1) then begin
              // Popup : aller au niveau suivant, et indiquer l'ID de la popup à afficher.
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:1,nextpage:'+inttostr(getIDPointer(actions[i].popup_id))+'}';
            end;
            if (actions[i].typeaction = 2) then begin
              // Raccourci (lien secondaire) vers un item présent sur la page
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:2,linkId:'+inttostr(actions[i].item_id)+'}';
            end;
            if (actions[i].typeaction = 3) then begin
              // Nouvelle page
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:3,nextpage:'+inttostr(getIDPointer(actions[i].linkto))+'}';
            end;
            if (actions[i].typeaction = 4) then begin
              // Jouer un son
              filename:=actualBaseDir+strings.strings[actions[i].soundtoplay];
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:4,audio:''res'+revertandaddslashes(filename,true)+'''}';
            end;
            if (actions[i].typeaction = 7) then begin
              // Animation simple
              filename:=actualBaseDir+strings.strings[actions[i].anim]+'.ANI';
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:7,src:''res'+revertandaddslashes(replaceExt(filename,'gif'),true)+''', audio:''res'+revertandaddslashes(replaceExt(filename,''),true)+''', left:'+inttostr(xoff_)+', top:'+inttostr(yoff_)+', time:'+inttostr(CCMAniLength(filename))+'}';
            end;
            if (actions[i].typeaction = 11) then begin
              // Commandes spéciales (copier dans le presse papiers, imprimer, configurer impression)
              actiondata:=actiondata+'{type:11}';
            end;
            if (actions[i].typeaction = 12) then begin
              // Fermer la popup.
              // In ciné-mamouth, this action item is followed by a popup action.
              if (actiondata <> '') then actiondata:=actiondata+', ';
              actiondata:=actiondata+'{type:12}';
            end;
          end;
          if (actiondata <> '') then linkdata:=linkdata+', actions:['+actiondata+']';
        end;
        inc(numlinks);
      end;
      if (itemtype = 604) then begin
        // Lettres utilisées dans la roue alphabétique
        links[numlinks].numactions:=0;
        links[numlinks].letter:=letter;
        links[numlinks].anim_skip:=page_skip;
        actualletter:=0;
        inc(numlinks);
      end;
      if (itemtype = 606) then begin
        // Boutons de navigation à gauche (il y en a 9, dans la frame externe)
        filename:=basedir+strings.strings[anim]+'.ANI';
        //TWTW.memo1.Lines.add('NAV bar '+filename);
        links[numlinks].anim:=filename;
        //links[numlinks].anim_skip:=page_skip;
        //TWTW.Memo1.lines.add('(Theorically) Link '+inttostr(item_id)+' to '+inttostr(page_skip));
        // The order in the file is wrong!!
        links[numlinks].anim_skip:=fixedNavBar(item_id, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page);
        if (exportjs) then linkdata:=linkdata+', src:''res'+revertandaddslashes(replaceExt(filename,'gif'),true)+''', audio:''res'+revertandaddslashes(replaceExt(filename,''),true)+''', left:'+inttostr(xoff_)+', top:'+inttostr(yoff_)+', time:'+inttostr(CCMAniLength(filename))+', nextpage:'+inttostr(getIDPointer(fixedNavBar(item_id, -40, -41, -42, -43)));
        inc(numlinks);
      end;
      if (itemtype = 607) then begin
        // Animation
        filename:=basedir+strings.strings[anim]+'.ANI';
        if (debug) then twtw.memo1.lines.add('Animation ('+inttostr(item_props)+' '+filename+': '+inttostr(links[numlinks].x1)+':'+inttostr(links[numlinks].y1)+'/'+inttostr(links[numlinks].x2)+':'+inttostr(links[numlinks].y2));
        if (exportjs) then linkdata:=linkdata+', src:''res'+revertandaddslashes(replaceExt(filename,'gif'),true)+''', audio:''res'+revertandaddslashes(replaceExt(filename,''),true)+''', left:'+inttostr(xoff_)+', top:'+inttostr(yoff_)+', time:'+inttostr(CCMAniLength(filename));
        //setCursor(cursor);
        if (item_props = 32) then begin
          nextpage_ani:=nextpage;
          if (not exportjs) then CCMPlayAni(filename,xoff_,yoff_,false) else linkdata:=linkdata+', autostart:true, nextpage:'+inttostr(getIDPointer(nextpage));
          setCursor(-2);
          dec(numhistory); // Doesn't count in the history
        end;
        if (item_props = 0) or (item_props = 16) then begin
          links[numlinks].anim:=filename;
          if (page_skip = 1) then begin
            links[numlinks].anim_skip:=nextpage;
            if (exportjs) then linkdata:=linkdata+', nextpage:'+inttostr(getIDPointer(nextpage));
          end else begin
            links[numlinks].anim_skip:=-1;
          end;
        end;
        inc(numlinks);
      end;
      if (itemtype = 608) then begin
        // Bouton d'annulation, utilisé dans la page d'options
        TWTW.CancelButton.Left:=links[numlinks].x1;
        TWTW.CancelButton.Top:=links[numlinks].y1;
        TWTW.CancelButton.Width:=links[numlinks].x2-links[numlinks].x1;
        TWTW.CancelButton.Height:=links[numlinks].y2-links[numlinks].y1;
        TWTW.CancelButton.Visible:=true;
        inc(numlinks);
      end;
      if (itemtype = 609) then begin
        // Longue image scrollable utilisée dans l'aide
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
      if ((exportjs) and (itemtype <> 605)) then begin
        jsexport:=jsexport+'page.links['+inttostr(numlinks-1)+'] = {'+linkdata+'};'#13#10;
      end;
    end;
    if (actualletter = 0) then begin
      displayPicture(actualBaseDir+'AZAZ0MAA.DIB',255,105); // Lettre A affichée par défaut
    end;
  end;
end;

procedure displayFrame(idframe,typepage:smallint);
var i,j:smallint;
    frame:TPAGE;
    idpointer_frame_pointer:longint;
begin
  with actualPages[actualPageLevel] do
  for i:=0 to info.numframes-1 do with info.frames[i] do if (id_frame = idframe) then begin // On cherche la frame à afficher dans la liste des frames
    for j:=0 to numinfos-1 do with infos[j] do begin // On parcours les infos disponibles
      if (id_frame2 = 1) then begin
        if (typepage = 102) then begin // Page pleine : on ajoute un offset (les popups ont leur propre offset)
          xoff:=offset_x;
          yoff:=offset_y;
        end;
      end else begin
        idpointer_frame_pointer:=getIDPointer(idpointer_frame);
        if (typeframe2 <> 202) then begin // On affiche le fond de la frame et ses items (exemple, les boutons de navigation).
          if (exportres or exportjs) and (not exportstatus[idpointer_frame_pointer].pageexported) then begin
            actualPages[actualPageLevel].numlinks:=0;
            actualPages[actualPageLevel].actualNumitems:=0;
            jsexport:='';
          end;
          if (not (exportres or exportjs)) or (not exportstatus[idpointer_frame_pointer].pageexported) then begin
            frame:=ReadPagePNG(idpointer_frame_pointer);
            addItems(frame,'',imageoffset_x,imageoffset_y);
          end else if (exportjs) then begin
            jsexport:=jsexport+'page.frames.push('+inttostr(idpointer_frame_pointer)+');'#13#10;
          end;
          if (exportres or exportjs) and (not exportstatus[idpointer_frame_pointer].pageexported) then begin
            exportstatus[idpointer_frame_pointer].pageexported:=true;
            nextexportpage:=idpointer_frame_pointer; // On prévoit d'exporter les liens, pour passer en fullexported
            exit;
          end;
        end;
      end;
    end;
  end;
end;

procedure displayPage(idpage:IDPOINTER);
var page:TPAGE;
    basedir:string;
begin
  // On arrête une éventuelle animation en cours
  if CCMIsPlaying then CCMStopAni;
  while CCMIsPlaying do;

  // On met à jour et cache d'éventuels éléments d'interface
  TWTW.Edit1.Text:=inttostr(idpage);
  TWTW.IndexEdit.Visible:=(idpage = CCMIndex);
  TWTW.IndexList.Visible:=(idpage = CCMIndex);
  TWTW.CancelButton.Visible:=false;
  TWTW.ScrollBox.Visible:=false;

  // On met à jour le statut de la sauvegarde de l'animation (mise à zéro lorsque c'est fait).
  TWTW.MenuSauveAnim.Checked:=AniSaveToDisk;

  // Lecture des informations sur la page.
  page:=ReadPagePNG(idpage);
  if page.typepage=0 then exit; // On n'est pas sur une vraie page, on ignore.

  if (page.typepage <> 102) then // S'il ne s'agit pas d'une pleine page (donc une popup à priori) et que le niveau est = 0 ou identique au précédent, alors on avance d'un niveau.
   if (actualPageLevel = 0) and (actualPages[actualPageLevel].actualPage <> idpage) and (actualPageLevel = predPageLevel) then
    inc(actualPageLevel) else
   else actualPageLevel:=0; // Sinon, il s'agit d'une pleine page, on revient au début.
  with actualPages[actualPageLevel] do begin // Ensuite, on donne les infos sur le niveau de page actuel
  // Initialisation des infos
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
    if (debug) then twtw.memo1.lines.add('Base directory: '+basedir);
    actualBasedir:=basedir;
    if ((actualBasedir <> '\HELP\') or (actualPageLevel <> predPageLevel)) then begin
      // - Aide : problèmes avec quelques pages (gros souk des offsets). Résultat : les liens entre les pages "molécules" par ex changent
      //   la position de la fenêtre (même déplacée), mais pas les pages d'aide (si déplacement de la fenêtre, on reste)...
      xoff:=actualPages[0].xoff;
      yoff:=actualPages[0].yoff;
    end;
    if (exportjs) then jsexport:='page.type='+inttostr(typepage-100)+';'#13#10;
    if (typepage=101) then begin  // Popup
      BufferImage.Canvas.CopyRect(actualPages[pred(actualPageLevel)].PageImage.Canvas.ClipRect,actualPages[pred(actualPageLevel)].PageImage.Canvas,BufferImage.Canvas.ClipRect);
    end;
    if (typepage=102) then begin  // Page pleine
      // On ajoute à l'historique
      if (numhistory >= 1000) then numhistory:=999;
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
        // Si disponible, on renseigne les pages principes, inventions, inventeurs...
        actualrelated_principles_popup:=related_principles_popup;
        actualmachines_page:=machines_page;
        actualinventors_page:=inventors_page;
        actualtimeline_page:=timeline_page;
      end;
      if (exportjs) then jsexport:=jsexport+'page.menupages=['
                     +inttostr(getIDPointer(fixedNavBar(-47, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page)))+','
                     +inttostr(getIDPointer(fixedNavBar(-48, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page)))+','
                     +inttostr(getIDPointer(fixedNavBar(-49, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page)))+','
                     +inttostr(getIDPointer(fixedNavBar(-50, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page)))
                     +'];'#13#10;
    end;
    if (typepage = 103) then begin  // Popup également ?
      BufferImage.Canvas.CopyRect(actualPages[pred(actualPageLevel)].PageImage.Canvas.ClipRect,actualPages[pred(actualPageLevel)].PageImage.Canvas,BufferImage.Canvas.ClipRect);
    end;
    // Affichage de la frame extérieure
    displayFrame(id_frame,typepage);
    if ((actualBasedir <> '\HELP\') or (actualPageLevel <> predPageLevel)) then begin
      // Si il ne s'agit pas d'une page d'aide ou si le niveau de page a changé, on décale la page dans la fenêtre.
      inc(xoff,xoffset);
      inc(yoff,yoffset);
    end;
    // On ajoute les différents items sur la page (image de fond, liens, animations...)
    if (debug) then twtw.memo1.lines.add('Loading items: '+inttostr(numitems));
    if (exportres or exportjs) then begin
      if (nextexportpage = 0) or (nextexportpage = idpage) then begin
        addItems(page,basedir,xoff,yoff);
        exportstatus[idpage].pageexported:=true;
      end;
    end else addItems(page,basedir,xoff,yoff);
  end;
  // Une fois tous les items ajoutés, on affiche sur le buffer
  CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
  // On sauvegarde l'image pour utilisation future (retour en arrière notamment, ou changement de popup)
  actualPages[actualPageLevel].PageImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,actualPages[actualPageLevel].PageImage.Canvas.ClipRect);
  // On rafraichit l'image à l'écran
  TWTW.pbx.Refresh;
  // Mettre à jour le curseur de la souris, si il y a un item ou pas en dessous
  simulateMouseMove;
  // On commence à compter l'historique à partir du workshop
  if (numhistory < 0) and (idpage = CCMWorkshop) then numhistory:=0;
  end;
  // On garde le niveau actuel pour usage futur
  predPageLevel:=actualPageLevel;
end;

procedure FinishedAnimation;
begin
  // On écrase la valeur de nextpage_load par la valeur de nextpage_ani (ou la page actuelle pour rafficher la page à l'issue de l'animation)
  nextpage_load:=-1;
  if (nextpage_ani > -1) then nextpage_load:=nextpage_ani
    else if (nextpage_ani = -1) then nextpage_load:=actualPages[actualPageLevel].actualPage;
  // On lance le timer pour actualiser la page (petit truc pour éviter de s'embêter avec les threads) 
  if (exportres or exportjs) then begin
    TWTW.ExportTimer.Enabled:=True;
  end else begin
    TWTW.NextPageTimer.Enabled:=true;
  end;
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
var i,j:word;
    s,param:string;
begin
  memo1.Lines.Clear;
  param:='TWTW';
  debug:=false;exportres:=false;exportjs:=false;
  if (paramstr(1) = '--debug') then debug:=true;
  if (paramstr(1) = '--exportres') then exportres:=true;
  if (paramstr(1) = '--exportjs') then exportjs:=true;
  if (paramcount > 0) then param:=paramstr(paramcount);
  TWTWZip:=nil;
  if FileExists(param+'.ZIP') then begin
    TWTWZip:=TZipFile.Create;
    TWTWZip.OpenFromFile(param+'.ZIP');
    TWTWZip.LoadZip;
  end;
  actualPageLevel:=0;
  numhistory:=-10;history[0]:=CCMWorkshop;
  if ((paramcount > 0) and (TWTWZip = nil)) then s:=param else s:='.';
  while (s<>'') and (s[length(s)] = '\') do delete(s,length(s),1);
  cdroot:=s;
  if (debug) then memo1.lines.add('Loading...');
  if not OpenPNG('DKCODE\TWTW.PNG') then begin
    Application.MessageBox('Fichier TWTW.PNG non trouvé ou illisible, spécifiez le chemin en ligne de commande.','Erreur',mb_ICONSTOP);
    Application.Terminate;
    exit;
  end;
  if (debug) then memo1.lines.add('Loaded OK');
  edit1.Text:=inttostr(info.page_start);
  BufferImage:=TBitmap.Create;
  BufferImage.Width:=info.screenwidth-2; // 638
  BufferImage.Height:=info.screenheight-22; // 458
  for i:=0 to 7 do begin
    actualPages[i].PageImage:=TBitmap.Create;
    actualPages[i].PageImage.Width:=info.screenwidth-2; // 638
    actualPages[i].PageImage.Height:=info.screenheight-22; // 458
  end;
  for i:=0 to index.indexlen-1 do IndexList.Items.Add(strings.strings[index.indexitems[i].indexword]);
  TWTW.Width:=info.screenwidth+4;
  pbx.width:=info.screenwidth;
  if (not debug) then TWTW.Height:=info.screenheight+3;
  if (not debug) and (not exportres) and (not exportjs) then Button1.Click;
  pbx.height:=info.screenheight-2;
  IndexEdit.Visible:=false;
  IndexList.Visible:=false;
  ScrollBox.Left:=CCMScrollBoxPos[0];
  ScrollBox.Top:=CCMScrollBoxPos[1];
  ScrollBox.Width:=CCMScrollBoxPos[2];
  ScrollBox.Height:=CCMScrollBoxPos[3];
  centerizeform(TWTW);
  if (exportres or exportjs) then begin
    for i:=0 to 2000 do begin
      exportstatus[i].pageexported:=false;
      exportstatus[i].fullexported:=false;
      for j:=0 to 100 do exportstatus[i].itemexported[j]:=false;
    end;
    nextexportpage:=0;
    jstotal:='';
    ExportTimer.Enabled:=True;
  end;
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
  if (exportres or exportjs) then exit;
  with actualPages[actualPageLevel] do begin
  if not (CCMIsPlaying) then begin
    linkFound:=false;
    for i:=0 to numlinks-1 do with links[i] do begin
      if (x >= x1) and (y >= y1) and (x <= x2) and (y <= y2) then begin
        linkFound:=true;
        {CCMCanvas.Brush.Color:=$cc0000; CCMCanvas.Pen.Color:=$cc0000; CCMCanvas.Rectangle(x1,y1,x2,y2);}
        setCursor(cursor);
      end;
    end;
    if not linkFound then setCursor(-1);
  end;
  end;
end;

procedure TTWTW.pbxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var i,j,k:word;
    filename:string;
    nextpage:IDPOINTER;
    nextlevel:smallint;
    actionTaken:boolean;

begin
  if (exportres or exportjs) and (Sender <> nil) then exit;
  if Button <> mbLeft then exit;
  if CCMIsPlaying then begin
    CCMStopAni;  // Stoppe simplement l'animation en cours avec un clic
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
        if (exportres) and (i-1 <> nextexportitem) then continue;
        if (debug) then twtw.memo1.lines.add(inttostr(linktype));
        // Item 601 ignoré, car c'est l'image de fond.
        if (linktype = 602) then begin
          // Animation avec barre de défilement
          actionTaken:=true;
          nextpage_ani:=anim_skip;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          if (not exportjs) then CCMPlayAni(anim,xoff,yoff,true);
          setCursor(-2);
        end;
        if (linktype = 603) then begin
          // Objets avec actions
          for j:=1 to numactions do with actions[j-1] do begin
            if (typeaction = 1) then begin
              // Popup : aller au niveau suivant, et indiquer l'ID de la popup à afficher.
              inc(nextlevel);
              nextpage:=popup_id;
              actionTaken:=true;
              break;
            end;
            if (typeaction = 2) then begin
              // Raccourci (lien secondaire) vers un item présent sur la page
              for k:=0 to actualNumitems-1 do if (actualItems[k].item_id = item_id) then begin
                if (actualItems[k].itemtype = 602) then begin
                  if (debug) then twtw.memo1.lines.add('Animation with control bar');
                  filename:=actualBaseDir+strings.strings[actualItems[k].anim]+'.ANI';
                  actionTaken:=true;
                  if (actualItems[k].autostart = 0) then nextpage_ani:=-2;
                  AniRect:=Rect(fx1,fy1,fx2,fy2);
                  if (not exportjs) then CCMPlayAni(filename,xoff,yoff,true);
                  setCursor(-2);
                end;
              end;
            end;
            if (typeaction = 3) then begin
              // Nouvelle page
              nextpage:=linkto;
              actionTaken:=true;
              break;
            end;
            if (typeaction = 4) then begin
              // Jouer un son
              filename:=actualBaseDir+strings.strings[soundtoplay]+'.WAV';
              setCursor(-2);
              if (not exportjs) then CCMPlayWav(filename);
            end;
            if (typeaction = 7) then begin
              // Animation simple
              filename:=actualBaseDir+strings.strings[anim]+'.ANI';
              actionTaken:=true;
              AniRect:=Rect(fx1,fy1,fx2,fy2);
              if (not exportjs) then CCMPlayAni(filename,xoff,yoff,false);
              setCursor(-2);
            end;
            if (typeaction = 11) then begin
              // Commandes spéciales
              if (not (exportres or exportjs)) then begin
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
            end;
            if (typeaction = 12) then begin
              // Fermer la popup.
              // In ciné-mamouth, this action item is followed by a popup action.
              dec(nextlevel);
              nextpage:=actualPages[nextlevel].actualPage;
            end;
          end;
        end;
        if (linktype = 604) then begin
          // Utilisé dans la roue aplhabétique
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
              if (not exportjs) then CCMPlayAni(actualBaseDir+'AZAZ0M'+chr(ord('A')+actualletter)+'A.ANI',xoff,yoff,false);
              setCursor(-2);
            end;
          end;
          if (nextpage_ani = -1) then begin
            if (debug) then twtw.memo1.lines.add('Current letter: '+chr(ord('A')+actualletter));
            if (not (exportres or exportjs)) then PlaySound(TMemoryStream(OpenFile(actualBaseDir+'DIAL.WAV')).Memory,0,SND_ASYNC or SND_MEMORY);
            displayPicture(actualBaseDir+'AZAZ0M'+chr(ord('A')+actualletter)+'A.DIB',255,105);
            CCMBufferImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,CCMBufferImage.Canvas.ClipRect);
            actualPages[actualPageLevel].PageImage.Canvas.CopyRect(BufferImage.Canvas.ClipRect,BufferImage.Canvas,actualPages[actualPageLevel].PageImage.Canvas.ClipRect);
            TWTW.pbx.Refresh;
          end;
        end;
        if (linktype = 606) then begin
          // Boutons de navigation à gauche
          nextpage_ani:=anim_skip;
          if (anim_skip = -51) and (numhistory > 0) then begin
            dec(numhistory);
            nextpage_ani:=history[numhistory];
          end;
          actionTaken:=true;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          if (not exportjs) then CCMPlayAni(anim,xoffset,yoffset,false);
          setCursor(-2);
        end;
        if (linktype = 607) then begin
          // Animations
          nextpage_ani:=anim_skip;
          actionTaken:=true;
          AniRect:=Rect(fx1,fy1,fx2,fy2);
          if (not exportjs) then CCMPlayAni(anim,xoffset,yoffset,false);
          setCursor(-2);
        end;
        if (linktype = 608) then begin
          // Utilisé à un seul endroit (page "Options")
          // Bouton "Annuler"
          // Pourrait également servir à fermer la popup, avec l'ID de popup qui suivrait.
          dec(nextlevel);
          nextpage:=actualPages[nextlevel].actualPage;
        end;
      end;
    end;
    if (nextpage > -1) and (not (exportres or exportjs)) then begin
      // Si on est supposé changer de page, on le fait.
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
  AniSavePrefix:='Ani';
  if AniSaveToDisk then Application.MessageBox(PAnsiChar('La prochaine animation à être jouée sera sauvegardée sous le nom de '+AniSavePrefix+'.gif et '+AniSavePrefix+'.wav. Sélectionnez cette option à nouveau pour annuler.'),'Activé !',mb_ICONINFORMATION);
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

procedure TTWTW.ExportTimerTimer(Sender: TObject);
var i,adv:word;
    nextpage:word;
begin
  ExportTimer.Enabled:=False;
  i:=getIDPointer(nextexportpage);
  adv:=0;
  while (i < pointers.nbpointers) and (exportstatus[i].fullexported) do begin; inc(i); inc(adv); end;
  if (i >= pointers.nbpointers) then begin
    TWTW.Caption := 'CCM Export finished!';
    TWTW.pbx.Cursor:=crDefault;
    if (exportjs) then writefile('total.js',jstotal);
    exit;
  end;
  nextpage:=i;
  TWTW.pbx.Cursor:=crHourGlass;
  if (exportres) then begin
    AniSaveToDisk:=true;
    AniSavePrefix:='res?';
  end;
  TWTW.Caption := 'CCM Exporting '+inttostr(nextpage)+' ('+inttostr(round(100*adv/pointers.nbpointers))+'%)';
  if (exportstatus[nextpage].pageexported) then begin
    if (exportjs) then begin
      // Tous ces espaces vides empêchent le programme de planter pendant de l'export... Faudrait trouver une meilleure solution...
      jsexport:='page = {frames:new Array(), links:new Array(), type:0};'#13#10+jsexport+'pages['+inttostr(nextpage)+'] = page;'#13#10;
      jstotal:=jstotal+jsexport;
      exportstatus[nextpage].fullexported := true;
    end else begin
      i:=0;
      while (i < actualPages[actualPageLevel].actualNumitems) and (exportstatus[nextpage].itemexported[i]) do inc(i);
      if (i >= actualPages[actualPageLevel].actualNumitems) then exportstatus[nextpage].fullexported := true else begin
        nextexportitem:=i;
        CCMBufferImage.Canvas.CopyRect(actualPages[actualPageLevel].PageImage.Canvas.ClipRect,actualPages[actualPageLevel].PageImage.Canvas,CCMBufferImage.Canvas.ClipRect);
        TWTW.pbxMouseDown(nil, mbLeft, [], actualPages[actualPageLevel].links[nextexportitem].x1, actualPages[actualPageLevel].links[nextexportitem].y1);
        exportstatus[nextpage].itemexported[nextexportitem]:=true;
      end;
    end;
    if (exportstatus[nextpage].fullexported) then begin
      nextexportpage:=0;
      ExportTimer.Enabled:=True; // Next page please!
      exit;
    end;
  end else begin
    actualPageLevel:=1;
    predPageLevel:=0;
    if (exportjs) then begin
      jsexport:='';
    end;
    displayPage(nextpage);
  end;
  if (not CCMIsPlaying) then ExportTimer.Enabled:=True;
end;

end.
