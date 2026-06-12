unit MobiToFb2Converter;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, LConvEncoding, base64;

function ConvertMobiToFb2(const MobiFileName, Fb2FileName: string): Boolean;

implementation

var
  LogFile: TextFile;

procedure Log(const Msg: string);
begin
  WriteLn(LogFile, Msg);
  Flush(LogFile);
end;

type
  TConvElemType = (cetTitle, cetSubtitle, cetParagraph, cetVerse, cetEmphasis,
    cetStrong, cetBlockquote, cetEmptyLine, cetImage);
  TConvElement = record
    ElemType: TConvElemType;
    Text: string;
    ImgSrc: string;
  end;
  TConvElementArray = array of TConvElement;

  TImageRecord = record
    Data: TBytes;
    MimeType: string;
    PDBRecIdx: Integer;
  end;
  TImageArray = array of TImageRecord;

  TBitReader = record
    Data: TBytes;
    BytePos: Integer;
    BitPos: Integer;
  end;

  THuffNode = packed record
    Left: Word;
    Right: Word;
  end;
  THuffTree = array of THuffNode;

function ReadBE16(const Buffer: TBytes; Offset: Integer): Word;
begin
  if Offset + 1 >= Length(Buffer) then Exit(0);
  Result := (Word(Buffer[Offset]) shl 8) or Word(Buffer[Offset + 1]);
end;

function ReadBE32(const Buffer: TBytes; Offset: Integer): LongWord;
begin
  if Offset + 3 >= Length(Buffer) then Exit(0);
  Result := (LongWord(Buffer[Offset]) shl 24) or
            (LongWord(Buffer[Offset + 1]) shl 16) or
            (LongWord(Buffer[Offset + 2]) shl 8) or
            LongWord(Buffer[Offset + 3]);
end;

