unit OpenMP3_Form_Main;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.MMSystem, Winapi.ShellApi,
  Winapi.DirectSound, Winapi.DirectDraw,
  System.SysUtils, System.Variants, System.Classes, System.Math, System.RTLConsts,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls,
  minimp3lib, Vcl.ExtCtrls;

const
  cBitsPerSample = 16; // Word;

type  // Riff Wave File Header
  TWaveFormatHeader = record // Cut WaveformatEx (leave cbSize);
      wFormatTag: Word;       { format type }
      nChannels: Word;        { number of channels (i.e. mono, stereo, etc.) }
      nSamplesPerSec: DWORD;  { sample rate }
      nAvgBytesPerSec: DWORD; { for buffer estimation }
      nBlockAlign: Word;      { block size of data }
      wBitsPerSample: Word;   { number of bits per sample of mono data }
    end;

  TRIFFWaveFileHeader = record
    riffIdent: DWORD;
    riffSize : DWORD;
    waveIdent: DWORD;
    fmtIdent : DWORD;
    fmtLength: DWORD;
    wavehdr  : TWaveFormatHeader;
    dataIdent: DWORD;
    dataSize : DWORD;
  end;

  TMemoryStreamExtend = class(TMemoryStream)
  private
    function GetMemoryAtPosition: Pointer;
    function GetBytesLeft: Longint;
  public
    function IncPtr(const Bytes: Longint): Boolean;
    property DataPtr: Pointer read GetMemoryAtPosition;
    property DataLen: Longint read GetBytesLeft;
  end;

  TMP3File = class
  private
    FMP3Decoder     : mp3dec_t;
    FMP3Data        : TMemoryStreamExtend;

    FPCMBuffer      : Pointer;
    FPCMBufferOffset: NativeInt;
    FPCMBufferLen   : NativeInt;
    FPCMFrameSize   : NativeInt;
    FPCMTotalSize   : NativeInt;

    // Info
    FMP3Channels    : Integer;
    FMP3Hz          : Cardinal;
    FMP3Layer       : Integer;
    FMP3Bitrate_kbps: Cardinal;
    FAvgBytesPerSec : Cardinal;

    procedure ClearStream();
    function GetFormat(fmt: PWaveFormatEx): Boolean;
    procedure Analyse();
    procedure DecodeTo(const Buffer: Pointer; BufLen: Integer); overload;
    procedure DecodeTo(const Filename: String); overload;
    procedure DecodeTo(const Stream: TStream); overload;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFile(const Filename: String);
  end;

  TPlayerOnProgress = procedure(const Sender: TObject; const Pos, Total: Int64) of object;
  TPlayer = class
  private
    FDSInterface: IDirectSound;
    FDSBufferPrimary  : IDirectSoundBuffer;
    FDSBufferSecondary: IDirectSoundBuffer;
    FMP3File          : TMP3File;
    FWAVHeader        : TWaveFormatEx;
    FDataStream       : TMemoryStream;
    FTimerId          : Cardinal;
    FOnProgress       : TPlayerOnProgress;
    FCaller           : procedure() of object;
    m_pHEvent: array[0..1] of THandle;
    procedure SetFormat(const wfe: PWaveFormatEx);
    function FailedEx(hRes: HResult; Operation: String): Boolean;
    procedure TimerEventBuffer();
    procedure TimerEventStream();
  public
    constructor Create();
    destructor Destroy(); override;

    procedure PlayFile(const mp3: TMP3File);
    procedure Play(const mp3: TMP3File);
    procedure Stop();
  end;

  // Patch Panel for Accept Files
  TPanelOnDropFile = procedure(Sender: TObject; const Filename: String; var AcceptNextFile: Boolean) of object;
  TPanel = class(Vcl.ExtCtrls.TPanel)
  private
    FOnDropFile: TPanelOnDropFile;
  protected
    procedure DropFileEvent(var msg: TWMDropFiles); message WM_DROPFILES;
  public
    property OnDropFile: TPanelOnDropFile read FOnDropFile write FOnDropFile;
  end;

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    Button2: TButton;
    Button3: TButton;
    Label1: TLabel;
    Panel1: TPanel;
    SaveDialog1: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private-Deklarationen }
    FPlayer: TPlayer;
    FMP3File: TMP3File;
    procedure Report(const Text: String; args: array of const); overload;
    procedure Report(const Text: String); overload;
    procedure Progress(const Sender: TObject; const Pos, Total: Int64);
    procedure OnDropFile(Sender: TObject; const Filename: String; var AcceptNextFile: Boolean);
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function ToTime(const Value: Cardinal): String;
begin
  Result := Format('%2.2d:%2.2d', [Value div 60, Value mod 60]);
