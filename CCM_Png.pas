unit CCM_Png;

interface

uses Classes;

type THEADER=record
    pages_start:cardinal;
    idstrings_size:cardinal;
    idpointers_start:cardinal;
  end;

type IDSTRING=smallint;

type IDPOINTER=longint;

type TSTRINGS=record
    nbstrings:smallint;
    strings:array[1..5000] of string[128];
  end;

type TFRAMES2=record
    typeframe2:smallint;
    id_frame2:smallint;
    idpointer_frame:IDPOINTER;
    size_x:smallint;
    size_y:smallint;
    imageoffset_x:smallint;
    imageoffset_y:smallint;
    offset_x:smallint;
    offset_y:smallint;
  end;

type TFRAMES=record
    typeframe:smallint;
    id_frame:smallint;
    size_x:smallint;
    size_y:smallint;
    numids:smallint;
    ids:array[0..10] of smallint;
    numinfos:smallint;
    infos:array[0..10] of TFRAMES2;
  end;

type TINFO=record
    screenwidth:smallint;
    screenheight:smallint;
    page_start:IDPOINTER;
    numframes:smallint;
    frames:array[0..10] of TFRAMES;
  end;

type TINDEXITEM=record
    indexword:IDSTRING;
    idpage:IDPOINTER;
    nbpopups:smallint;
    popups:array[0..10] of IDPOINTER;
  end;

type TINDEX=record
    indexlen:cardinal;
    indexitems:array[0..2000] of TINDEXITEM;
  end;

type TPOINTERS=record
    nbpointers:cardinal;
    pointers:array[0..2000] of cardinal;
  end;

type TACTION=record
    typeaction:smallint;
    popup_id:IDPOINTER;
    popuplevel:smallint;
    item_id:smallint;
    linkto:IDPOINTER;
    soundtoplay:IDSTRING;
    anim:IDSTRING;
    command:smallint;
    popup_to_close:IDPOINTER;
  end;

type TITEM=record
    itemtype:smallint;
    item_id:smallint;
    item_props:smallint;
    imgwidth:smallint;
    imgheight:smallint;
    image:IDSTRING;
    x1:smallint;
    y1:smallint;
    x2:smallint;
    y2:smallint;
    cursor:IDSTRING;
    anim:IDSTRING;
    numactions:smallint;
    actions:array[0..1] of TACTION;
    page_skip:IDPOINTER;
    autostart:smallint;
    nextpage:IDPOINTER;
    popup_id:IDPOINTER;
    letter:smallint;
  end;

type TPAGE=record
    typepage:smallint;
    id_frame:smallint;
    xoffset:smallint;
    yoffset:smallint;
    basedirectory:IDSTRING;
    numitems:smallint;
    items:array[0..100] of TITEM;
    links_infos:smallint;
    more_infos:smallint;
    related_principles_popup:IDPOINTER;
    machines_page:IDPOINTER;
    inventors_page:IDPOINTER;
    timeline_page:IDPOINTER;
  end;

type TPOS=array[0..3] of integer;

function OpenPNG(filename:string):boolean;
procedure ClosePNG;
function ReadPagePNG(idpointer:longint):TPAGE;
function fixedNavBar(item_id:smallint; actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page:IDPOINTER):IDPOINTER;

var header:THEADER;
    strings:TSTRINGS;
    info:TINFO;
    index:TINDEX;
    pointers:TPOINTERS;
    PNG:TStream;
    CCMWorkshop:IDPOINTER;
    CCMindex:IDPOINTER;
    CCMScrollBoxPos:TPOS;

implementation

uses CCM_PngEN, CCM_PngFR;

var realOpenPNG:function(filename:string):boolean;
    realClosePNG:procedure;
    realReadPagePNG:function(idpointer:longint):TPAGE;
    realFixedNavBar:function(item_id:smallint; actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page:IDPOINTER):IDPOINTER;
    currentEngine:word; // Moteur de décodage, 1 = EN, 2 = FR

function loadNextEngine:boolean;
begin
  inc(currentEngine);
  if (currentEngine = 1) then begin
    realOpenPNG:=@CCM_PngEN.OpenPNG;
    realClosePNG:=@CCM_PngEN.ClosePNG;
    realReadPagePNG:=@CCM_PngEN.ReadPagePNG;
    realFixedNavBar:=@CCM_PngEN.fixedNavBar;
    CCMWorkshop:=CCM_PngEN.CCMWorkshop;
    CCMindex:=CCM_PngEN.CCMindex;
    CCMScrollBoxPos:=CCM_PngEN.CCMScrollBoxPos;
  end;
  if (currentEngine = 2) then begin
    realOpenPNG:=@CCM_PngFR.OpenPNG;
    realClosePNG:=@CCM_PngFR.ClosePNG;
    realReadPagePNG:=@CCM_PngFR.ReadPagePNG;
    realFixedNavBar:=@CCM_PngFR.fixedNavBar;
    CCMWorkshop:=CCM_PngFR.CCMWorkshop;
    CCMindex:=CCM_PngFR.CCMindex;
    CCMScrollBoxPos:=CCM_PngFR.CCMScrollBoxPos;
  end;
  loadNextEngine:=currentEngine<=2;
end;

function OpenPNG(filename:string):boolean;
var res:boolean;
begin
  res:=false;
  while (loadNextEngine) do begin
    res:=realOpenPNG(filename);
    if (res) then break;
  end;
  OpenPNG:=res;
end;

procedure ClosePNG;
begin
  realClosePNG;
end;

function ReadPagePNG(idpointer:longint):TPAGE;
begin
  ReadPagePNG:=realReadPagePNG(idpointer);
end;

function fixedNavBar(item_id:smallint; actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page:IDPOINTER):IDPOINTER;
begin
  fixedNavBar:=realFixedNavBar(item_id, actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page);
end;

begin
  currentEngine:=0;
end.
