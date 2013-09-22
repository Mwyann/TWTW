unit CCM_PngEN;

interface

uses Classes, Windows, Forms, SysUtils, CCM_Png, CCM_Zip;

function OpenPNG(filename:string):boolean;
procedure ClosePNG;
function ReadPagePNG(idpointer:longint):TPAGE;
function getIDPointer(idpointer:longint):longint;
function fixedNavBar(item_id:smallint; actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page:IDPOINTER):IDPOINTER;

const CCMWorkshop:IDPOINTER=438408;
      CCMindex:IDPOINTER=211350;
      CCMScrollBoxPos:TPOS=(313,70,273,300);
      
implementation

{ BigEndian reading functions }

function typeReadCardinalBE:cardinal;
var buf:array[0..3] of byte;
begin
  PNG.read(buf,4);
  typeReadCardinalBE:=buf[0]*256*256*256+buf[1]*256*256+buf[2]*256+buf[3];
end;

function typeReadWordBE:smallint;
var buf:array[0..1] of byte;
    val:longint;
begin
  PNG.read(buf,2);
  val:=buf[0]*256+buf[1];
  if (val > 32767) then val:=val-65536;
  typeReadWordBE:=val;
end;

procedure SkipBytes(n:integer);
begin
  PNG.seek(n, soFromCurrent);
end;

{ Structs reading functions }

procedure readHeader;
begin
  PNG.seek(0, soFromBeginning);
  header.pages_start:=typeReadCardinalBE;
  header.idstrings_size:=typeReadCardinalBE;
end;

function readStrings:boolean;
var i,j,l:word;
    s:string;
    buf:array[0..127] of char;
begin
  readStrings:=false;
  strings.nbstrings:=typeReadWordBE;
  strings.strings[strings.nbstrings]:='';
  for i:=1 to strings.nbstrings do begin
    l:=typeReadWordBE;
    if (l > 127) then exit;
    buf[l]:=' ';
    PNG.Read(buf,l);
    s:='';
    for j:=1 to l do s:=s+buf[pred(j)];
    strings.strings[i]:=s;
  end;
  readStrings:=true;
end;

procedure readFrame2(framenum:word;infonum:word);
begin
  with info.frames[framenum].infos[infonum] do begin
    typeframe2:=typeReadWordBE;
    id_frame2:=typeReadWordBE;
    if (typeframe2=201) then begin
      SkipBytes(1*2);
      idpointer_frame:=typeReadCardinalBE;
      SkipBytes(1*2);
      if (id_frame2 > 1) then begin
        SkipBytes(2*2);
      end;
      size_x:=typeReadWordBE;
      size_y:=typeReadWordBE;
      offset_x:=typeReadWordBE;
      offset_y:=typeReadWordBE;
      imageoffset_x:=offset_x;
      imageoffset_y:=offset_y;
    end else
    if (typeframe2=202) then begin
      SkipBytes(4*2);
      size_x:=typeReadWordBE;
      size_y:=typeReadWordBE;
      offset_x:=typeReadWordBE;
      offset_y:=typeReadWordBE;
    end else
    if (typeframe2=203) then begin
      SkipBytes(1*2);
      idpointer_frame:=typeReadCardinalBE;
      SkipBytes(3*2);
      offset_x:=typeReadWordBE;
      offset_y:=typeReadWordBE;
      imageoffset_x:=typeReadWordBE;
      imageoffset_y:=typeReadWordBE;
    end else raise Exception.Create('Unknown typeframe2');
  end;
end;

procedure readFrame(framenum:word);
var i:word;
begin
  with info.frames[framenum] do begin
    typeframe:=typeReadWordBE;
    id_frame:=typeReadWordBE;
    if (typeframe=101) or (typeframe=103) then begin
      SkipBytes(12*2);
      numids:=typeReadWordBE;
      if numids > 0 then
        for i:=0 to numids-1 do ids[i]:=typeReadWordBE;
      SkipBytes(1*2);
      numinfos:=typeReadWordBE;
      if numinfos > 0 then
        for i:=0 to numinfos-1 do readFrame2(framenum,i);
    end else
    if (typeframe=102) then begin
      SkipBytes(2*2);
      size_x:=typeReadWordBE;
      size_y:=typeReadWordBE;
      SkipBytes(8*2);
      numinfos:=typeReadWordBE;
      if numinfos > 0 then
        for i:=0 to numinfos-1 do readFrame2(framenum,i);
    end else raise Exception.Create('Unknown typeframe');
    SkipBytes(1*2);
  end;
end;

procedure readInfo;
var i:word;
begin
  SkipBytes(1*2);
  info.screenwidth:=typeReadWordBE;
  info.screenheight:=typeReadWordBE;
  SkipBytes(6*2);
  info.page_start:=typeReadCardinalBE;
  info.numframes:=typeReadWordBE;
  if info.numframes > 0 then
    for i:=0 to info.numframes-1 do readFrame(i);
end;

