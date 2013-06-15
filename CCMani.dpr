program CCMani;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  CCM_Ani in 'CCM_Ani.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
