unit fontloader;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, raylib, math, LConvEncoding;

const
  MAX_IMG_W    = 600;
  MAX_IMG_H    = 800;

procedure LoadFontWithRanges(var font: TFont; size: Integer; const fontPath: PChar; ranges: array of Integer);
procedure LoadFontWithPreset(var font: TFont; size: Integer; const fontPath: PChar; preset: Integer);
function DecodeBase64(const Input: string; var Output: TBytes): Boolean;
function LoadTextureFromBase64(const Base64Data: string): TTexture2D;
function FindSubStr(const SubStr, Str: string; Offset: Integer): Integer;
function DecodeXMLEntities(const S: string): string;
function ConvertEncodingIfNeeded(var Content: string): Boolean;

implementation

procedure LoadFontWithRanges(var font: TFont; size: Integer; const fontPath: PChar;
  ranges: array of Integer);
var
  i, j, totalCodepoints, rangeStart, rangeStop, currentRangeSize: Integer;
  updatedCodepoints: PInteger;
  tempFont: TFont;
begin
  if font.texture.id <> 0 then UnloadFont(font);
  tempFont := LoadFont(fontPath);
  totalCodepoints := 0;
  i := 0;
  while i < Length(ranges) do
  begin
    rangeStart := ranges[i]; rangeStop := ranges[i + 1];
    totalCodepoints := totalCodepoints + (rangeStop - rangeStart + 1);
    Inc(i, 2);
  end;
  totalCodepoints := totalCodepoints + tempFont.glyphCount;
  updatedCodepoints := GetMem(totalCodepoints * SizeOf(Integer));
  try
    for i := 0 to tempFont.glyphCount - 1 do updatedCodepoints[i] := tempFont.glyphs[i].value;
    currentRangeSize := tempFont.glyphCount;
    i := 0;
    while i < Length(ranges) do
    begin
      rangeStart := ranges[i]; rangeStop := ranges[i + 1];
      for j := rangeStart to rangeStop do
      begin updatedCodepoints[currentRangeSize] := j; Inc(currentRangeSize); end;
      Inc(i, 2);
    end;
    font := LoadFontEx(fontPath, size, updatedCodepoints, totalCodepoints);
  finally
    FreeMem(updatedCodepoints);
    UnloadFont(tempFont);
  end;
end;

procedure LoadFontWithPreset(var font: TFont; size: Integer; const fontPath: PChar;
  preset: Integer);
var
  ranges: array of Integer;
begin
  SetLength(ranges, 0);
  case preset of
    0: begin if font.texture.id <> 0 then UnloadFont(font); font := LoadFont(fontPath); Exit; end;
    1: begin SetLength(ranges, 4); ranges[0] := $00C0; ranges[1] := $017F; ranges[2] := $0180; ranges[3] := $024F; end;
    2: begin SetLength(ranges, 4); ranges[0] := $0370; ranges[1] := $03FF; ranges[2] := $1F00; ranges[3] := $1FFF; end;
    3: begin
        SetLength(ranges, 14);
        ranges[0]  := $0400; ranges[1]  := $04FF;
        ranges[2]  := $0500; ranges[3]  := $052F;
        ranges[4]  := $2DE0; ranges[5]  := $2DFF;
        ranges[6]  := $A640; ranges[7]  := $A69F;
        ranges[8]  := $2000; ranges[9]  := $206F;
        ranges[10] := $0080; ranges[11] := $00FF;
        ranges[12] := $0100; ranges[13] := $017F;
      end;
    4: begin
        SetLength(ranges, 18);
        ranges[0]  := $4E00; ranges[1]  := $9FFF;  ranges[2]  := $3400; ranges[3]  := $4DBF;
        ranges[4]  := $3000; ranges[5]  := $303F;  ranges[6]  := $3040; ranges[7]  := $309F;
        ranges[8]  := $30A0; ranges[9]  := $30FF;  ranges[10] := $31F0; ranges[11] := $31FF;
        ranges[12] := $FF00; ranges[13] := $FFEF;  ranges[14] := $AC00; ranges[15] := $D7AF;
        ranges[16] := $1100; ranges[17] := $11FF;
      end;
  end;
  LoadFontWithRanges(font, size, fontPath, ranges);
  SetTextureFilter(font.texture, TEXTURE_FILTER_BILINEAR);