end;

procedure TimerCallback(uTimerID, uMessage: UINT; dwUser, dw1, dw2: DWORD_PTR); stdcall;
begin
  TPlayer(dwUser).FCaller();
end;

{ TMemoryStreamExtend }

function TMemoryStreamExtend.GetBytesLeft: Longint;
begin
  Result := Size - Position;
end;

function TMemoryStreamExtend.GetMemoryAtPosition: Pointer;
begin
  Result := Pointer(NativeUInt(Memory) + Position);
end;

function TMemoryStreamExtend.IncPtr(const Bytes: Longint): Boolean;
begin
  Result := ((Position + Bytes) < Size);
  Position := Position + Min(Bytes, Size - Position);
end;

{ TPanel }

procedure TPanel.DropFileEvent(var msg: TWMDropFiles);
var
  i, fileCount: Integer;
  fileName: array[0..MAX_PATH] of Char;
  acceptNextFile: Boolean;
begin
  fileCount := DragQueryFile(msg.Drop, $FFFFFFFF, fileName, MAX_PATH);

  if Assigned(FOnDropFile) then
    for i := 0 to fileCount - 1 do
    begin
      DragQueryFile(msg.Drop, i, fileName, MAX_PATH);

      acceptNextFile := True;

      FOnDropFile(Self, String(filename), acceptNextFile);

      if not acceptNextFile then
        Break;
    end;

  DragFinish(msg.Drop);
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  FPlayer.PlayFile(FMP3File);
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  FPlayer.Play(FMP3File);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  if SaveDialog1.Execute then
    FMP3File.DecodeTo(SaveDialog1.FileName);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Model Instance
  DragAcceptFiles(Panel1.Handle, True);
  Panel1.OnDropFile := OnDropFile;

  FPlayer := TPlayer.Create();
  FPlayer.FOnProgress := Progress;
  FMP3File := nil;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  DragAcceptFiles(Panel1.Handle, False);
  FPlayer.Free();

  if Assigned(FMP3File) then
    FreeAndNil(FMP3File);
end;

procedure TForm1.OnDropFile(Sender: TObject; const Filename: String; var AcceptNextFile: Boolean);
var
  sFileExtension: String;
  sBaseFilename: String;
begin
  sFileExtension := ExtractFileExt(Filename);
  sBaseFilename := ExtractFileName(Filename);

  // Load Collada File as biingModel
  if SameText(sFileExtension, '.mp3') then
  begin
    if Assigned(FMP3File) then
    begin
      FPlayer.Stop();
      FreeAndNil(FMP3File);
    end;

    FMP3File := TMP3File.Create();
    FMP3File.LoadFromFile(Filename);

    Report('+++ %s +++', [sBaseFilename]);
    Report('Channels %d', [FMP3File.FMP3Channels]);
    Report('Frequency %d hz', [FMP3File.FMP3Hz]);
    Report('Layers %d', [FMP3File.FMP3Layer]);
    Report('Bitrate %d kbps', [FMP3File.FMP3Bitrate_kbps]);

    Button1.Enabled := True;
    Button2.Enabled := True;
    Button3.Enabled := True;

    AcceptNextFile := False;
  end;
end;

procedure TForm1.Progress(const Sender: TObject; const Pos, Total: Int64);
var
  sec, tot: Double;