procedure readIndexitem(indexnum:word);
var i:word;
begin
  with index.indexitems[indexnum] do begin
    indexword:=typeReadWordBE;
    SkipBytes(2*2);
    idpage:=typeReadCardinalBE;
    nbpopups:=typeReadWordBE;
    if nbpopups > 0 then
      for i:=0 to nbpopups-1 do begin
        popups[i]:=typeReadCardinalBE;
      end;
  end;
end;

procedure readIndex;
var i:word;
begin
  index.indexlen:=typeReadCardinalBE;
  if index.indexlen > 0 then
    for i:=0 to index.indexlen-1 do readIndexitem(i);
end;

function readAction:TACTION;
var action:TACTION;
begin
  with action do begin
    typeaction:=typeReadWordBE;
    if (typeaction = 0) then begin
      popup_id:=typeReadWordBE;
      SkipBytes(2*2);
    end else
    if (typeaction = 1) then begin
      popup_id:=typeReadCardinalBE;
      popuplevel:=typeReadWordBE;
      if (typeReadWordBE <> 0) then SkipBytes(-2);
      if (popup_id = 60426) then SkipBytes(16);
    end else
    if (typeaction = 2) then begin
      item_id:=typeReadWordBE;
      SkipBytes(1*2);
      if (typeReadWordBE <> 0) then SkipBytes(-2);
    end else
    if (typeaction = 3) then begin
      linkto:=typeReadCardinalBE;
      SkipBytes(1*2);
      if (typeReadWordBE <> 0) then SkipBytes(-2);
    end else
    if (typeaction = 4) then begin
      soundtoplay:=typeReadWordBE;
      SkipBytes(1*4);
      SkipBytes(3*2);
      if (typeReadWordBE <> 0) then SkipBytes(-2);
    end else
    if (typeaction = 7) then begin
      anim:=typeReadWordBE;
      SkipBytes(5*2);
      if (typeReadWordBE <> 0) then SkipBytes(-2);
    end else
    if (typeaction = 11) then begin
      command:=typeReadWordBE;
      if (typeReadWordBE <> 0) then SkipBytes(-2);
    end else
    if (typeaction = 12) then begin
      popup_to_close:=typeReadCardinalBE;
    end else
    if (typeaction = 36) then begin
      SkipBytes(2*2);
    end else raise Exception.Create('Unknown typeaction');
  end;
  result:=action;
end;

function readItem:TITEM;
var item:TITEM;
    i:smallint;
begin
  with item do begin
    itemtype:=typeReadWordBE;
    item_id:=typeReadWordBE;
    item_props:=typeReadWordBE;
    if (itemtype = 601) then begin
      SkipBytes(2*2);
      imgwidth:=typeReadWordBE;
      imgheight:=typeReadWordBE;
      SkipBytes(2*2);
      image:=typeReadWordBE;
    end else
    if (itemtype = 602) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(2*2);
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      anim:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(1*2);
      autostart:=typeReadWordBE;
      SkipBytes(1*2);
    end else
    if (itemtype = 603) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(2*2);
      numactions:=typeReadWordBE;
      for i:=0 to numactions-1 do actions[i]:=readAction;
    end else
    if (itemtype = 604) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(2*2);
      letter:=typeReadWordBE;
    end else
    if (itemtype = 605) then begin
      SkipBytes(6*2);
    end else
    if (itemtype = 606) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(1*2);
      anim:=typeReadWordBE;
      SkipBytes(1*2);
    end else
    if (itemtype = 607) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      page_skip:=typeReadWordBE;
      if (page_skip = 1) then begin
        SkipBytes(3*2);
        nextpage:=typeReadCardinalBE;
        SkipBytes(1*2);
      end;
      anim:=typeReadWordBE;
      SkipBytes(1*2);
    end else
    if (itemtype = 608) then begin
      x1:=typeReadWordBE;
      y1:=typeReadWordBE;
      x2:=typeReadWordBE;
      y2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(5*2);
      popup_id:=typeReadWordBE;
      SkipBytes(3*2);
    end else
    if (itemtype = 609) then begin
      SkipBytes(1*2);
      x1:=typeReadWordBE;
      x2:=typeReadWordBE;
      SkipBytes(6*2);
      image:=typeReadWordBE;
    end else
    if (itemtype = 610) then begin
      SkipBytes(1*2);
      x1:=typeReadWordBE;
      x2:=typeReadWordBE;
      cursor:=typeReadWordBE;
      SkipBytes(5*2);
      SkipBytes(8*2);
    end else raise Exception.Create('Unknown itemtype');
  end;
  result:=item;
end;

function readPage(idpage:longint):TPAGE;
var page:TPAGE;
    i,j,k:smallint;
    nblinks,tmp:smallint;
    tmp2:cardinal;