function DecodeXMLEntities(const S: string): string;
begin
  Result := StringReplace(S, '&amp;', '&', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&#10;', #10, [rfReplaceAll]);
  Result := StringReplace(Result, '&#13;', #13, [rfReplaceAll]);
end;

procedure ConvertEncodingIfNeeded(var S: string; EncodingCode: LongWord);
begin
  if EncodingCode = 1251 then
    S := CP1251ToUTF8(S)
  else if EncodingCode = 1252 then
    S := CP1252ToUTF8(S);
end;

function EscapeXML(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function FindAttrValue(const Tag, AttrName: string): string;
var
  p, vs, ve: Integer;
  q: Char;
begin
  Result := '';
  p := Pos(AttrName + '=', Tag);
  if p = 0 then Exit;
  vs := p + Length(AttrName) + 1;
  if vs > Length(Tag) then Exit;
  q := Tag[vs];
  if not (q in ['"', '''']) then Exit;
  ve := Pos(q, Tag, vs + 1);
  if ve > vs then
    Result := Copy(Tag, vs + 1, ve - vs - 1);
end;

function DetectImageMimeType(const Data: TBytes): string;
begin
  Result := 'image/jpeg';
  if Length(Data) >= 3 then
  begin
    if (Data[0] = $FF) and (Data[1] = $D8) and (Data[2] = $FF) then
      Result := 'image/jpeg'
    else if (Data[0] = $89) and (Data[1] = $50) and (Data[2] = $4E) then
      Result := 'image/png'
    else if (Data[0] = $47) and (Data[1] = $49) and (Data[2] = $46) then
      Result := 'image/gif';
  end;
end;

function EncodeBase64Bytes(const Data: TBytes): string;
var
  S: AnsiString;
begin
  Result := '';
  if Length(Data) = 0 then Exit;
  SetLength(S, Length(Data));
  Move(Data[0], S[1], Length(Data));
  Result := EncodeStringBase64(S);
end;

function ExtractImageIndex(const Src: string): Integer;
var
  k: Integer;
  NumStr: string;
begin
  Result := -1;
  NumStr := '';
  for k := Length(Src) downto 1 do
  begin
    if Src[k] in ['0'..'9'] then
      NumStr := Src[k] + NumStr
    else if NumStr <> '' then
      Break;
  end;
  if NumStr <> '' then
    Result := StrToIntDef(NumStr, -1);
end;

function GetSizeOfTrailingDataEntry(const Data: TBytes): Integer;
var
  i, Num, DataLen: Integer;
  V: Byte;
begin
  Num := 0;
  DataLen := Length(Data);
  if DataLen < 4 then Exit(0);
  for i := DataLen - 4 to DataLen - 1 do
  begin
    V := Data[i];
    if (V and $80) <> 0 then
      Num := 0
    else
      Num := (Num shl 7) or (V and $7F);
  end;
  Result := Num;
end;

function TrimTrailingDataEntries(const Data: TBytes; Trailers, MultiByte: Integer): TBytes;
var
  i, Num, DataLen: Integer;
  LastByte: Byte;
begin
  Result := Copy(Data, 0, Length(Data));
  DataLen := Length(Result);
  for i := 1 to Trailers do
  begin
    if DataLen <= 0 then Break;
    Num := GetSizeOfTrailingDataEntry(Result);
    if (Num > 0) and (Num <= DataLen) then
    begin
      SetLength(Result, DataLen - Num);
      DataLen := Length(Result);
    end
    else
      Break;
  end;
  if (MultiByte <> 0) and (DataLen > 0) then
  begin
    LastByte := Result[DataLen - 1];
    Num := (LastByte and 3) + 1;
    if (Num > 0) and (Num <= DataLen) then
      SetLength(Result, DataLen - Num);
  end;
end;

procedure InitBitReader(var BR: TBitReader; const Data: TBytes);
begin
  BR.Data := Data;
  BR.BytePos := 0;
  BR.BitPos := 7;
end;

function ReadBit(var BR: TBitReader): Integer;
begin
  Result := 0;
  if BR.BytePos < Length(BR.Data) then
  begin
    Result := (BR.Data[BR.BytePos] shr BR.BitPos) and 1;
    Dec(BR.BitPos);
    if BR.BitPos < 0 then
    begin
      BR.BitPos := 7;
      Inc(BR.BytePos);
    end;
  end;
end;

function BitsAvailable(const BR: TBitReader): Boolean;
begin
  Result := BR.BytePos < Length(BR.Data);
end;

procedure DoDecompressHuff(const Compressed: TBytes; const Tree: THuffTree;
  const CDICData: TBytes; CDICEntryCount, CDICBits: LongWord;
  var Output: TBytes; var OutPos: Integer; MaxDepth: LongWord);
var
  BR: TBitReader;
  NodeIdx: Integer;
  Bit: Integer;
  Child: Word;
  DictIdx: Integer;
  Ptr: LongWord;
  DictOff, DictLen: Integer;
  DictEntry: TBytes;
begin
  if Length(Tree) = 0 then Exit;
  InitBitReader(BR, Compressed);

  while BitsAvailable(BR) do
  begin
    NodeIdx := 0;
    while NodeIdx < Length(Tree) do
    begin
      Bit := ReadBit(BR);
      if Bit = 0 then
        Child := Tree[NodeIdx].Left
      else
        Child := Tree[NodeIdx].Right;

      if (Child and $8000) <> 0 then
      begin
        if (Child and 1) <> 0 then
        begin
          DictIdx := Child shr 1;
          if (CDICData <> nil) and (LongWord(DictIdx) < CDICEntryCount) and (MaxDepth > 0) then
          begin
            Ptr := ReadBE32(CDICData, 8 + DictIdx * 4);
            DictOff := Ptr shr CDICBits;
            DictLen := Ptr and ((1 shl CDICBits) - 1);
            if (8 + CDICEntryCount * 4 + DictOff + DictLen) <= LongWord(Length(CDICData)) then
            begin
              SetLength(DictEntry, DictLen);
              Move(CDICData[8 + CDICEntryCount * 4 + DictOff], DictEntry[0], DictLen);
              DoDecompressHuff(DictEntry, Tree, CDICData, CDICEntryCount, CDICBits,
                Output, OutPos, MaxDepth - 1);
            end;
          end;
        end
        else
        begin
          if OutPos >= Length(Output) then
            SetLength(Output, Length(Output) * 2 + 256);
          Output[OutPos] := (Child shr 1) and $FF;
          Inc(OutPos);
        end;
        Break;
      end
      else
        NodeIdx := Child;
    end;
  end;
end;

function DecompressHuffCDIC(const Compressed: TBytes; const Tree: THuffTree;
  const CDICData: TBytes; CDICEntryCount, CDICBits: LongWord): string;
var
  Output: TBytes;
  OutPos: Integer;
begin
  Result := '';
  if (Length(Compressed) = 0) or (Length(Tree) = 0) then Exit;
  SetLength(Output, Length(Compressed) * 2);
  OutPos := 0;
  DoDecompressHuff(Compressed, Tree, CDICData, CDICEntryCount, CDICBits, Output, OutPos, 10);
  SetLength(Output, OutPos);
  if OutPos > 0 then
    SetString(Result, PAnsiChar(@Output[0]), OutPos);
end;

function DecompressPalmDoc(const Compressed: TBytes): string;
var
  i, Len: Integer;
  C, C2, M, N: Integer;
  OutBuf: TBytes;
  OutPos, OutSize: Integer;
  J: Integer;
begin
  Result := '';
  Len := Length(Compressed);
  if Len = 0 then Exit;
  OutSize := Len * 4;
  if OutSize < 4096 then OutSize := 4096;
  SetLength(OutBuf, OutSize);
  OutPos := 0;
  i := 0;

  while i < Len do
  begin
    C := Compressed[i];
    Inc(i);
    if (C >= 1) and (C <= 8) then
    begin
      while (C > 0) and (i < Len) do
      begin
        if OutPos >= OutSize then begin OutSize := OutSize * 2; SetLength(OutBuf, OutSize); end;
        OutBuf[OutPos] := Compressed[i];
        Inc(OutPos); Inc(i); Dec(C);
      end;
    end
    else if C < 128 then
    begin
      if OutPos >= OutSize then begin OutSize := OutSize * 2; SetLength(OutBuf, OutSize); end;
      OutBuf[OutPos] := C;
      Inc(OutPos);
    end
    else if C >= 192 then
    begin
      if OutPos >= OutSize then begin OutSize := OutSize * 2; SetLength(OutBuf, OutSize); end;
      OutBuf[OutPos] := 32;
      Inc(OutPos);
      if OutPos >= OutSize then begin OutSize := OutSize * 2; SetLength(OutBuf, OutSize); end;
      OutBuf[OutPos] := C xor 128;
      Inc(OutPos);
    end
    else
    begin
      if i < Len then
      begin
        C2 := Compressed[i];
        Inc(i);
        M := ((C and $7F) shl 5) or (C2 shr 3);
        N := (C2 and 7) + 3;
        if M > 0 then
        begin
          for J := 1 to N do
          begin
            if OutPos >= OutSize then begin OutSize := OutSize * 2; SetLength(OutBuf, OutSize); end;
            if OutPos - M >= 0 then
              OutBuf[OutPos] := OutBuf[OutPos - M]
            else
              OutBuf[OutPos] := 0;
            Inc(OutPos);
          end;
        end;
      end;
    end;
  end;

  SetLength(OutBuf, OutPos);
  if OutPos > 0 then
    SetString(Result, PAnsiChar(@OutBuf[0]), OutPos);
end;

function ParseXHTMLToElements(const Content: string): TConvElementArray;
var
  i, j, k: Integer;
  Tag, TagName, TextContent, AttrVal: string;
  InBody, InTextBlock: Boolean;
  CurrentElem: TConvElement;
  CurrentType: TConvElemType;
  ExpectChapterTitle: Boolean;
  TagCount: Integer;
begin
  SetLength(Result, 0);
  InBody := False;
  InTextBlock := False;
  ExpectChapterTitle := False;
  CurrentType := cetParagraph;
  CurrentElem.ElemType := cetParagraph;
  CurrentElem.Text := '';
  TagCount := 0;

  i := Pos('<body', Content);
  Log('Parser: <body> at pos=' + IntToStr(i));
  if i = 0 then
  begin
    i := Pos('<section', Content);
    Log('Parser: <section> at pos=' + IntToStr(i));
  end;
  if i = 0 then
  begin
    i := Pos('<main', Content);
    Log('Parser: <main> at pos=' + IntToStr(i));
  end;

  if i > 1 then
  begin
    i := Pos('>', Content, i) + 1;
    if i = 1 then i := 1;
  end
  else
    i := 1;

  InBody := True;
  Log('Parser: starting at pos=' + IntToStr(i) + ', content length=' + IntToStr(Length(Content)));
  Log('Parser: first 100 chars from start: ' + Copy(Content, i, 100));

  while InBody and (i <= Length(Content)) do
  begin
    if Content[i] = '<' then
    begin
      j := Pos('>', Content, i);
      if j = 0 then Break;
      Tag := Trim(Copy(Content, i+1, j-i-1));
      Inc(TagCount);
      if TagCount <= 10 then
        Log('Parser: tag #' + IntToStr(TagCount) + ' at ' + IntToStr(i) + ': "' + Copy(Tag, 1, 80) + '"');
      if (TagCount mod 1000) = 0 then
        Log('Parser: tag #' + IntToStr(TagCount) + ' at pos=' + IntToStr(i));

      if Pos('/', Tag) = 1 then
      begin
        TagName := Trim(Copy(Tag, 2, Length(Tag)-1));
        if InTextBlock and ((TagName = 'p') or (TagName = 'div') or (TagName = 'section') or
          (TagName = 'article') or (TagName = 'main') or (TagName = 'blockquote') or
          (TagName = 'h1') or (TagName = 'h2') or (TagName = 'h3') or
          (TagName = 'h4') or (TagName = 'h5') or (TagName = 'h6') or
          (TagName = 'poem') or (TagName = 'stanza')) then
        begin
          if Trim(CurrentElem.Text) <> '' then
          begin
            CurrentElem.Text := Trim(CurrentElem.Text);
            SetLength(Result, Length(Result)+1);
            Result[High(Result)] := CurrentElem;
          end;
          InTextBlock := False;
          CurrentElem.ElemType := cetParagraph;
          CurrentElem.Text := '';
          CurrentType := cetParagraph;
        end;
        if (TagName = 'em') or (TagName = 'i') or (TagName = 'strong') or (TagName = 'b') then
          CurrentType := cetParagraph;
      end
      else
      begin
        TagName := '';
        k := 1;
        while (k <= Length(Tag)) and not (Tag[k] in [' ', '/', '>']) do
        begin
          TagName := TagName + Tag[k];
          Inc(k);
        end;
        TagName := LowerCase(TagName);
        case TagName of
          'h1', 'h2', 'h3', 'h4', 'h5', 'h6':
          begin
            if InTextBlock and (Trim(CurrentElem.Text) <> '') then
            begin
              CurrentElem.Text := Trim(CurrentElem.Text);
              SetLength(Result, Length(Result)+1);
              Result[High(Result)] := CurrentElem;
            end;
            InTextBlock := True;
            CurrentElem.ElemType := cetTitle;
            CurrentElem.Text := '';
            ExpectChapterTitle := False;
          end;
          'mbp:pagebreak', 'pagebreak', 'svg:pagebreak':
          begin
            if InTextBlock and (Trim(CurrentElem.Text) <> '') then
            begin
              CurrentElem.Text := Trim(CurrentElem.Text);
              SetLength(Result, Length(Result)+1);
              Result[High(Result)] := CurrentElem;
            end;
            InTextBlock := False;
            ExpectChapterTitle := True;
          end;
          'p', 'div', 'li', 'td', 'th':
          begin
          end;
          'subtitle':
          begin
            CurrentElem.ElemType := cetSubtitle;
            InTextBlock := True;
          end;
          'poem', 'stanza', 'v':
          begin
            CurrentElem.ElemType := cetVerse;
            InTextBlock := True;
          end;
          'blockquote', 'cite':
          begin
            CurrentElem.ElemType := cetBlockquote;
            InTextBlock := True;
          end;
          'br', 'empty-line':
          begin
            SetLength(Result, Length(Result)+1);
            Result[High(Result)].ElemType := cetEmptyLine;
            Result[High(Result)].Text := '';
          end;
          'img', 'svg:img':
          begin
            if InTextBlock and (Trim(CurrentElem.Text) <> '') then
            begin
              CurrentElem.Text := Trim(CurrentElem.Text);
              SetLength(Result, Length(Result)+1);
              Result[High(Result)] := CurrentElem;
            end;
            InTextBlock := False;
            CurrentElem.ElemType := cetParagraph;
            CurrentElem.Text := '';
            AttrVal := FindAttrValue(Tag, 'src');
            Log('IMG: src="' + AttrVal + '" idx=' + IntToStr(ExtractImageIndex(AttrVal)));
            if AttrVal <> '' then
            begin
              SetLength(Result, Length(Result)+1);
              Result[High(Result)].ElemType := cetImage;
              Result[High(Result)].ImgSrc := AttrVal;
              Result[High(Result)].Text := '';
            end;
          end;
          'em', 'i', 'emphasis': CurrentType := cetEmphasis;
          'strong', 'b': CurrentType := cetStrong;
        end;
      end;
      i := j + 1;
    end
    else
    begin
      j := i;
      while (j <= Length(Content)) and (Content[j] <> '<') do Inc(j);
      TextContent := DecodeXMLEntities(Copy(Content, i, j-i));
      TextContent := StringReplace(TextContent, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
      TextContent := StringReplace(TextContent, #194#160, ' ', [rfReplaceAll]);
      TextContent := StringReplace(TextContent, #160, ' ', [rfReplaceAll]);
      TextContent := StringReplace(TextContent, #13#10, ' ', [rfReplaceAll]);
      TextContent := StringReplace(TextContent, #10, ' ', [rfReplaceAll]);
      TextContent := StringReplace(TextContent, #13, ' ', [rfReplaceAll]);
      TextContent := StringReplace(TextContent, #9, ' ', [rfReplaceAll]);
      while Pos('  ', TextContent) > 0 do
        TextContent := StringReplace(TextContent, '  ', ' ', [rfReplaceAll]);
      TextContent := Trim(TextContent);
      if TextContent <> '' then
      begin
        if not InTextBlock then
        begin
          if ExpectChapterTitle then
          begin
            CurrentElem.ElemType := cetTitle;
            ExpectChapterTitle := False;
          end
          else
            CurrentElem.ElemType := cetParagraph;
          CurrentElem.Text := '';
          InTextBlock := True;
        end;

        if CurrentElem.ElemType <> cetTitle then
        begin
          case CurrentType of
            cetEmphasis: CurrentElem.ElemType := cetEmphasis;
            cetStrong: CurrentElem.ElemType := cetStrong;
          end;
        end;

        CurrentElem.Text := CurrentElem.Text + TextContent + ' ';
      end;
      i := j;
    end;
  end;

  if InTextBlock and (Trim(CurrentElem.Text) <> '') then
  begin
    CurrentElem.Text := Trim(CurrentElem.Text);
    SetLength(Result, Length(Result)+1);
    Result[High(Result)] := CurrentElem;
  end;
  Log('Parser: done, total tags=' + IntToStr(TagCount) + ', elements=' + IntToStr(Length(Result)));
end;

function ConvertMobiToFb2(const MobiFileName, Fb2FileName: string): Boolean;
var
  FS: TFileStream;
  PDBHeader: TBytes;
  NumRecords, i, j: Integer;
  Rec0Offset, HeaderLen, TextEncoding, EXTHFlags: LongWord;
  Record0: TBytes;
  MobiHeaderOffset: Integer;
  EXTHCount, PosEXTH, RecType, RecLen: LongWord;
  Title, Author: string;
  FullHTML, Decompressed: string;
  TrimmedData: TBytes;
  Elements: TConvElementArray;
  ElemIdx: Integer;
  Elem: TConvElement;
  Compression: Word;
  TextRecordCount: Word;
  TrailDataFlags: Word;
  MultiByte, Trailers: Integer;
  TempFlags: LongWord;
  InSection: Boolean;
  HuffRecordOffset, HuffRecordCount: LongWord;
  HuffTree: THuffTree;
  CDICData: TBytes;
  CDICEntryCount, CDICBits: LongWord;
  HasHuffCDIC: Boolean;
  RawRecord: TBytes;
  IsKF8: Boolean;
  KF8Start: Int64;
  KF8PDBHeader: TBytes;
  KF8NumRecords: Integer;
  KF8Record0: TBytes;
  KF8Compression: Word;
  KF8TextCount: Word;
  KF8Enc: LongWord;
  KF8MultiByte, KF8Trailers: Integer;
  KF8HasHuff: Boolean;
  KF8HuffOffset, KF8HuffCount: LongWord;
  KF8HuffTree: THuffTree;
  KF8CDIC: TBytes;
  KF8CDICCount, KF8CDICBits: LongWord;
  KF8HLen: LongWord;
  RecSize: Integer;
  FirstBytes: string;
  Images: TImageArray;
  FirstImageRecord: LongWord;
  ImgIdx: Integer;
  OrigMobiOff: Integer;

  function ReadRecord(const APDB: TBytes; AIdx, ANum: Integer; ABase: Int64): TBytes;
  var
    S, E: Int64;
  begin
    Result := nil;
    if (AIdx < 0) or (AIdx >= ANum) then Exit;
    S := ABase + Int64(ReadBE32(APDB, 78 + AIdx * 8));
    if AIdx < ANum - 1 then
      E := ABase + Int64(ReadBE32(APDB, 78 + (AIdx + 1) * 8))
    else
      E := FS.Size;
    if E <= S then Exit;
    RecSize := Integer(E - S);
    SetLength(Result, RecSize);
    FS.Seek(S, soBeginning);
    FS.ReadBuffer(Result[0], RecSize);
  end;

  function HexDump(const Data: TBytes; MaxLen: Integer): string;
  var
    k: Integer;
  begin
    Result := '';
    for k := 0 to Min(MaxLen - 1, Length(Data) - 1) do
      Result := Result + IntToHex(Data[k], 2) + ' ';
    Result := Trim(Result);
  end;

  function FindMobiInRecord(const R: TBytes): Integer;
  var
    k: Integer;
  begin
    Result := -1;
    for k := 0 to Min(255, Length(R) - 4) do
      if (R[k] = 77) and (R[k+1] = 79) and (R[k+2] = 66) and (R[k+3] = 73) then
        Exit(k);
  end;

  procedure ParseMOBIHeader(const R: TBytes; MobiOff: Integer;
    out ACompression: Word; out ATextCount: Word; out AEnc: LongWord;
    out AMultiByte, ATrailers: Integer; out AHuffOff, AHuffCnt: LongWord;
    out AHasHuff: Boolean; out AHLen: LongWord);
  var
    TmpF: LongWord;
    TDF: Word;
  begin
    ACompression := ReadBE16(R, 0);
    ATextCount := ReadBE16(R, 8);
    AHLen := ReadBE32(R, MobiOff + 4);
    AEnc := ReadBE32(R, MobiOff + 12);
    if AEnc = $FFFFFFFF then AEnc := 65001;

    AMultiByte := 0;
    ATrailers := 0;
    if AHLen >= $E4 then
    begin
      if MobiOff + 243 <= Length(R) then
      begin
        TDF := ReadBE16(R, MobiOff + 242);
        AMultiByte := TDF and 1;
        TmpF := TDF;
        while TmpF > 1 do
        begin
          if (TmpF and 2) <> 0 then Inc(ATrailers);
          TmpF := TmpF shr 1;
        end;
      end;
    end;

    AHuffOff := 0;
    AHuffCnt := 0;
    AHasHuff := False;
    if (ACompression = 17480) and (AHLen >= 104) and (MobiOff + 103 <= Length(R)) then
    begin
      AHuffOff := ReadBE32(R, MobiOff + 96);
      AHuffCnt := ReadBE32(R, MobiOff + 100);
      AHasHuff := (AHuffOff > 0) and (AHuffCnt > 0);
    end;

    if not (ACompression in [1, 2, 17480]) then
    begin
      Log('  WARN: unknown compression ' + IntToStr(ACompression) + ', fallback to 1');
      ACompression := 1;
    end;
    if (ATextCount = 0) or (ATextCount > 10000) then ATextCount := 0;
  end;

  procedure LoadHuffCDIC(ARootRec: Integer; ACount: LongWord;
    const AName: string; const APDB: TBytes; ANum: Integer; ABase: Int64;
    out ATree: THuffTree; out ACDIC: TBytes; out AEntries, ABits: LongWord);
  var
    k: Integer;
    Rec: TBytes;
  begin
    SetLength(ATree, 0);
    ACDIC := nil;
    AEntries := 0;
    ABits := 9;

    Log(AName + ': loading HUFF from record ' + IntToStr(ARootRec) + ', CDIC count=' + IntToStr(ACount));

    Rec := ReadRecord(APDB, ARootRec, ANum, ABase);
    if (Rec <> nil) and (Length(Rec) > 8) then
    begin
      SetLength(ATree, (Length(Rec) - 8) div 4);
      for k := 0 to High(ATree) do
      begin
        ATree[k].Left := ReadBE16(Rec, 8 + k * 4);
        ATree[k].Right := ReadBE16(Rec, 8 + k * 4 + 2);
      end;
      Log(AName + ': HUFF tree nodes=' + IntToStr(Length(ATree)));
    end
    else
      Log(AName + ': HUFF record is nil or too small');

    for k := ARootRec + 1 to ARootRec + Integer(ACount) - 1 do
    begin
      Rec := ReadRecord(APDB, k, ANum, ABase);
      if Rec <> nil then
      begin
        if ACDIC = nil then
          ACDIC := Copy(Rec)
        else
        begin
          SetLength(ACDIC, Length(ACDIC) + Length(Rec));
          Move(Rec[0], ACDIC[Length(ACDIC) - Length(Rec)], Length(Rec));
        end;
      end;
    end;

    if (ACDIC <> nil) and (Length(ACDIC) >= 8) then
    begin
      AEntries := ReadBE32(ACDIC, 0);
      ABits := ReadBE32(ACDIC, 4);
      if ABits = 0 then ABits := 9;
      Log(AName + ': CDIC entries=' + IntToStr(AEntries) + ', bits=' + IntToStr(ABits) + ', data=' + IntToStr(Length(ACDIC)) + ' bytes');
    end
    else
      Log(AName + ': CDIC data is nil or too small');
  end;

  function DecompressRecord(const Raw: TBytes; AComp: Word;
    AMB, ATr: Integer; AHasHuff: Boolean;
    const ATree: THuffTree; const ACDIC: TBytes; AEntries, ABits: LongWord): string;
  var
    TD: TBytes;
  begin
    Result := '';
    if (AMB <> 0) or (ATr > 0) then
      TD := TrimTrailingDataEntries(Raw, ATr, AMB)
    else
      TD := Raw;

    if AComp = 2 then
      Result := DecompressPalmDoc(TD)
    else if AComp = 1 then
    begin
      if Length(TD) > 0 then
        SetString(Result, PAnsiChar(@TD[0]), Length(TD));
    end
    else if (AComp = 17480) and AHasHuff then
      Result := DecompressHuffCDIC(TD, ATree, ACDIC, AEntries, ABits);
  end;

  procedure WriteStr(const S: string; F: TFileStream);
  begin
    if Length(S) > 0 then
      F.WriteBuffer(S[1], Length(S));
  end;

begin
  Result := False;

  AssignFile(LogFile, ChangeFileExt(MobiFileName, '.log'));
  Rewrite(LogFile);
  try
    Log('=== ConvertMobiToFb2 ===');
    Log('Input:  ' + MobiFileName);
    Log('Output: ' + Fb2FileName);
    Log('File exists: ' + BoolToStr(SysUtils.FileExists(MobiFileName), True));

    if not SysUtils.FileExists(MobiFileName) then
    begin
      Log('ERROR: file not found');
      Exit;
    end;

    FS := TFileStream.Create(MobiFileName, fmOpenRead or fmShareDenyWrite);
    try
      Log('--- PDB Header ---');
      SetLength(PDBHeader, 78);
      FS.ReadBuffer(PDBHeader[0], 78);
      NumRecords := ReadBE16(PDBHeader, 76);
      Log('NumRecords=' + IntToStr(NumRecords));
      if NumRecords < 2 then
      begin
        Log('ERROR: NumRecords < 2, abort');
        Exit;
      end;

      SetLength(PDBHeader, 78 + NumRecords * 8);
      FS.Seek(0, soBeginning);
      FS.ReadBuffer(PDBHeader[0], Length(PDBHeader));

      Rec0Offset := ReadBE32(PDBHeader, 78);
      Log('Rec0Offset=' + IntToStr(Rec0Offset));

      FS.Seek(Rec0Offset, soBeginning);
      RecSize := Min(4096, Integer(FS.Size - Rec0Offset));
      SetLength(Record0, RecSize);
      FS.ReadBuffer(Record0[0], RecSize);
      Log('Record0 read ' + IntToStr(RecSize) + ' bytes');
      Log('Record0 first 32 bytes: ' + HexDump(Record0, 32));

      MobiHeaderOffset := FindMobiInRecord(Record0);
      OrigMobiOff := MobiHeaderOffset;
      Log('MOBI header offset=' + IntToStr(MobiHeaderOffset));
      if MobiHeaderOffset = -1 then
      begin
        Log('ERROR: MOBI header not found in Record0, abort');
        Exit;
      end;

      HeaderLen := ReadBE32(Record0, MobiHeaderOffset + 4);
      TextEncoding := ReadBE32(Record0, MobiHeaderOffset + 12);
      if TextEncoding = $FFFFFFFF then TextEncoding := 65001;

      Log('HeaderLen=' + IntToStr(HeaderLen));
      Log('TextEncoding=' + IntToStr(TextEncoding));

      Compression := ReadBE16(Record0, 0);
      TextRecordCount := ReadBE16(Record0, 8);
      Log('PalmDoc compression=' + IntToStr(Compression));
      Log('PalmDoc textRecordCount=' + IntToStr(TextRecordCount));

      SetLength(Title, 32);
      Move(PDBHeader[0], Title[1], 32);
      Title := Trim(StringReplace(Title, #0, '', [rfReplaceAll]));
      if Title = '' then Title := ChangeFileExt(ExtractFileName(MobiFileName), '');
      Author := '';
      Log('Title (from PDB): "' + Title + '"');

      if HeaderLen >= 112 then
      begin
        if MobiHeaderOffset + 131 <= Length(Record0) then
        begin
          EXTHFlags := ReadBE32(Record0, MobiHeaderOffset + 128);
          Log('EXTHFlags=' + IntToHex(EXTHFlags, 8));
          if (EXTHFlags and $40) <> 0 then
          begin
            PosEXTH := MobiHeaderOffset + HeaderLen;
            if (PosEXTH + 12 <= Length(Record0)) and
               (Record0[PosEXTH] = 69) and (Record0[PosEXTH+1] = 88) and
               (Record0[PosEXTH+2] = 84) and (Record0[PosEXTH+3] = 72) then
            begin
              EXTHCount := ReadBE32(Record0, PosEXTH + 8);
              Log('EXTH records count=' + IntToStr(EXTHCount));
              PosEXTH := PosEXTH + 12;
              for i := 1 to EXTHCount do
              begin
                if PosEXTH + 8 > Length(Record0) then Break;
                RecType := ReadBE32(Record0, PosEXTH);
                RecLen := ReadBE32(Record0, PosEXTH + 4);
                if RecLen < 8 then Break;
                if PosEXTH + RecLen > Length(Record0) then Break;
                if (RecType = 503) and (Title = '') then
                begin
                  SetLength(Title, RecLen - 8);
                  if RecLen > 8 then Move(Record0[PosEXTH + 8], Title[1], RecLen - 8);
                  ConvertEncodingIfNeeded(Title, TextEncoding);
                end
                else if (RecType = 100) and (Author = '') then
                begin
                  SetLength(Author, RecLen - 8);
                  if RecLen > 8 then Move(Record0[PosEXTH + 8], Author[1], RecLen - 8);
                  ConvertEncodingIfNeeded(Author, TextEncoding);
                end;
                Inc(PosEXTH, RecLen);
              end;
            end
            else
              Log('EXTH header not found at expected position');
          end
          else
            Log('EXTH flag bit 0x40 not set');
        end;
      end
      else
        Log('HeaderLen < 112, skipping EXTH');

      Log('Title: "' + Title + '"');
      Log('Author: "' + Author + '"');

      Log('--- KF8 Detection ---');
      IsKF8 := False;
      KF8Start := 0;
      for i := 1 to NumRecords - 1 do
      begin
        RawRecord := ReadRecord(PDBHeader, i, NumRecords, 0);
        if RawRecord <> nil then
        begin
          Log('Record ' + IntToStr(i) + ': ' + IntToStr(Length(RawRecord)) + ' bytes, first 8: ' + HexDump(RawRecord, 8));
          if Length(RawRecord) >= 3 then
          begin
            if (RawRecord[0] = $E9) and (RawRecord[1] = $8E) and
               ((RawRecord[2] = $0A) or
                ((RawRecord[2] = $0D) and (Length(RawRecord) > 3) and (RawRecord[3] = $0A))) then
            begin
              if i + 1 <= NumRecords - 1 then
                KF8Start := Int64(ReadBE32(PDBHeader, 78 + (i + 1) * 8))
              else
                KF8Start := FS.Size;
              if (KF8Start < FS.Size - 78) then
              begin
                IsKF8 := True;
                Log('KF8 BOUNDARY found at record ' + IntToStr(i));
                Log('KF8Start=' + IntToStr(KF8Start));
                Break;
              end
              else
                Log('Record ' + IntToStr(i) + ' has boundary marker but no KF8 data after it');
            end;
          end;
        end
        else
          Log('Record ' + IntToStr(i) + ': nil');
      end;

      if not IsKF8 then
        Log('No KF8 boundary found, treating as old MOBI');

      FullHTML := '';

      if IsKF8 then
      begin
        Log('--- KF8 Section ---');
        Log('Seeking to KF8Start=' + IntToStr(KF8Start) + ', file size=' + IntToStr(FS.Size));

        if FS.Size - KF8Start < 78 then
        begin
          Log('ERROR: KF8 section too small (' + IntToStr(FS.Size - KF8Start) + ' bytes), abort');
          Exit;
        end;

        FS.Seek(KF8Start, soBeginning);
        SetLength(KF8PDBHeader, 78);
        FS.ReadBuffer(KF8PDBHeader[0], 78);
        Log('KF8 PDB header first 32 bytes: ' + HexDump(KF8PDBHeader, 32));

        KF8NumRecords := ReadBE16(KF8PDBHeader, 76);
        Log('KF8 NumRecords=' + IntToStr(KF8NumRecords));
        if KF8NumRecords < 1 then
        begin
          Log('ERROR: KF8 NumRecords < 1, abort');
          Exit;
        end;

        SetLength(KF8PDBHeader, 78 + KF8NumRecords * 8);
        FS.Seek(KF8Start, soBeginning);
        FS.ReadBuffer(KF8PDBHeader[0], Length(KF8PDBHeader));
        Log('KF8 PDB header fully read: ' + IntToStr(Length(KF8PDBHeader)) + ' bytes');

        KF8Record0 := ReadRecord(KF8PDBHeader, 0, KF8NumRecords, KF8Start);
        if KF8Record0 = nil then
        begin
          Log('ERROR: KF8 Record0 is nil, abort');
          Exit;
        end;
        Log('KF8 Record0: ' + IntToStr(Length(KF8Record0)) + ' bytes, first 32: ' + HexDump(KF8Record0, 32));

        MobiHeaderOffset := FindMobiInRecord(KF8Record0);
        Log('KF8 MOBI header offset=' + IntToStr(MobiHeaderOffset));
        if MobiHeaderOffset = -1 then
        begin
          Log('ERROR: MOBI header not found in KF8 Record0, abort');
          Exit;
        end;

        ParseMOBIHeader(KF8Record0, MobiHeaderOffset,
          KF8Compression, KF8TextCount, KF8Enc,
          KF8MultiByte, KF8Trailers, KF8HuffOffset, KF8HuffCount,
          KF8HasHuff, KF8HLen);

        Log('KF8 compression=' + IntToStr(KF8Compression));
        Log('KF8 textCount=' + IntToStr(KF8TextCount));
        Log('KF8 encoding=' + IntToStr(KF8Enc));
        Log('KF8 huffOffset=' + IntToStr(KF8HuffOffset) + ', huffCount=' + IntToStr(KF8HuffCount));
        Log('KF8 hasHuff=' + BoolToStr(KF8HasHuff, True));
        Log('KF8 headerLen=' + IntToStr(KF8HLen));
        Log('KF8 multiByte=' + IntToStr(KF8MultiByte) + ', trailers=' + IntToStr(KF8Trailers));

        TextEncoding := KF8Enc;

        if KF8TextCount = 0 then
        begin
          KF8TextCount := KF8NumRecords - 1;
          if KF8TextCount < 1 then KF8TextCount := 1;
          Log('KF8 textCount was 0, fallback to ' + IntToStr(KF8TextCount));
        end;

        SetLength(KF8HuffTree, 0);
        KF8CDIC := nil;
        KF8CDICCount := 0;
        KF8CDICBits := 9;

        if KF8HasHuff then
          LoadHuffCDIC(Integer(KF8HuffOffset), KF8HuffCount, 'KF8',
            KF8PDBHeader, KF8NumRecords, KF8Start,
            KF8HuffTree, KF8CDIC, KF8CDICCount, KF8CDICBits);

        Log('Reading ' + IntToStr(KF8TextCount) + ' KF8 text records...');
        for i := 1 to KF8TextCount do
        begin
          RawRecord := ReadRecord(KF8PDBHeader, i, KF8NumRecords, KF8Start);
          if RawRecord = nil then
          begin
            Log('  Record ' + IntToStr(i) + ': nil, skip');
            Continue;
          end;
          RecSize := Length(RawRecord);
          Decompressed := DecompressRecord(RawRecord, KF8Compression,
            KF8MultiByte, KF8Trailers, KF8HasHuff,
            KF8HuffTree, KF8CDIC, KF8CDICCount, KF8CDICBits);
          Log('  Record ' + IntToStr(i) + ': ' + IntToStr(RecSize) + ' -> ' + IntToStr(Length(Decompressed)) + ' bytes');
          FullHTML := FullHTML + Decompressed;
        end;
      end
      else
      begin
        Log('--- Old MOBI Section ---');
        ParseMOBIHeader(Record0, MobiHeaderOffset,
          Compression, TextRecordCount, TextEncoding,
          MultiByte, Trailers, HuffRecordOffset, HuffRecordCount,
          HasHuffCDIC, HeaderLen);

        Log('compression=' + IntToStr(Compression));
        Log('textCount=' + IntToStr(TextRecordCount));
        Log('encoding=' + IntToStr(TextEncoding));
        Log('huffOffset=' + IntToStr(HuffRecordOffset) + ', huffCount=' + IntToStr(HuffRecordCount));
        Log('hasHuff=' + BoolToStr(HasHuffCDIC, True));
        Log('multiByte=' + IntToStr(MultiByte) + ', trailers=' + IntToStr(Trailers));

        if TextRecordCount = 0 then
        begin
          TextRecordCount := NumRecords - 1;
          if TextRecordCount < 1 then TextRecordCount := 1;
          Log('textCount was 0, fallback to ' + IntToStr(TextRecordCount));
        end;

        SetLength(HuffTree, 0);
        CDICData := nil;
        CDICEntryCount := 0;
        CDICBits := 9;

        if HasHuffCDIC then
          LoadHuffCDIC(Integer(HuffRecordOffset), HuffRecordCount, 'OldMOBI',
            PDBHeader, NumRecords, 0,
            HuffTree, CDICData, CDICEntryCount, CDICBits);

        Log('Reading ' + IntToStr(TextRecordCount) + ' text records...');
        for i := 1 to TextRecordCount do
        begin
          RawRecord := ReadRecord(PDBHeader, i, NumRecords, 0);
          if RawRecord = nil then
          begin
            Log('  Record ' + IntToStr(i) + ': nil, skip');
            Continue;
          end;
          RecSize := Length(RawRecord);
          Decompressed := DecompressRecord(RawRecord, Compression,
            MultiByte, Trailers, HasHuffCDIC,
            HuffTree, CDICData, CDICEntryCount, CDICBits);
          Log('  Record ' + IntToStr(i) + ': ' + IntToStr(RecSize) + ' -> ' + IntToStr(Length(Decompressed)) + ' bytes');
          FullHTML := FullHTML + Decompressed;
        end;
      end;

      Log('--- HTML Result ---');
      Log('FullHTML length=' + IntToStr(Length(FullHTML)));
      if Length(FullHTML) > 0 then
      begin
        Log('First 200 chars: ' + Copy(FullHTML, 1, 200));
        ConvertEncodingIfNeeded(FullHTML, TextEncoding);
        Log('After encoding, length=' + IntToStr(Length(FullHTML)));
      end;

      if Length(FullHTML) = 0 then
      begin
        Log('ERROR: FullHTML is empty, abort');
        Exit;
      end;

      Log('--- Parse XHTML ---');
      Elements := ParseXHTMLToElements(FullHTML);
      Log('Elements parsed: ' + IntToStr(Length(Elements)));
      if Length(Elements) > 0 then
      begin
        Log('First element type=' + IntToStr(Ord(Elements[0].ElemType)) + ', text="' + Copy(Elements[0].Text, 1, 80) + '"');
        Log('Last  element type=' + IntToStr(Ord(Elements[High(Elements)].ElemType)) + ', text="' + Copy(Elements[High(Elements)].Text, 1, 80) + '"');
      end;

      if Length(Elements) = 0 then
      begin
        Log('ERROR: no elements parsed, abort');
        Exit;
      end;

      Log('--- Read Images ---');
      SetLength(Images, 0);
      FirstImageRecord := 0;
      if (OrigMobiOff >= 0) and (OrigMobiOff + 95 <= Length(Record0)) then
        FirstImageRecord := ReadBE32(Record0, OrigMobiOff + 92);
      Log('FirstImageRecord=' + IntToStr(FirstImageRecord));

      if FirstImageRecord > 0 then
      begin
        for i := Integer(FirstImageRecord) to NumRecords - 1 do
        begin
          RawRecord := ReadRecord(PDBHeader, i, NumRecords, 0);
          if (RawRecord <> nil) and (Length(RawRecord) > 4) then
          begin
            if ((RawRecord[0] = $FF) and (RawRecord[1] = $D8) and (RawRecord[2] = $FF)) or
               ((RawRecord[0] = $89) and (RawRecord[1] = $50) and (RawRecord[2] = $4E)) or
               ((RawRecord[0] = $47) and (RawRecord[1] = $49) and (RawRecord[2] = $46)) then
            begin
              SetLength(Images, Length(Images) + 1);
              Images[High(Images)].Data := RawRecord;
              Images[High(Images)].MimeType := DetectImageMimeType(RawRecord);
              Images[High(Images)].PDBRecIdx := i;
              Log('  Image ' + IntToStr(Length(Images)) + ': rec=' + IntToStr(i) + ', ' +
                IntToStr(Length(RawRecord)) + ' bytes, ' + Images[High(Images)].MimeType);
            end
            else
              Log('  Skip rec=' + IntToStr(i) + ': not an image (' + IntToStr(Length(RawRecord)) + ' bytes)');
          end;
        end;
      end;
      Log('Total images: ' + IntToStr(Length(Images)));

      FS.Free;
      FS := nil;

      Log('--- Write FB2 ---');
      FS := TFileStream.Create(Fb2FileName, fmCreate);
      try
        WriteStr('<?xml version="1.0" encoding="UTF-8"?>'#10, FS);
        WriteStr('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">'#10, FS);
        WriteStr('  <description>'#10, FS);
        WriteStr('    <title-info>'#10, FS);
        if Title <> '' then
          WriteStr('      <book-title>' + EscapeXML(Title) + '</book-title>'#10, FS);
        if Author <> '' then
        begin
          WriteStr('      <author>'#10, FS);
          WriteStr('        <first-name>' + EscapeXML(Author) + '</first-name>'#10, FS);
          WriteStr('      </author>'#10, FS);
        end;
        WriteStr('    </title-info>'#10, FS);
        WriteStr('  </description>'#10, FS);
        WriteStr('  <body>'#10, FS);

        InSection := False;
        for ElemIdx := 0 to High(Elements) do
        begin
          Elem := Elements[ElemIdx];
          if Elem.ElemType = cetTitle then
          begin
            if InSection then WriteStr('    </section>'#10, FS);
            WriteStr('    <section>'#10, FS);
            WriteStr('      <title>'#10, FS);
            if Trim(Elem.Text) <> '' then
              WriteStr('        <p>' + EscapeXML(Elem.Text) + '</p>'#10, FS)
            else
              WriteStr('        <p> </p>'#10, FS);
            WriteStr('      </title>'#10, FS);
            InSection := True;
          end
          else
          begin
            if not InSection then
            begin
              WriteStr('    <section>'#10, FS);
              InSection := True;
            end;
            case Elem.ElemType of
              cetSubtitle: WriteStr('      <subtitle>' + EscapeXML(Elem.Text) + '</subtitle>'#10, FS);
              cetParagraph: WriteStr('      <p>' + EscapeXML(Elem.Text) + '</p>'#10, FS);
              cetVerse:
              begin
                WriteStr('      <poem>'#10, FS);
                WriteStr('        <stanza>'#10, FS);
                WriteStr('          <v>' + EscapeXML(Elem.Text) + '</v>'#10, FS);
                WriteStr('        </stanza>'#10, FS);
                WriteStr('      </poem>'#10, FS);
              end;
              cetEmphasis: WriteStr('      <p><emphasis>' + EscapeXML(Elem.Text) + '</emphasis></p>'#10, FS);
              cetStrong: WriteStr('      <p><strong>' + EscapeXML(Elem.Text) + '</strong></p>'#10, FS);
              cetBlockquote: WriteStr('      <cite>' + EscapeXML(Elem.Text) + '</cite>'#10, FS);
              cetEmptyLine: WriteStr('      <empty-line/>'#10, FS);
              cetImage:
              begin
                ImgIdx := ExtractImageIndex(Elem.ImgSrc);
                if (ImgIdx >= 1) and (ImgIdx <= Length(Images)) then
                  WriteStr('      <image l:href="#img' + IntToStr(ImgIdx) + '"/>'#10, FS)
                else
                  WriteStr('      <image l:href="' + EscapeXML(Elem.ImgSrc) + '"/>'#10, FS);
              end;
            end;
          end;
        end;

        if InSection then WriteStr('    </section>'#10, FS);
        WriteStr('  </body>'#10, FS);

        for ImgIdx := 0 to High(Images) do
        begin
          WriteStr('  <binary id="img' + IntToStr(ImgIdx + 1) + '" content-type="' +
            Images[ImgIdx].MimeType + '">'#10, FS);
          WriteStr(EncodeBase64Bytes(Images[ImgIdx].Data) + #10, FS);
          WriteStr('  </binary>'#10, FS);
        end;

        WriteStr('</FictionBook>'#10, FS);
        Result := True;
        Log('FB2 written successfully, size=' + IntToStr(FS.Size));
      finally
        FS.Free;
        FS := nil;
      end;

    except
      on E: Exception do
      begin
        Log('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
        if FS <> nil then
        begin
          FS.Free;
          FS := nil;
        end;
        Result := False;
      end;
    end;

  finally
    Log('=== Done (Result=' + BoolToStr(Result, True) + ') ===');
    CloseFile(LogFile);
  end;
end;

end.