begin
  if Pos > 0 then
  begin
    sec := Pos / (Sender as TPlayer).FWAVHeader.nAvgBytesPerSec;
  end else sec := 0;

  tot := Total / (Sender as TPlayer).FWAVHeader.nAvgBytesPerSec;

  Label1.Caption := Format('%d of %d %s of %s', [Pos, Total, ToTime(Round(sec)), ToTime(Round(tot))]);
end;

procedure TForm1.Report(const Text: String; args: array of const);
begin
  Memo1.Lines.Add(Format(Text, args));
end;

procedure TForm1.Report(const Text: String);
begin
  Memo1.Lines.Add(Text);
end;

{ TMP3File }

procedure TMP3File.ClearStream;
begin
  if Assigned(FMP3Data) then
    FreeAndNil(FMP3Data);

  if (FPCMBuffer <> nil) then
    FreeMem(FPCMBuffer, FPCMBufferLen);

  FPCMBuffer := nil;
  FPCMBufferLen := 0;
  FPCMTotalSize := 0;
end;

constructor TMP3File.Create;
begin
  FMP3Data := nil;
  FPCMBuffer := nil;
  FPCMBufferLen := 0;
  FPCMBufferOffset := 0;
  FPCMTotalSize := 0;
end;

procedure TMP3File.DecodeTo(const Stream: TStream);
var
  pcmDat: mp3d_sample_p;
  pmcLen: Cardinal;
  samples: Integer;
  frame_info: mp3dec_frame_info_t;
begin
  pmcLen := FPCMFrameSize;

  GetMem(pcmDat, pmcLen);
  try
    repeat
      samples := _mp3dec_decode_frame(
        @FMP3Decoder,
        FMP3Data.DataPtr,
        FMP3Data.DataLen,
        pcmDat,
        @frame_info
      );

      if (samples = 1152) then
        Stream.Write(pcmDat^, pmcLen)
      else
        OutputDebugString('+++++ INVALID BLOCK ++++++');

      FPCMTotalSize := FPCMTotalSize + FPCMFrameSize;
    until not FMP3Data.IncPtr(frame_info.frame_offset + frame_info.frame_bytes);
  finally
    FreeMem(pcmDat, pmcLen);
  end;
end;

procedure TMP3File.Analyse();
begin

end;

procedure TMP3File.DecodeTo(const Filename: String);
var
  fileStream: TFileStream;
  wavFileHeader: TRIFFWaveFileHeader;
  pcmData: mp3d_sample_p;
  pcmLength: Cardinal;
  wex: tWAVEFORMATEX;
  samples, wavHeaderLen: Integer;
  frame_info: mp3dec_frame_info_t;
begin
  pcmLength := MINIMP3_MAX_SAMPLES_PER_FRAME * FMP3Channels;
  GetMem(pcmData, pcmLength);
  fileStream := TFileStream.Create(Filename, fmCreate);

  wavHeaderLen := SizeOf(TRIFFWaveFileHeader);
  ZeroMemory(@wavFileHeader, wavHeaderLen);
  wavFileHeader.riffIdent := FOURCC_RIFF;

  GetFormat(@wex);

  wavFileHeader.waveIdent := mmioStringToFOURCC('WAVE', 0);
  wavFileHeader.fmtIdent  := mmioStringToFOURCC('fmt', 0);
  wavFileHeader.fmtLength := 16;
  wavFileHeader.dataIdent := mmioStringToFOURCC('data', 0);

  wavFileHeader.wavehdr.wFormatTag := wex.wFormatTag;
  wavFileHeader.wavehdr.nChannels := wex.nChannels;
  wavFileHeader.wavehdr.nSamplesPerSec := wex.nSamplesPerSec;
  wavFileHeader.wavehdr.nAvgBytesPerSec := wex.nAvgBytesPerSec;
  wavFileHeader.wavehdr.nBlockAlign := wex.nBlockAlign;
  wavFileHeader.wavehdr.wBitsPerSample := wex.wBitsPerSample;
  fileStream.Write(wavFileHeader, wavHeaderLen);
  try
    FMP3Data.Position := 0;

    repeat
      samples := _mp3dec_decode_frame(
        @FMP3Decoder,
        FMP3Data.DataPtr,
        FMP3Data.DataLen,
        pcmData,
        @frame_info
      );

      Assert(samples = 1152, 'Unknow');

      fileStream.Write(pcmData^, pcmLength);
      until not FMP3Data.IncPtr(frame_info.frame_offset + frame_info.frame_bytes);

      wavFileHeader.riffSize := fileStream.Size - 8;
      wavFileHeader.dataSize := fileStream.Size - 44;
      fileStream.Position := 0;
      fileStream.Write(wavFileHeader, wavHeaderLen);
  finally
    FreeMem(pcmData, pcmLength);
    fileStream.free;
  end;