end;

function DecodeBase64(const Input: string; var Output: TBytes): Boolean;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i, j, Len, PadCount, B1, B2, B3, B4: Integer;
  Clean: string;
  Ch: Char;
begin
  Result := False;
  SetLength(Output, 0);
  Clean := '';

  for i := 1 to Length(Input) do
  begin
    Ch := Input[i];
    if (Ch <= #32) then Continue;
    if (Ch in ['&', '<', '>', '"', '''']) then Continue;
    Clean := Clean + Ch;
  end;

  Len := Length(Clean);
  if Len = 0 then Exit;

  PadCount := 0;
  if Clean[Len] = '=' then Inc(PadCount);
  if (Len > 1) and (Clean[Len-1] = '=') then Inc(PadCount);

  SetLength(Output, (Len * 3) div 4 - PadCount);
  if Length(Output) = 0 then Exit;

  i := 1;
  j := 0;
  while (i + 3 <= Len) and (j < Length(Output)) do
  begin
    B1 := Pos(Clean[i], Base64Chars) - 1;
    B2 := Pos(Clean[i+1], Base64Chars) - 1;
    B3 := Pos(Clean[i+2], Base64Chars) - 1;
    B4 := Pos(Clean[i+3], Base64Chars) - 1;

    if (B1 < 0) or (B2 < 0) then Break;

    Output[j] := Byte((B1 shl 2) or (B2 shr 4));
    Inc(j);
    if (j < Length(Output)) and (B3 >= 0) then
    begin
      Output[j] := Byte(((B2 and $0F) shl 4) or (B3 shr 2));
      Inc(j);
    end;
    if (j < Length(Output)) and (B4 >= 0) then
    begin
      Output[j] := Byte(((B3 and $03) shl 6) or B4);
      Inc(j);
    end;
    Inc(i, 4);
  end;
  Result := (j > 0);
end;

function LoadTextureFromBase64(const Base64Data: string): TTexture2D;
var
  ImgData: TBytes;
  Img: TImage;
  Tex: TTexture2D;
  Ext: PAnsiChar;
  Scale: Single;
  NewW, NewH: Integer;
begin
  Result.id      := 0;
  Result.width   := 0;
  Result.height  := 0;
  Result.mipmaps := 1;
  Result.format  := 0;

  if not DecodeBase64(Base64Data, ImgData) then Exit;
  if Length(ImgData) < 20 then Exit;

  if (ImgData[0]=137) and (ImgData[1]=80) and (ImgData[2]=78) and (ImgData[3]=71) then Ext := '.png'
  else if (ImgData[0]=255) and (ImgData[1]=216) and (ImgData[2]=255) then Ext := '.jpg'
  else Ext := '.png';

  Img := LoadImageFromMemory(Ext, @ImgData[0], Length(ImgData));
  if IsImageValid(Img) then
  begin
    NewW := Img.width;
    NewH := Img.height;
    if (NewW > MAX_IMG_W) or (NewH > MAX_IMG_H) then
    begin
      Scale := Min(MAX_IMG_W / NewW, MAX_IMG_H / NewH);
      NewW := Round(NewW * Scale);
      NewH := Round(NewH * Scale);
      ImageResize(@Img, NewW, NewH);
    end;
    Tex := LoadTextureFromImage(Img);
    UnloadImage(Img);
    Result := Tex;
  end;
end;

function FindSubStr(const SubStr, Str: string; Offset: Integer): Integer;
var
  SubLen, StrLen, i: Integer;
begin
  Result := 0;
  SubLen := Length(SubStr);
  StrLen := Length(Str);
  if (SubLen = 0) or (Offset < 1) or (Offset > StrLen) then Exit;

  for i := Offset to StrLen - SubLen + 1 do
  begin
    if Copy(Str, i, SubLen) = SubStr then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

function DecodeXMLEntities(const S: string): string;
var
  i, code, semiPos: Integer;
  entity, utf8char: string;
begin
  Result := S;
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&#160;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&#10;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&#13;', '', [rfReplaceAll]);

  i := 1;
  while i <= Length(Result) do
  begin
    if (Result[i] = '&') and (i + 2 <= Length(Result)) and (Result[i+1] = '#') then
    begin
      semiPos := Pos(';', Result, i+2);
      if semiPos > 0 then
      begin
        entity := Copy(Result, i+2, semiPos - i - 2);
        code   := 0;
        if (Length(entity) > 0) and (entity[1] = 'x') then
          code := StrToIntDef('$' + Copy(entity, 2, MaxInt), 0)
        else
          code := StrToIntDef(entity, 0);

        if code > 31 then
        begin
          if code < $80 then
            utf8char := AnsiChar(code)
          else if code < $800 then
            utf8char := AnsiChar($C0 or (code shr 6)) + AnsiChar($80 or (code and $3F))
          else if code < $10000 then
            utf8char := AnsiChar($E0 or (code shr 12)) + AnsiChar($80 or ((code shr 6) and $3F)) + AnsiChar($80 or (code and $3F))
          else
            utf8char := AnsiChar($F0 or (code shr 18)) + AnsiChar($80 or ((code shr 12) and $3F)) + AnsiChar($80 or ((code shr 6) and $3F)) + AnsiChar($80 or (code and $3F));

          Delete(Result, i, semiPos - i + 1);
          Insert(utf8char, Result, i);
          i := i + Length(utf8char);
        end
        else
        begin
          Delete(Result, i, semiPos - i + 1);
          Continue;
        end;
        Continue;
      end;
    end;
    Inc(i);
  end;

  for i := Length(Result) downto 1 do
  begin
    case Ord(Result[i]) of
      0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 14..31:
        Delete(Result, i, 1); // Удалить управляющие символы нахер
      9, 10, 13:
        Result[i] := ' '; // Заменить табуляцию/переносы на пробел
    end;
  end;
end;

function ConvertEncodingIfNeeded(var Content: string): Boolean;
var
  EncDecl: string;
  HasBOM: Boolean;
  i: Integer;
  b: Byte;
  IsLikelyUTF8: Boolean;
begin
  Result := False;

  HasBOM := (Length(Content) >= 3) and
            (Ord(Content[1]) = $EF) and
            (Ord(Content[2]) = $BB) and
            (Ord(Content[3]) = $BF);
  if HasBOM then
  begin
    Content := Copy(Content, 4, MaxInt);
    Exit(True);
  end;

  EncDecl := LowerCase(Copy(Content, 1, Min(500, Length(Content))));
  if Pos('encoding="utf-8"', EncDecl) > 0 then Exit(True);
  if Pos('encoding="windows-1251"', EncDecl) > 0 then begin Content := CP1251ToUTF8(Content); Exit(True); end;
  if Pos('encoding="koi8-r"', EncDecl) > 0 then begin Content := KOI8RToUTF8(Content); Exit(True); end;

  IsLikelyUTF8 := True;
  i := 1;
  while i <= Length(Content) do
  begin
    b := Ord(Content[i]);
    if b >= $C0 then
    begin
      if (b <= $DF) and (i + 1 <= Length(Content)) and (Ord(Content[i+1]) in [$80..$BF]) then Inc(i, 2)
      else if (b <= $EF) and (i + 2 <= Length(Content)) and (Ord(Content[i+1]) in [$80..$BF]) and (Ord(Content[i+2]) in [$80..$BF]) then Inc(i, 3)
      else if (b <= $F4) and (i + 3 <= Length(Content)) and (Ord(Content[i+1]) in [$80..$BF]) and (Ord(Content[i+2]) in [$80..$BF]) and (Ord(Content[i+3]) in [$80..$BF]) then Inc(i, 4)
      else
      begin
        IsLikelyUTF8 := False;
        Break;
      end;
    end
    else
      Inc(i);
  end;

  if not IsLikelyUTF8 then
  begin
    for i := 1 to Length(Content) do
    begin
      b := Ord(Content[i]);
      if (b >= $C0) and (b <= $FF) then
      begin
        Content := CP1251ToUTF8(Content);
        Exit(True);
      end;
    end;
  end;
end;

end.

