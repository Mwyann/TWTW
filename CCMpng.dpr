program CCMpng;

uses
  Forms,
  CCM_Main in 'CCM_Main.pas' {TWTW},
  CCM_Png in 'CCM_Png.pas',
  CCM_Ani in 'CCM_Ani.pas',
  CCM_Zip in 'CCM_Zip.pas',
  CCM_PngEN in 'CCM_PngEN.pas',
  CCM_PngFR in 'CCM_PngFR.pas',
  FTGifAnimate in 'FTGifAnimate.pas',
  GIFImage in 'GifImage.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'CCM emulator';
  Application.CreateForm(TTWTW, TWTW);
  Application.Run;
end.