end;

procedure TMP3File.DecodeTo(const Buffer: Pointer; BufLen: Integer);
var
  pcmData: mp3d_sample_p;
  pcmSize: NativeInt;
  size: Cardinal;
  samples: Integer;
  frame_info: mp3dec_frame_info_t;
  iRest: Integer;
begin
  pcmData := Pointer(NativeUint(FPCMBuffer) + FPCMBufferOffset);
  pcmSize := FPCMBufferLen - FPCMBufferOffset;
  size := FPCMBufferOffset;
  FPCMBufferOffset := 0;

  while (pcmSize >= FPCMFrameSize) do
  begin
    samples := _mp3dec_decode_frame(
      @FMP3Decoder,
      FMP3Data.DataPtr,
      FMP3Data.DataLen,
      pcmData,
      @frame_info
    );

    pcmData := mp3d_sample_p(NativeUInt(pcmData) + FPCMFrameSize);
    pcmSize := pcmSize - FPCMFrameSize;
    size := size + FPCMFrameSize;
    FPCMTotalSize := FPCMTotalSize + FPCMFrameSize;
    if not FMP3Data.IncPtr(frame_info.frame_offset + frame_info.frame_bytes) then
    begin
      OutputDebugString(PChar('PANIC'));
      break;
    end;
  end;

  CopyMemory(Buffer, FPCMBuffer, BufLen);
  iRest := size - BufLen; // Überhang verschieben auf den Anfang

  if (iRest > 0) then
  begin
    FPCMBufferOffset := iRest;
    CopyMemory(
      FPCMBuffer,
      Pointer(NativeUInt(FPCMBuffer) + BufLen),
      iRest
    );
  end;
end;

destructor TMP3File.Destroy;
begin
  ClearStream();
  inherited;
end;

function TMP3File.GetFormat(fmt: PWaveFormatEx): Boolean;
var
  nAvgBytesPerSec: Integer;
  nBlockAlign: Integer;
begin
  Result := Assigned(fmt) and (FMP3Data <> nil) and (FMP3Data.Size > 0);

  if Result then
  begin
    nAvgBytesPerSec := (cBitsPerSample * FMP3Channels * FMP3Hz) shr 3;
    nBlockAlign     := (cBitsPerSample * FMP3Channels) shr 3;

    // Wave Header
    ZeroMemory(fmt, SizeOf(tWAVEFORMATEX));
    fmt.wFormatTag := WAVE_FORMAT_PCM;
    fmt.nChannels := FMP3Channels;
    fmt.nSamplesPerSec := FMP3Hz;
    fmt.wBitsPerSample := cBitsPerSample;
    fmt.nBlockAlign := nBlockAlign;
    fmt.nAvgBytesPerSec := nAvgBytesPerSec;
  end;
end;

procedure TMP3File.LoadFromFile(const Filename: String);
var
  fs: TFileStream;
  samples: Integer;
  frame_info: mp3dec_frame_info_t;