begin
  if (idpage >= longint(pointers.nbpointers)) then PNG.Seek(cardinal(idpage)+header.pages_start,soFromBeginning) else
  if (idpage >= 0) then PNG.Seek(pointers.pointers[idpage]+header.pages_start,soFromBeginning) else begin
    pointers.pointers[pointers.nbpointers]:=PNG.Position-header.pages_start; // Création d'une liste de pointeurs
    inc(pointers.nbpointers);
  end;
  with page do begin
    typepage:=typeReadWordBE;
    while (typepage=-1) do typepage:=typeReadWordBE; // Sert de NOP - N'EXISTE PAS DANS LE FICHIER ORIGINAl!
    if (typepage=0) then begin
      id_frame:=typeReadWordBE;
      numitems:=typeReadWordBE;
      nblinks:=0;
      for i:=0 to numitems-1 do begin
        items[i]:=readItem;
        if (items[i].itemtype = 606) then inc(nblinks);
      end;
      SkipBytes(1*2);
      k:=0;
      for i:=1 to nblinks do begin
        tmp:=typeReadWordBE+k;
        SkipBytes((nblinks-i)*2+((i-1)*4));
        for j:=0 to numitems-1 do if (items[j].item_id = tmp) then items[j].page_skip:=typeReadCardinalBE;
        SkipBytes(0-((nblinks-i)*2+(i*4)));
        k:=-k;
      end;
      SkipBytes(nblinks*4);
    end else
    if (typepage=101) or (typepage=102) or (typepage=103) then begin
      id_frame:=typeReadWordBE;
      xoffset:=typeReadWordBE;
      yoffset:=typeReadWordBE;
      basedirectory:=typeReadWordBE;
      SkipBytes(1*2);
      tmp:=typeReadWordBE;
      SkipBytes(1*2);
      if (tmp < 201) then SkipBytes(tmp*3);
      numitems:=typeReadWordBE;
      for i:=0 to numitems-1 do items[i]:=readItem;
      links_infos:=typeReadWordBE;
      while ((links_infos > 600) and (links_infos < 610)) do begin
        SkipBytes(-2);
        inc(numitems);
        items[numitems-1]:=readItem;
        links_infos:=typeReadWordBE;
      end;
      tmp:=typeReadWordBE;
      more_infos:=0;
      if (tmp <> 4) then begin
        more_infos:=typeReadWordBE;
        if (more_infos = 1) then begin
          if (links_infos = 0) then begin
            related_principles_popup:=typeReadCardinalBE;
            machines_page:=typeReadCardinalBE;
            inventors_page:=typeReadCardinalBE;
            timeline_page:=typeReadCardinalBE;
          end else begin
            SkipBytes(5*2);
          end;
        end;
        if (more_infos = 8124) then begin
          SkipBytes(-4);
          for i:=0 to 25 do begin
            tmp2:=typeReadCardinalBE;
            for j:=0 to numitems-1 do if (items[j].letter = i) then items[j].page_skip:=tmp2;
          end;
          SkipBytes(26*2); // Don't know what this is...
          SkipBytes(2*2);
        end;
      end;
    end else raise Exception.Create('Unknown typepage');
  end;
  result:=page;
end;

{ Exported functions }

function OpenPNG(filename:string):boolean;
begin
  OpenPNG:=false;
  PNG:=OpenFile(filename);
  if PNG <> nil then begin
    readHeader;
    if (not readStrings) then exit;
    readInfo;
    readIndex;
    // La version EN n'a pas de pointeurs, les n° de page est en fait la position dans le fichier PNG, d'où les grands nombres.
    pointers.nbpointers:=0; // Pour l'export on va donner des n° de page.
    while (PNG.Position <> PNG.Size) do readPage(-1);
    OpenPNG:=true;
  end;
end;

procedure ClosePNG;
begin
  if PNG <> nil then PNG.Free;
end;

function ReadPagePNG(idpointer:longint):TPAGE;
begin
  try
    result:=readPage(idpointer);
  except
    MessageBox(Application.Handle,'Fichier TWTW.ANI corrompu.','Erreur',0);
    Application.Terminate;
    exit;
  end;
end;

function getIDPointer(idpointer:longint):longint;
var i:longint;
begin
  getIDPointer:=idpointer;
  for i:=0 to longint(pointers.nbpointers)-1 do if pointers.pointers[i] = cardinal(idpointer) then getIDPointer:=i;
end;

function fixedNavBar(item_id:smallint; actualmachines_page, actualrelated_principles_popup, actualtimeline_page, actualinventors_page:IDPOINTER):IDPOINTER;
begin
  fixedNavBar:=0;
  case item_id of
	  850: fixedNavBar:=438408; // Atelier
	  -47,851: if actualmachines_page = -1 then fixedNavBar:=57508 else fixedNavBar:=actualmachines_page; // Machines
	  -48,852: if actualrelated_principles_popup = -1 then fixedNavBar:=350946 else fixedNavBar:=actualrelated_principles_popup; // Grands Principes
	  -49,853: if actualtimeline_page = -1 then fixedNavBar:=426052 else fixedNavBar:=actualtimeline_page; // Histoire
	  -50,854: if actualinventors_page = -1 then fixedNavBar:=196062 else fixedNavBar:=actualinventors_page; // Inventeurs
	  855: fixedNavBar:=-51;  // Retour, géré plus bas
	  856: fixedNavBar:=211350; // Index
	  857: fixedNavBar:=278816; // Options
	  858: fixedNavBar:=117408; // Aide
  end;
end;

end.
