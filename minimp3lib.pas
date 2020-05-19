unit minimp3lib;
(*
   Only Works with GCC 4.8.1 32 bit

   > gcc -c minimp3lib.cpp -o minimp3lib.obj

   Import Basic functions from minimp3
*)

interface

const
  MINIMP3_MAX_SAMPLES_PER_FRAME = 1152*2;

type
  mp3d_sample_p = PWord;

  mp3dec_frame_info_p = ^mp3dec_frame_info_t;
  mp3dec_frame_info_t = record
    frame_bytes, frame_offset, channels, hz, layer, bitrate_kbps: integer;
  end;

  mp3dec_p = ^mp3dec_t;
  mp3dec_t = record
    mdct_overlap: array[0..1, 0..287] of single;
    qmf_state: array[0..959] of single;
    reserv: integer;
    free_format_bytes: integer;
    header: array[0..3] of Byte;
    reserv_buf: array[0..510] of Byte;
  end;

function _mp3dec_version: Integer; cdecl; external;
procedure _mp3dec_init(dec: mp3dec_p); cdecl; external;
function _mp3dec_decode_frame(dec: mp3dec_p; mp3_data: PByte; mp3_bytes: Integer; pcm_data: mp3d_sample_p; info: mp3dec_frame_info_p): Integer; cdecl; external;

implementation

uses
  Winapi.Windows, System.SysUtils;

const
  MINIMP3LIB_VERSION = $1010;

{$LINK MINIMP3LIB.OBJ}
{$LINK CHKSTK_MS.OBJ}

procedure ___chkstk_ms; cdecl; external;

function _memset(P: Pointer; B: Byte; count: Integer): pointer; cdecl;
begin
  result := P;
  FillChar(P^, count, B);
end;

procedure _memcpy(dest, source: Pointer; count: Integer); cdecl;
begin
  Move(source^, dest^, count);
end;

procedure _memmove(dest: Pointer; src: Pointer; num: Integer); cdecl;
begin
  Move(src^, dest^, num);
end;

//int memcmp ( const void * ptr1, const void * ptr2, size_t num );
function _memcmp(ptr1, ptr2: Pointer; num: Integer): Integer; cdecl;
begin
  Result := Integer(CompareMem(ptr1, ptr2, num));
end;

// void* malloc (size_t size);
function _malloc(size: Integer): Pointer; cdecl;
begin
  GetMem(Result, size);
end;

// void* realloc (void* ptr, size_t size);
function _realloc(ptr: Pointer; size: Integer): Pointer;
begin
  Result := ReallocMemory(ptr, size)
end;

procedure _free(ptr: Pointer);
begin
  FreeMem(ptr);
end;

initialization
  Assert(_mp3dec_version = MINIMP3LIB_VERSION, 'Wrong minimp3lib version');
end.