//  dwDataBytes: NativeInt;
begin
  ClearStream();

  try
    fs := TFileStream.Create(Filename, fmOpenRead);
    try
      FMP3Data := TMemoryStreamExtend.Create();
      FMP3Data.CopyFrom(fs, fs.Size);
    finally
      fs.Free();
    end;
  except
    raise;
  end;

  // Reset Position
  FMP3Data.Position := 0;

  // Init Decoder
  _mp3dec_init(@FMP3Decoder);

  // Decoder the first block; without write pcm data; need info
  samples := _mp3dec_decode_frame(
    @FMP3Decoder,
    FMP3Data.DataPtr,
    FMP3Data.DataLen,
    nil,
    @frame_info
  );

  Assert(samples = 1152, 'Invalid mp3');

  // Skip junk
  Assert(
    FMP3Data.IncPtr(frame_info.frame_offset),
    'no data in file'
  );

  //
//  dwDataBytes := FMP3Data.Size - frame_info.frame_offset;
  FMP3Channels := frame_info.channels;
  FMP3Hz := frame_info.hz;
  FMP3Layer := frame_info.layer;
  FMP3Bitrate_kbps := frame_info.bitrate_kbps;
  FAvgBytesPerSec := (cBitsPerSample * FMP3Channels * FMP3Hz) shr 3;

  // Single Frame 16-bit samples (2 Bytes) * Channels (1 = Mono; 2 = Stereo)
  FPCMFrameSize := (MINIMP3_MAX_SAMPLES_PER_FRAME * frame_info.channels);

  // Calculate the Buffer to hold all decrypted Frames avoid avgBytesPerSecond
  FPCMBufferLen := FPCMFrameSize * ((FAvgBytesPerSec div FPCMFrameSize) + 1);
  FPCMBufferOffset := 0;
  GetMem(FPCMBuffer, FPCMBufferLen);
end;

{ TPlayFile }

constructor TPlayer.Create;
begin
	m_pHEvent[0] := CreateEvent(nil, FALSE, FALSE, PChar('Direct_Sound_Buffer_Notify_0'));
	m_pHEvent[1] := CreateEvent(nil, FALSE, FALSE, PChar('Direct_Sound_Buffer_Notify_1'));
  FDataStream := TMemoryStream.Create();
  FTimerId := 0;
  FOnProgress := nil;
end;

destructor TPlayer.Destroy;
begin
  Stop();
  FDataStream.Free();
  inherited;
end;

function TPlayer.FailedEx(hRes: HResult; Operation: String): Boolean;
begin
  case hRes of
    DS_OK: Exit(False);
    DSERR_BADFORMAT: raise Exception.Create(Operation + ': DSERR_BADFORMAT');
    DSERR_INVALIDPARAM: raise Exception.Create(Operation + ': DSERR_INVALIDPARAM');
    DSERR_INVALIDCALL: raise Exception.Create(Operation + ': DSERR_INVALIDCALL');
    DSERR_OUTOFMEMORY: raise Exception.Create(Operation + ': DSERR_OUTOFMEMORY');
    DSERR_PRIOLEVELNEEDED: raise Exception.Create(Operation + ': DSERR_PRIOLEVELNEEDED');
    DSERR_UNSUPPORTED: raise Exception.Create(Operation + ': DSERR_UNSUPPORTED');
  else
    raise Exception.Create(Operation + ': Unknow Error');
  end;
end;

procedure TPlayer.Play(const mp3: TMP3File);
var
  ptrAudio1: Pointer;
  ptrAudio2: Pointer;
  dwBytesAudio1: Cardinal;
  dwBytesAudio2: Cardinal;
