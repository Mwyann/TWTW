unit CCM_Zip;
// Copyright 2005 Patrik Spanel
// scilib@sendme.cz

// Written from scratch using InfoZip PKZip file specification application note

// ftp://ftp.info-zip.org/pub/infozip/doc/appnote-iz-latest.zip

// uses the Borland out of the box zlib


// 2005 Added support for streams (LoadFromStream(const ZipFileStream: TStream),SaveToStream(...)) 

// Nick Naimo <nick@naimo.com> added support for folders on 6/29/2004 
// Marcin Wojda <Marcin@sacer.com.pl> added exceptions and try finally blocks
// Jarek Stok³osa <jarek.stoklosa@gmail.com> 11/04/2008 added support for additional file descriptor(LoadFromStream and SaveToStream), add const section;

interface

uses SysUtils, Classes, zlib, Windows;

type
  TFileDescriptor = packed record
    Crc32: DWORD; //                          4 bytes
    CompressedSize: DWORD; //                 4 bytes
    UncompressedSize: DWORD; //               4 bytes
  end;

  TCommonFileHeader = packed record
    VersionNeededToExtract: WORD; //       2 bytes
    GeneralPurposeBitFlag: WORD; //        2 bytes
    CompressionMethod: WORD; //              2 bytes
    LastModFileTimeDate: DWORD; //             4 bytes
    FileDescriptor:TFileDescriptor;
    FilenameLength: WORD; //                 2 bytes
    ExtraFieldLength: WORD; //              2 bytes
  end;

  TLocalFile = packed record
    LocalFileHeaderSignature: DWORD; //     4 bytes  (0x04034b50)
    CommonFileHeader: TCommonFileHeader; //
    filename: string[255];
    CompressedDataStart: DWORD;
    CompressedDataLength: DWORD;
  end;

  TZipFile = class(TObject)
    Files: array of TLocalFile;
    ZipFileStream: TStream;
  private
    function GetUncompressed(i: integer): TMemoryStream;
  public
    procedure LoadZip;
    procedure OpenFromFile(const filename: string);
    procedure Close();
    function SearchFile(filename: string): integer;
  end;

  EZipFileCRCError = class(Exception);
  const
   dwLocalFileHeaderSignature = $04034B50;
   dwLocalFileDescriptorSignature = $08074B50;
   dwCentralFileHeaderSignature = $02014B50;
   dwEndOfCentralDirSignature = $06054b50;

function ZipCRC32(const Data: string): longword;
function OpenFile(filename:string):TMemoryStream;

var TWTWZip: TZipFile;
    cdroot: string;

implementation

{ TZipFile }

procedure TZipFile.LoadZip;
var
  n: integer;
  signature: DWORD;
  searchSignature:DWORD;
  c:AnsiChar;
  s:AnsiString;
begin
  n := 0;
  repeat
    signature := 0;
    ZipFileStream.Read(signature, 4);
    if   (ZipFileStream.Position =  ZipFileStream.Size) then exit;
  until signature = dwLocalFileHeaderSignature;
  repeat
    begin
      if (signature = dwLocalFileHeaderSignature) then
      begin
        inc(n);
        SetLength(Files, n);
        //SetLength(CentralDirectory, n);
        with Files[n - 1] do
        begin
          LocalFileHeaderSignature := signature;
          ZipFileStream.Read(CommonFileHeader, SizeOf(CommonFileHeader));
          SetLength(s, CommonFileHeader.FilenameLength);
          ZipFileStream.Read(PChar(s)^, CommonFileHeader.FilenameLength);
          filename:=s;
          ZipFileStream.Seek(CommonFileHeader.ExtraFieldLength, soFromCurrent);
          CompressedDataStart := ZipFileStream.Position;
          if ((CommonFileHeader.GeneralPurposeBitFlag and 8) = 8) then
          begin
            searchSignature := 0;
            repeat
              ZipFileStream.Read(searchSignature, 4);
              if searchSignature <> dwLocalFileDescriptorSignature then
              begin
                ZipFileStream.Seek(-4, soFromCurrent);
                ZipFileStream.Read(c, SizeOf(c));
              end;
            until  searchSignature = dwLocalFileDescriptorSignature;
            CompressedDataLength := ZipFileStream.Position-CompressedDataStart;
            ZipFileStream.Read(CommonFileHeader.FileDescriptor, SizeOf(CommonFileHeader.FileDescriptor));
          end
          else
          begin
            CompressedDataLength := CommonFileHeader.FileDescriptor.CompressedSize;
            ZipFileStream.Seek(CompressedDataLength, soFromCurrent);
          end;
        end;
      end;
    end;
    signature := 0;
    ZipFileStream.Read(signature, 4);
  until signature <> (dwLocalFileHeaderSignature);
