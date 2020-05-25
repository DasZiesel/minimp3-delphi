program OpenMP3Demo;

uses
  Vcl.Forms,
  OpenMP3_Form_Main in 'OpenMP3_Form_Main.pas' {Form1},
  minimp3lib in 'minimp3lib.pas',
  openal in 'openal.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