begin
  if not mp3.GetFormat(@FWAVHeader) then
    raise Exception.Create('Fehlermeldung');

  FDataStream.Clear();
  mp3.DecodeTo(FDataStream);
  FDataStream.Position := 0;
  FCaller := TimerEventBuffer;
  FMP3File := mp3;

  SetFormat(@FWAVHeader);

  // Init Buffer
  if FailedEx(
    FDSBufferSecondary.Lock(0, FWAVHeader.nAvgBytesPerSec, @ptrAudio1, @dwBytesAudio1, @ptrAudio2, @dwBytesAudio2, 0),
    'FDSBufferSecondary.Lock')
  then
    Exit;

  if (ptrAudio1 <> nil) then
    ZeroMemory(ptrAudio1, dwBytesAudio1);

  if (ptrAudio2 <> nil) then
    ZeroMemory(ptrAudio2, dwBytesAudio2);

  if (ptrAudio1 <> nil) and (dwBytesAudio1 > 0) then
    FMP3File.DecodeTo(ptrAudio1, dwBytesAudio1);

  if (ptrAudio2 <> nil) and (dwBytesAudio2 > 0) then
    FMP3File.DecodeTo(ptrAudio2, dwBytesAudio2);

  FDSBufferSecondary.Unlock(ptrAudio1, dwBytesAudio1, ptrAudio2, dwBytesAudio2);

  // Start Play
  FDSBufferSecondary.Play(0, 0, DSCBSTART_LOOPING);
  FTimerId := timeSetEvent(300, 100, TimerCallback, Cardinal(Self), TIME_PERIODIC or TIME_CALLBACK_FUNCTION);

  if FTimerId = 0 then
    OutputDebugString('***** TIMER FAILED *****');
end;

procedure TPlayer.PlayFile(const mp3: TMP3File);
var
  ptrAudio1: Pointer;
  ptrAudio2: Pointer;
  dwBytesAudio1: Cardinal;
  dwBytesAudio2: Cardinal;
begin
  if not mp3.GetFormat(@FWAVHeader) then
    raise Exception.Create('Fehlermeldung');

  FCaller := TimerEventStream;
  FMP3File := mp3;

  SetFormat(@FWAVHeader);

  // Init Buffer
  if FailedEx(
    FDSBufferSecondary.Lock(0, FWAVHeader.nAvgBytesPerSec, @ptrAudio1, @dwBytesAudio1, @ptrAudio2, @dwBytesAudio2, 0),
    'FDSBufferSecondary.Lock')
  then
    Exit;

  if (ptrAudio1 <> nil) then
    ZeroMemory(ptrAudio1, dwBytesAudio1);

  if (ptrAudio2 <> nil) then
    ZeroMemory(ptrAudio2, dwBytesAudio2);

  if (ptrAudio1 <> nil) and (dwBytesAudio1 > 0) then
    FMP3File.DecodeTo(ptrAudio1, dwBytesAudio1);

  if (ptrAudio2 <> nil) and (dwBytesAudio2 > 0) then
    FMP3File.DecodeTo(ptrAudio2, dwBytesAudio2);

  FDSBufferSecondary.Unlock(ptrAudio1, dwBytesAudio1, ptrAudio2, dwBytesAudio2);

  // Start Play
  FDSBufferSecondary.Play(0, 0, DSCBSTART_LOOPING);
  FTimerId := timeSetEvent(300, 100, TimerCallback, Cardinal(Self), TIME_PERIODIC or TIME_CALLBACK_FUNCTION);

  if FTimerId = 0 then
    OutputDebugString('***** TIMER FAILED *****');
end;

procedure TPlayer.SetFormat(const wfe: PWaveFormatEx);
var
  hWnd: THandle;
  bufDesc: DSBUFFERDESC;
  lpDSBNotify: IDirectSoundNotify;
  pPosNotify: array[0..1] of DSBPOSITIONNOTIFY;
begin
  if (DirectSoundCreate(nil, FDSInterface, nil) <> DS_OK) then
    raise Exception.Create('DirectSoundCreate: Ups');

	//Set Cooperative Level
	hWnd := GetForegroundWindow();
	if (hWnd = 0) then
		hWnd := GetDesktopWindow();

  if (FDSInterface.SetCooperativeLevel(hWnd, DSSCL_PRIORITY) <> DS_OK) then
    raise Exception.Create('DSInterface.SetCooperativeLevel: Ups');

	//Create Primary Buffer
	ZeroMemory(@bufDesc, SizeOf(DSBUFFERDESC));
	bufDesc.dwSize := SizeOf(DSBUFFERDESC);
	bufDesc.dwFlags := DSBCAPS_PRIMARYBUFFER;

  if Failed(FDSInterface.CreateSoundBuffer(bufDesc, FDSBufferPrimary, nil)) then
  begin
    ShowMessage('Create Primary Sound Buffer Failed!');
    Exit();
  end;

	//Set Primary Buffer Format
	if Failed(FDSBufferPrimary.SetFormat(wfe)) then
  begin
    ShowMessage('Set Primary Format Failed!');
    Exit();
  end;

	//Create Second Sound Buffer
	bufDesc.dwFlags := DSBCAPS_CTRLPOSITIONNOTIFY or DSBCAPS_GLOBALFOCUS;
	bufDesc.dwBufferBytes := 2 * wfe.nAvgBytesPerSec; //2 Seconds Buffer