end;

procedure TZipFile.OpenFromFile(const filename: string);
begin
  ZipFileStream := TFileStream.Create(filename, fmOpenRead or fmShareDenyWrite);
end;

procedure TZipFile.Close();
begin
  try
    ZipFileStream.Free;
  finally
  end;
end;

function TZipFile.GetUncompressed(i: integer): TMemoryStream;
var
  Decompressor: TDecompressionStream;
  UncompressedStream: TStringStream;
  UncompressedData: TMemoryStream;
  Aheader: string;
  ReadBytes: integer;
  LoadedCrc32: DWORD;
  CompressedData: AnsiString;
  UncompressedString: AnsiString;
begin
  if (i < 0) or (i > High(Files)) then
    raise Exception.Create('Index out of range.');
  Aheader := chr(120) + chr(156);
  //manufacture a 2 byte header for zlib; 4 byte footer is not required.
  ZipFileStream.Seek(Files[i].CompressedDataStart, soFromBeginning);
  SetLength(CompressedData, Files[i].CompressedDataLength);
  ZipFileStream.Read(PChar(CompressedData)^, Files[i].CompressedDataLength);
  UncompressedStream := TStringStream.Create(Aheader + CompressedData);
  try {+}
    Decompressor := TDecompressionStream.Create(UncompressedStream);
    try {+}
      SetLength(UncompressedString, Files[i].CommonFileHeader.FileDescriptor.UncompressedSize);
      ReadBytes := Decompressor.Read(PChar(UncompressedString)^, Files[i].CommonFileHeader.FileDescriptor.UncompressedSize);
      UncompressedData := TMemoryStream.Create;
      UncompressedData.Write(PChar(UncompressedString)^,ReadBytes);
      UncompressedData.Seek(0,soFromBeginning);
      Result := UncompressedData;
      if ReadBytes <> integer(Files[i].CommonFileHeader.FileDescriptor.UncompressedSize) then
        Result := nil;
    finally
      Decompressor.Free;
    end;
  finally
    UncompressedStream.Free;
  end;

  LoadedCRC32 := ZipCRC32(UncompressedString);
  if LoadedCRC32 <> Files[i].CommonFileHeader.FileDescriptor.Crc32 then
    // - Result := '';
    raise EZipFileCRCError.CreateFmt('CRC Error in "%s".', [Files[i].filename]);
end;

function TZipFile.SearchFile(filename: string): integer;
var i:dword;
begin
  result:=-1;
  for i:=1 to Length(filename) do if filename[i] = '\' then filename[i] := '/';
  filename:=UpperCase(filename);
  for i:=0 to Length(Files)-1 do begin
    if UpperCase(Files[i].filename) = filename then begin
      result:=i;
      break;
    end;
  end;
end;

{ ZipCRC32 }

//calculates the zipfile CRC32 value from a string

