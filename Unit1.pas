unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    Button2: TButton;
    Button8: TButton;
    Edit1: TComboBox;
    Panel1: TPanel;
    PaintBox1: TPaintBox;
    procedure FormShow(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses CCM_Ani, CCM_Zip;

procedure TForm1.FormShow(Sender: TObject);
var sc:TSearchRec;
    e:integer;
begin
  e:=findfirst('*.ANI',$3F,sc);
  while e=0 do begin
    Edit1.Items.Add(sc.name);
    e:=findnext(sc);
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  CCMPlayAni(edit1.text,0,0,false);
end;

procedure TForm1.Button8Click(Sender: TObject);
begin
  CCMStopAni;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
begin
  CCMRefresh;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  cdroot:='.';
  AniRect:=Rect(0,0,638,460);
  CCMCanvas:=PaintBox1.Canvas;
  Panel1.DoubleBuffered:=true;
end;

end.