//  bufDesc.dwBufferBytes := dwBufferSize;
	bufDesc.lpwfxFormat := wfe;

  if Failed(FDSInterface.CreateSoundBuffer(bufDesc, FDSBufferSecondary, nil)) then
  begin
    ShowMessage('Create Secondary Sound Buffer Failed!');
    Exit();
  end;

	//Query DirectSoundNotify
  if Failed(FDSBufferSecondary.QueryInterface(IID_IDirectSoundNotify, lpDSBNotify)) then
  begin
    ShowMessage('QueryInterface DirectSoundNotify Failed!');
    Exit();
  end;

	//Set Direct Sound Buffer Notify Position
	pPosNotify[0].dwOffset := wfe.nAvgBytesPerSec div 2 - 1;
	pPosNotify[1].dwOffset := 3 * wfe.nAvgBytesPerSec div 2 - 1;
	pPosNotify[0].hEventNotify := m_pHEvent[0];
	pPosNotify[1].hEventNotify := m_pHEvent[1];

 	if Failed(lpDSBNotify.SetNotificationPositions(2, @pPosNotify)) then
  begin
    ShowMessage('Set NotificationPosition Failed!');
    Exit();
  end;
end;

procedure TPlayer.Stop;
begin
  if (FDSBufferSecondary <> nil) then
  begin
    OutputDebugString('***** KILLED *****');
    if FTimerId > 0 then
      timeKillEvent(FTimerId);

    FDSBufferSecondary.Stop();
    FDSBufferSecondary := nil;
    FDSBufferPrimary := nil;
    FDSInterface := nil;
  end;
end;

procedure TPlayer.TimerEventBuffer;
var
  ptrAudio1: Pointer;
  ptrAudio2: Pointer;
  dwBytesAudio1: Cardinal;
  dwBytesAudio2: Cardinal;
  dwBytesAvailable: Int64;
  dwBytesWritten: Cardinal;
  dwOffset, dwBytes: Cardinal;
  hr: HRESULT;
begin
  hr := WaitForMultipleObjects(2, @m_pHEvent[0], FALSE, 0);

  if hr = WAIT_OBJECT_0 then
  begin
    OutputDebugString('***** BUFFER(1) *****');
    dwOffset := FWAVHeader.nAvgBytesPerSec;
    dwBytes := FWAVHeader.nAvgBytesPerSec;
  end else if hr = WAIT_OBJECT_0 + 1 then
           begin
             OutputDebugString('***** BUFFER(2) *****');
             dwOffset := 0;
             dwBytes := FWAVHeader.nAvgBytesPerSec;
           end else begin
            Exit;
           end;

  dwBytesAvailable := FDataStream.Size - FDataStream.Position;

  if dwBytesAvailable <= 0 then
  begin
    OutputDebugString('***** STOP *****');
    Stop();
  end;

  hr := FDSBufferSecondary.Lock(dwOffset, dwBytes, @ptrAudio1, @dwBytesAudio1, @ptrAudio2, @dwBytesAudio2, 0);

  if Failed(hr) then
  begin
    OutputDebugString('***** LOCK ERROR *****');
    Exit;
  end;

  if (ptrAudio1 <> nil) and (dwBytesAvailable > 0) then
  begin
    if dwBytesAvailable < dwBytesAudio1 then
      ZeroMemory(ptrAudio1, dwBytesAudio1);

    dwBytesWritten := FDataStream.Read(ptrAudio1^, Min(dwBytesAudio1, dwBytesAvailable));
    dwBytesAvailable := dwBytesAvailable - dwBytesWritten;
  end;

  if (ptrAudio2 <> nil) and (dwBytesAvailable > 0) then
  begin
    if dwBytesAvailable < dwBytesAudio2 then
      ZeroMemory(ptrAudio2, dwBytesAudio2);

    dwBytesWritten := FDataStream.Read(ptrAudio2^, Min(dwBytesAudio2, dwBytesAvailable));
    dwBytesAvailable := dwBytesAvailable - dwBytesWritten;
  end;

  FDSBufferSecondary.Unlock(ptrAudio1, dwBytesAudio1, ptrAudio2, dwBytesAudio2);

  if Assigned(FOnProgress) then
    FOnProgress(Self, FDataStream.Position, FDataStream.Size);

  if dwBytesAvailable <= 0 then
  begin
    OutputDebugString('***** STOP *****');
    Stop();
  end;