function ZipCRC32(const Data: string): longword;
const
  CRCtable: array[0..255] of DWORD = (
    $00000000, $77073096, $EE0E612C, $990951BA, $076DC419, $706AF48F, $E963A535,
    $9E6495A3, $0EDB8832, $79DCB8A4,
    $E0D5E91E, $97D2D988, $09B64C2B, $7EB17CBD, $E7B82D07, $90BF1D91, $1DB71064,
    $6AB020F2, $F3B97148, $84BE41DE,
    $1ADAD47D, $6DDDE4EB, $F4D4B551, $83D385C7, $136C9856, $646BA8C0, $FD62F97A,
    $8A65C9EC, $14015C4F, $63066CD9,
    $FA0F3D63, $8D080DF5, $3B6E20C8, $4C69105E, $D56041E4, $A2677172, $3C03E4D1,
    $4B04D447, $D20D85FD, $A50AB56B,
    $35B5A8FA, $42B2986C, $DBBBC9D6, $ACBCF940, $32D86CE3, $45DF5C75, $DCD60DCF,
    $ABD13D59, $26D930AC, $51DE003A,
    $C8D75180, $BFD06116, $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F, $2802B89E,
    $5F058808, $C60CD9B2, $B10BE924,
    $2F6F7C87, $58684C11, $C1611DAB, $B6662D3D, $76DC4190, $01DB7106, $98D220BC,
    $EFD5102A, $71B18589, $06B6B51F,
    $9FBFE4A5, $E8B8D433, $7807C9A2, $0F00F934, $9609A88E, $E10E9818, $7F6A0DBB,
    $086D3D2D, $91646C97, $E6635C01,
    $6B6B51F4, $1C6C6162, $856530D8, $F262004E, $6C0695ED, $1B01A57B, $8208F4C1,
    $F50FC457, $65B0D9C6, $12B7E950,
    $8BBEB8EA, $FCB9887C, $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65, $4DB26158,
    $3AB551CE, $A3BC0074, $D4BB30E2,
    $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB, $4369E96A, $346ED9FC, $AD678846,
    $DA60B8D0, $44042D73, $33031DE5,
    $AA0A4C5F, $DD0D7CC9, $5005713C, $270241AA, $BE0B1010, $C90C2086, $5768B525,
    $206F85B3, $B966D409, $CE61E49F,
    $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4, $59B33D17, $2EB40D81, $B7BD5C3B,
    $C0BA6CAD, $EDB88320, $9ABFB3B6,
    $03B6E20C, $74B1D29A, $EAD54739, $9DD277AF, $04DB2615, $73DC1683, $E3630B12,
    $94643B84, $0D6D6A3E, $7A6A5AA8,
    $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1, $F00F9344, $8708A3D2, $1E01F268,
    $6906C2FE, $F762575D, $806567CB,
    $196C3671, $6E6B06E7, $FED41B76, $89D32BE0, $10DA7A5A, $67DD4ACC, $F9B9DF6F,
    $8EBEEFF9, $17B7BE43, $60B08ED5,
    $D6D6A3E8, $A1D1937E, $38D8C2C4, $4FDFF252, $D1BB67F1, $A6BC5767, $3FB506DD,
    $48B2364B, $D80D2BDA, $AF0A1B4C,
    $36034AF6, $41047A60, $DF60EFC3, $A867DF55, $316E8EEF, $4669BE79, $CB61B38C,
    $BC66831A, $256FD2A0, $5268E236,
    $CC0C7795, $BB0B4703, $220216B9, $5505262F, $C5BA3BBE, $B2BD0B28, $2BB45A92,
    $5CB36A04, $C2D7FFA7, $B5D0CF31,
    $2CD99E8B, $5BDEAE1D, $9B64C2B0, $EC63F226, $756AA39C, $026D930A, $9C0906A9,
    $EB0E363F, $72076785, $05005713,
    $95BF4A82, $E2B87A14, $7BB12BAE, $0CB61B38, $92D28E9B, $E5D5BE0D, $7CDCEFB7,
    $0BDBDF21, $86D3D2D4, $F1D4E242,
    $68DDB3F8, $1FDA836E, $81BE16CD, $F6B9265B, $6FB077E1, $18B74777, $88085AE6,
    $FF0F6A70, $66063BCA, $11010B5C,
    $8F659EFF, $F862AE69, $616BFFD3, $166CCF45, $A00AE278, $D70DD2EE, $4E048354,
    $3903B3C2, $A7672661, $D06016F7,
    $4969474D, $3E6E77DB, $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0, $A9BCAE53,
    $DEBB9EC5, $47B2CF7F, $30B5FFE9,
    $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6, $BAD03605, $CDD70693, $54DE5729,
    $23D967BF, $B3667A2E, $C4614AB8,
    $5D681B02, $2A6F2B94, $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D);
var
  i: integer;
begin
  result := $FFFFFFFF;
  for i := 0 to length(Data) - 1 do
    result := (result shr 8) xor (CRCtable[byte(result) xor Ord(Data[i + 1])]);
  result := result xor $FFFFFFFF;
end;

function OpenFile(filename:string):TMemoryStream;
var i:integer;
    tm:TMemoryStream;
    tf:TFileStream;
begin
  tm:=nil;
  if (filename[1]) = '\' then delete(filename,1,1);
  if TWTWZip <> nil then begin
    i:=TWTWZip.SearchFile(filename);
    if i <> -1 then tm := TWTWZip.GetUncompressed(i);
  end else begin
    if (FileExists(cdroot+'\'+filename)) then begin
      tm:=TMemoryStream.Create;
      tf:=TFileStream.Create(cdroot+'\'+filename, fmOpenRead or fmShareDenyWrite);
      tm.LoadFromStream(tf);
      tf.Free;
    end;
  end;
  result := tm;
end;

end.