end;

procedure TPlayer.TimerEventStream;
var
  ptrAudio1: Pointer;
  ptrAudio2: Pointer;
  dwBytesAudio1: Cardinal;
  dwBytesAudio2: Cardinal;
  dwBytesAvailable: Int64;
  dwBytesWritten: Cardinal;
  dwOffset, dwBytes: Cardinal;
  hr: HRESULT;
begin
  hr := WaitForMultipleObjects(2, @m_pHEvent[0], FALSE, 0);

  if hr = WAIT_OBJECT_0 then
  begin
    dwOffset := FWAVHeader.nAvgBytesPerSec;
    dwBytes := FWAVHeader.nAvgBytesPerSec;
  end else if hr = WAIT_OBJECT_0 + 1 then
           begin
             dwOffset := 0;
             dwBytes := FWAVHeader.nAvgBytesPerSec;

           end else begin
            Exit;
           end;

  dwBytesAvailable := FMP3File.FMP3Data.DataLen;

  if dwBytesAvailable <= 0 then
  begin
    OutputDebugString('***** STOP *****');
    Stop();
  end;

  hr := FDSBufferSecondary.Lock(dwOffset, dwBytes, @ptrAudio1, @dwBytesAudio1, @ptrAudio2, @dwBytesAudio2, 0);

  if Failed(hr) then
  begin
    OutputDebugString('***** LOCK FAILED *****');
    Exit;
  end;

  if (ptrAudio1 <> nil) and (dwBytesAvailable > 0) then
  begin
    if dwBytesAvailable < dwBytesAudio1 then
      ZeroMemory(ptrAudio1, dwBytesAudio1);

    FMP3File.DecodeTo(ptrAudio1, dwBytesAudio1);

//    dwBytesWritten := FDataStream.Read(lpvAudio1^, Min(dwBytesAudio1, dwBytesAvailable));
    dwBytesAvailable := FMP3File.FMP3Data.DataLen;
  end;

  if (ptrAudio2 <> nil) and (dwBytesAvailable > 0) then
  begin
    if dwBytesAvailable < dwBytesAudio2 then
      ZeroMemory(ptrAudio2, dwBytesAudio2);

    FMP3File.DecodeTo(ptrAudio2, dwBytesAudio2);
//    dwBytesWritten := FDataStream.Read(lpvAudio2^, Min(dwBytesAudio2, dwBytesAvailable));
    dwBytesAvailable := FMP3File.FMP3Data.DataLen;
  end;

  FDSBufferSecondary.Unlock(ptrAudio1, dwBytesAudio1, ptrAudio2, dwBytesAudio2);

  if Assigned(FOnProgress) then
    FOnProgress(Self, FMP3File.FPCMTotalSize, 0);

  if FMP3File.FMP3Data.DataLen <= 0 then
  begin
    OutputDebugString('***** STOP *****');
    Stop();
  end;
end;

end.
