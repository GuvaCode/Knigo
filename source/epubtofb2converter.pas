unit EpubToFb2Converter;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, LConvEncoding, unzip, zipUtils, ReaderTools;

function ConvertEpubToFb2(const EpubFileName, Fb2FileName: string): Boolean;

implementation

type
  TConvElemType = (cetTitle, cetSubtitle, cetParagraph, cetVerse, cetEmphasis, cetStrong, cetBlockquote, cetImage, cetEmptyLine);

  TConvElement = record
    ElemType: TConvElemType;
    Text: string;
    ImgSrc: string;
  end;

  TConvElementArray = array of TConvElement;

  TConvImage = record
    Id: string;
    ContentType: string;
    Base64Data: string;
  end;

  TConvImageArray = array of TConvImage;

  TChapterInfo = record
    Src: string;
    Title: string;
  end;
  TChapterArray = array of TChapterInfo;

// === Вспомогательные функции ===

function NormalizeArchivePath(const Path: string): string;
begin
  Result := StringReplace(Path, '\', '/', [rfReplaceAll]);
  // Удаляем ведущие слеши, которые ломают поиск в ZIP
  while (Length(Result) > 0) and (Result[1] = '/') do Delete(Result, 1, 1);
  while (Length(Result) > 2) and (Result[1] = '.') and (Result[2] = '/') do
    Delete(Result, 1, 2);
  if (Length(Result) > 1) and (Result[Length(Result)] = '/') then
    Delete(Result, Length(Result), 1);
end;

function CombineEPUBPath(const BasePath, RelativePath: string): string;
var
  CleanBase, CleanRel: string;
begin
  CleanBase := NormalizeArchivePath(BasePath);
  CleanRel := NormalizeArchivePath(RelativePath);
  if (CleanRel <> '') and (Pos(CleanBase + '/', CleanRel) = 1) then Exit(CleanRel);
  if (CleanBase = '') or (CleanBase = '.') then Exit(CleanRel);
  if (CleanBase[Length(CleanBase)] <> '/') and (CleanRel <> '') and (CleanRel[1] <> '/') then
    Result := CleanBase + '/' + CleanRel
  else
    Result := CleanBase + CleanRel;
end;

function FindAttrValue(const Tag, AttrName: string): string;
var
  AttrStart, ValStart, ValEnd: Integer;
  Quote: Char;
  SearchName: string;
begin
  Result := '';
  SearchName := AttrName + '=';
  AttrStart := Pos(SearchName, Tag);
  if AttrStart = 0 then
  begin
    SearchName := AttrName + ' =';
    AttrStart := Pos(SearchName, Tag);
  end;
  if AttrStart = 0 then Exit;

  ValStart := AttrStart + Length(SearchName);
  while (ValStart <= Length(Tag)) and (Tag[ValStart] = ' ') do Inc(ValStart);
  if ValStart > Length(Tag) then Exit;
  Quote := Tag[ValStart];
  if not (Quote in ['"', '''']) then Exit;

  ValEnd := Pos(Quote, Tag, ValStart + 1);
  if ValEnd > ValStart then
    Result := Copy(Tag, ValStart + 1, ValEnd - ValStart - 1);
end;

// === Парсер toc.ncx ===

function ParseNcxToChapters(const NcxContent, BasePath: string): TChapterArray;
var
  i, j, k: Integer;
  Tag, Src, Title: string;
  InNavPoint: Boolean;
begin
  SetLength(Result, 0);
  InNavPoint := False;
  Src := '';
  Title := '';
  i := 1;
  while i <= Length(NcxContent) do
  begin
    if NcxContent[i] = '<' then
    begin
      j := Pos('>', NcxContent, i);
      if j = 0 then Break;
      Tag := Copy(NcxContent, i+1, j-i-1);

      if Pos('navPoint', Tag) > 0 then
      begin
        if Pos('/', Tag) = 1 then
        begin
          if (Src <> '') and (Title <> '') then
          begin
            SetLength(Result, Length(Result)+1);
            Result[High(Result)].Src := NormalizeArchivePath(CombineEPUBPath(BasePath, Src));
            Result[High(Result)].Title := Title;
          end;
          Src := '';
          Title := '';
          InNavPoint := False;
        end
        else
          InNavPoint := True;
      end;

      if InNavPoint then
      begin
        if Pos('content', Tag) > 0 then
        begin
          Src := FindAttrValue(Tag, 'src');
          if Src <> '' then
          begin
            k := Pos('#', Src);
            if k > 0 then Src := Copy(Src, 1, k-1);
          end;
        end;

        if Pos('navLabel', Tag) = 1 then
        begin
          k := Pos('<text>', NcxContent, j);
          if k > 0 then
          begin
            k := k + 6;
            j := Pos('</text>', NcxContent, k);
            if j > k then
              Title := Trim(Copy(NcxContent, k, j-k));
          end;
        end;
      end;
    end;
    Inc(i);
  end;
end;

function ReadZipFileBytes(Zip: Pointer; const Name: string): TBytes;
var
  FileInfo: unz_file_info;
  NameBuf: array[0..1024] of AnsiChar;
  ReadSize: Integer;
begin
  Result := nil;
  if Zip = nil then Exit;
  if unzLocateFile(unzFile(Zip), PAnsiChar(AnsiString(Name)), 2) <> UNZ_OK then Exit;
  if unzOpenCurrentFile(unzFile(Zip)) <> UNZ_OK then Exit;
  if unzGetCurrentFileInfo(unzFile(Zip), @FileInfo, @NameBuf[0], SizeOf(NameBuf)-1, nil, 0, nil, 0) <> UNZ_OK then
  begin
    unzCloseCurrentFile(unzFile(Zip));
    Exit;
  end;
  if FileInfo.uncompressed_size > 0 then
  begin
    SetLength(Result, FileInfo.uncompressed_size);
    ReadSize := unzReadCurrentFile(unzFile(Zip), @Result[0], FileInfo.uncompressed_size);
    if ReadSize < 0 then SetLength(Result, 0);
  end;
  unzCloseCurrentFile(unzFile(Zip));
end;

// ИСПРАВЛЕНИЕ: EPUB XHTML всегда в UTF-8. Копируем байты как есть, без конвертации.
function GetZipFileContent(Zip: Pointer; const Name: string): string;
var
  Data: TBytes;
begin
  Result := '';
  Data := ReadZipFileBytes(Zip, Name);
  if Length(Data) = 0 then Exit;

  if (Length(Data) >= 3) and (Data[0] = $EF) and (Data[1] = $BB) and (Data[2] = $BF) then
  begin
    SetLength(Result, Length(Data) - 3);
    if Length(Result) > 0 then Move(Data[3], Result[1], Length(Result));
  end
  else
  begin
    SetLength(Result, Length(Data));
    if Length(Data) > 0 then Move(Data[0], Result[1], Length(Data));
  end;
end;

// ИСПРАВЛЕНИЕ: Base64 с переносами строк по 76 символов (требование FB2)
function EncodeBase64Bytes(const Data: TBytes): string;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  LineWidth = 76;
var
  i, Len, Col: Integer;
  B1, B2, B3: Byte;
begin
  Result := '';
  Len := Length(Data);
  i := 0;
  Col := 0;
  while i < Len do
  begin
    B1 := Data[i]; Inc(i);
    B2 := 0; if i < Len then begin B2 := Data[i]; Inc(i); end;
    B3 := 0; if i < Len then begin B3 := Data[i]; Inc(i); end;

    Result := Result + Base64Chars[(B1 shr 2) + 1];
    Result := Result + Base64Chars[((B1 and 3) shl 4) or (B2 shr 4) + 1];
    Inc(Col, 2);

    if i - 1 < Len then
      Result := Result + Base64Chars[((B2 and 15) shl 2) or (B3 shr 6) + 1]
    else
      Result := Result + '=';
    Inc(Col);

    if i < Len then
      Result := Result + Base64Chars[(B3 and 63) + 1]
    else
      Result := Result + '=';
    Inc(Col);

    if Col >= LineWidth then
    begin
      Result := Result + #10;
      Col := 0;
    end;
  end;
  if (Length(Result) > 0) and (Result[Length(Result)] <> #10) then
    Result := Result + #10;
end;

function EscapeXML(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function GetImageContentType(const Ext: string): string;
var
  E: string;
begin
  E := LowerCase(Ext);
  if (E = '.jpg') or (E = '.jpeg') then Result := 'image/jpeg'
  else if E = '.png' then Result := 'image/png'
  else if E = '.gif' then Result := 'image/gif'
  else if E = '.svg' then Result := 'image/svg+xml'
  else Result := 'image/jpeg';
end;

// === Парсер XHTML ===

function ParseXHTMLToElements(const Content: string): TConvElementArray;
var
  i, j, k: Integer;
  Tag, TagName, AttrVal, TextContent: string;
  InBody, InTextBlock: Boolean;
  CurrentElem: TConvElement;
  CurrentType: TConvElemType;

  function CollapseSpaces(const S: string): string;
  var
    ci: Integer;
    LastWasSpace: Boolean;
  begin
    Result := '';
    LastWasSpace := False;
    for ci := 1 to Length(S) do
    begin
      if S[ci] in [' ', #9, #10, #13] then
      begin
        if not LastWasSpace then
        begin
          Result := Result + ' ';
          LastWasSpace := True;
        end;
      end
      else
      begin
        Result := Result + S[ci];
        LastWasSpace := False;
      end;
    end;
  end;

begin
  SetLength(Result, 0);
  InBody := False;
  InTextBlock := False;
  CurrentType := cetParagraph;
  CurrentElem.ElemType := cetParagraph;
  CurrentElem.Text := '';
  CurrentElem.ImgSrc := '';

  i := Pos('<body', Content);
  if i = 0 then i := Pos('<section', Content);
  if i = 0 then i := Pos('<main', Content);
  if i = 0 then Exit;

  i := Pos('>', Content, i) + 1;
  InBody := True;

  while InBody and (i <= Length(Content)) do
  begin
    if Content[i] = '<' then
    begin
      j := Pos('>', Content, i);
      if j = 0 then Break;
      Tag := Trim(Copy(Content, i+1, j-i-1));

      if Pos('/', Tag) = 1 then
      begin
        TagName := Trim(Copy(Tag, 2, Length(Tag)-1));
        if TagName = 'body' then InBody := False;

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
            CurrentElem.ElemType := cetTitle;
            InTextBlock := True;
          end;
          'p', 'div', 'li', 'td', 'th':
          begin
            CurrentElem.ElemType := cetParagraph;
            InTextBlock := True;
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
          'blockquote':
          begin
            CurrentElem.ElemType := cetBlockquote;
            InTextBlock := True;
          end;
          'img', 'image':
          begin
            AttrVal := FindAttrValue(Tag, 'src');
            if AttrVal = '' then AttrVal := FindAttrValue(Tag, 'href');
            if AttrVal = '' then AttrVal := FindAttrValue(Tag, 'xlink:href');

            if AttrVal <> '' then
            begin
              if InTextBlock and (Trim(CurrentElem.Text) <> '') then
              begin
                CurrentElem.Text := Trim(CurrentElem.Text);
                SetLength(Result, Length(Result)+1);
                Result[High(Result)] := CurrentElem;
                CurrentElem.Text := '';
              end;
              InTextBlock := False;

              SetLength(Result, Length(Result)+1);
              Result[High(Result)].ElemType := cetImage;
              Result[High(Result)].ImgSrc := AttrVal;
            end;
          end;
          'br':
          begin
            SetLength(Result, Length(Result)+1);
            Result[High(Result)].ElemType := cetEmptyLine;
          end;
          'code':
          begin
            CurrentElem.ElemType := cetParagraph;
            InTextBlock := True;
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
      TextContent := CollapseSpaces(TextContent);
      TextContent := Trim(TextContent);

      if TextContent <> '' then
      begin
        if not InTextBlock then
        begin
          CurrentElem.ElemType := cetParagraph;
          CurrentElem.Text := '';
          InTextBlock := True;
        end;
        case CurrentType of
          cetEmphasis: CurrentElem.ElemType := cetEmphasis;
          cetStrong: CurrentElem.ElemType := cetStrong;
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
end;

// === Главная функция конвертации ===

function ConvertEpubToFb2(const EpubFileName, Fb2FileName: string): Boolean;
var
  Zip: Pointer;
  Content, OpfPath, BasePath, Tag, Id, Href, Title, Author: string;
  i, j, k, ImgCounter: Integer;
  InMetadata, InManifest, InSpine: Boolean;
  SpineList: TStringList;
  IdMap: TStringList;
  FS: TFileStream;
  XHTMLPath, ImgPath, Ext, ImgId, Base64Data: string;
  ImgData: TBytes;
  Elements: TConvElementArray;
  HasContent: Boolean;
  ElemIdx: Integer;
  Elem: TConvElement;
  ImagesList: TConvImageArray;
  ImgIdx: Integer;
  ActualType: TConvElemType;

  NcxFileName, NcxPath, NcxContent: string;
  ChaptersFromNcx: TChapterArray;
  NcxChapterIdx: Integer;
  ExplicitChapterTitle: string;
  AlreadyHasTitle: Boolean;

  procedure WriteString(const S: string);
  begin
    if Length(S) > 0 then
      FS.WriteBuffer(S[1], Length(S));
  end;

begin
  Result := False;
  if not SysUtils.FileExists(EpubFileName) then Exit;

  Zip := unzOpen(PAnsiChar(AnsiString(EpubFileName)));
  if Zip = nil then Exit;

  SpineList := TStringList.Create;
  IdMap := TStringList.Create;
  ImgCounter := 0;
  SetLength(ImagesList, 0);

  try
    Content := GetZipFileContent(Zip, 'META-INF/container.xml');
    if Content = '' then Exit;
    OpfPath := FindAttrValue(Content, 'full-path');
    if OpfPath = '' then Exit;
    BasePath := ExtractFilePath(OpfPath);

    Content := GetZipFileContent(Zip, OpfPath);
    if Content = '' then Exit;

    InMetadata := False;
    InManifest := False;
    InSpine := False;
    Title := '';
    Author := '';
    NcxFileName := '';

    i := 1;
    while i <= Length(Content) do
    begin
      if Content[i] = '<' then
      begin
        j := Pos('>', Content, i);
        if j = 0 then Break;
        Tag := Copy(Content, i+1, j-i-1);

        if Pos('metadata', Tag) > 0 then InMetadata := True;
        if Pos('/metadata', Tag) > 0 then InMetadata := False;
        if Pos('manifest', Tag) > 0 then InManifest := True;
        if Pos('/manifest', Tag) > 0 then InManifest := False;
        if Pos('spine', Tag) > 0 then InSpine := True;
        if Pos('/spine', Tag) > 0 then InSpine := False;

        if InMetadata then
        begin
          if Pos('dc:title', Tag) > 0 then
          begin
            k := Pos('</dc:title>', Content, j);
            if k > j then Title := Trim(Copy(Content, j+1, k-j-1));
          end;
          if Pos('dc:creator', Tag) > 0 then
          begin
            k := Pos('</dc:creator>', Content, j);
            if k > j then Author := Trim(Copy(Content, j+1, k-j-1));
          end;
        end;

        if InManifest and (Pos('item ', Tag) > 0) then
        begin
          Id := FindAttrValue(Tag, 'id');
          Href := FindAttrValue(Tag, 'href');
          if Href <> '' then Href := NormalizeArchivePath(Href);
          if (Id <> '') and (Href <> '') then IdMap.Add(Id + '=' + Href);

          if Pos('application/x-dtbncx+xml', Tag) > 0 then
            NcxFileName := Href;
        end;

        if InSpine and (Pos('itemref ', Tag) > 0) then
        begin
          Id := FindAttrValue(Tag, 'idref');
          if Id <> '' then
          begin
            Href := '';
            for k := 0 to IdMap.Count - 1 do
            begin
              if (Pos(Id + '=', IdMap[k]) = 1) or (IdMap[k] = Id) then
              begin
                Href := Copy(IdMap[k], Length(Id) + 2, MaxInt);
                Break;
              end;
            end;
            if Href = '' then
            begin
              if Pos('.', Id) > 0 then Href := Id else Href := Id + '.xhtml';
            end;
            Href := NormalizeArchivePath(Href);
            SpineList.Add(Href);
          end;
        end;
        i := j + 1;
      end
      else
        Inc(i);
    end;

    if SpineList.Count = 0 then Exit;

    if NcxFileName <> '' then
    begin
      NcxPath := CombineEPUBPath(BasePath, NcxFileName);
      NcxContent := GetZipFileContent(Zip, NcxPath);
      if NcxContent <> '' then
        ChaptersFromNcx := ParseNcxToChapters(NcxContent, BasePath);
    end;

    FS := TFileStream.Create(Fb2FileName, fmCreate);
    try
      WriteString('<?xml version="1.0" encoding="UTF-8"?>'#10);
      WriteString('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">'#10);

      WriteString('  <description>'#10);
      WriteString('    <title-info>'#10);
      if Title <> '' then
        WriteString('      <book-title>' + EscapeXML(Title) + '</book-title>'#10);
      if Author <> '' then
      begin
        WriteString('      <author>'#10);
        WriteString('        <first-name>' + EscapeXML(Author) + '</first-name>'#10);
        WriteString('      </author>'#10);
      end;
      WriteString('    </title-info>'#10);
      WriteString('  </description>'#10);

      WriteString('  <body>'#10);

      for i := 0 to SpineList.Count - 1 do
      begin
        XHTMLPath := CombineEPUBPath(BasePath, SpineList[i]);
        Content := GetZipFileContent(Zip, XHTMLPath);
        if Content = '' then Continue;

        Elements := ParseXHTMLToElements(Content);

        HasContent := False;
        // ИСПРАВЛЕНИЕ: cetImage добавлен в проверку, чтобы главы с картинками не пропускались
        for ElemIdx := 0 to High(Elements) do
          if Elements[ElemIdx].ElemType in [cetParagraph, cetTitle, cetSubtitle, cetVerse, cetEmphasis, cetStrong, cetBlockquote, cetImage] then
          begin
            HasContent := True;
            Break;
          end;
        if not HasContent then Continue;

        ExplicitChapterTitle := '';
        for NcxChapterIdx := 0 to High(ChaptersFromNcx) do
        begin
          if (ChaptersFromNcx[NcxChapterIdx].Src = XHTMLPath) or
             (Pos(ChaptersFromNcx[NcxChapterIdx].Src, XHTMLPath) > 0) or
             (Pos(XHTMLPath, ChaptersFromNcx[NcxChapterIdx].Src) > 0) then
          begin
            ExplicitChapterTitle := ChaptersFromNcx[NcxChapterIdx].Title;
            Break;
          end;
        end;

        if ExplicitChapterTitle <> '' then
        begin
          AlreadyHasTitle := False;
          for ElemIdx := 0 to High(Elements) do
          begin
            if Elements[ElemIdx].ElemType = cetTitle then
            begin
              if (Pos(ExplicitChapterTitle, Elements[ElemIdx].Text) > 0) or
                 (Pos(Elements[ElemIdx].Text, ExplicitChapterTitle) > 0) then
              begin
                AlreadyHasTitle := True;
                Break;
              end;
            end;
            if Elements[ElemIdx].ElemType in [cetParagraph, cetVerse, cetBlockquote] then
              Break;
          end;

          if not AlreadyHasTitle then
          begin
            SetLength(Elements, Length(Elements) + 1);
            for ElemIdx := High(Elements) downto 1 do
              Elements[ElemIdx] := Elements[ElemIdx - 1];

            Elements[0].ElemType := cetTitle;
            Elements[0].Text := ExplicitChapterTitle;
            Elements[0].ImgSrc := '';
          end;
        end;

        for ElemIdx := 0 to High(Elements) do
        begin
          Elem := Elements[ElemIdx];

          if Elem.ElemType = cetParagraph then
            ActualType := cetParagraph
          else
            ActualType := Elem.ElemType;

          case ActualType of
            cetTitle:
            begin
              WriteString('    <section>'#10);
              WriteString('      <title>'#10);
              WriteString('        <p>' + EscapeXML(Elem.Text) + '</p>'#10);
              WriteString('      </title>'#10);
              WriteString('    </section>'#10);
            end;
            cetSubtitle:
              WriteString('      <subtitle>' + EscapeXML(Elem.Text) + '</subtitle>'#10);
            cetParagraph:
              WriteString('      <p>' + EscapeXML(Elem.Text) + '</p>'#10);
            cetVerse:
            begin
              WriteString('      <poem>'#10);
              WriteString('        <stanza>'#10);
              WriteString('          <v>' + EscapeXML(Elem.Text) + '</v>'#10);
              WriteString('        </stanza>'#10);
              WriteString('      </poem>'#10);
            end;
            cetEmphasis:
              WriteString('      <p><emphasis>' + EscapeXML(Elem.Text) + '</emphasis></p>'#10);
            cetStrong:
              WriteString('      <p><strong>' + EscapeXML(Elem.Text) + '</strong></p>'#10);
            cetBlockquote:
              WriteString('      <cite>' + EscapeXML(Elem.Text) + '</cite>'#10);
            cetEmptyLine:
              WriteString('      <empty-line/>'#10);
            cetImage:
            begin
              // 1. Пробуем собрать путь относительно текущей главы
              ImgPath := CombineEPUBPath(BasePath, Elem.ImgSrc);
              ImgData := ReadZipFileBytes(Zip, ImgPath);

              // 2. FALLBACK: если не нашли, пробуем по имени файла (частая проблема кривых EPUB)
              if Length(ImgData) = 0 then
              begin
                ImgPath := ExtractFileName(Elem.ImgSrc);
                ImgData := ReadZipFileBytes(Zip, ImgPath);
              end;

              if Length(ImgData) > 0 then
              begin
                Inc(ImgCounter);
                ImgId := 'img_' + IntToStr(ImgCounter);
                Ext := LowerCase(ExtractFileExt(Elem.ImgSrc));
                if (Ext = '') or (Pos('.', Ext) = 0) then Ext := '.jpg';
                Base64Data := EncodeBase64Bytes(ImgData);

                SetLength(ImagesList, Length(ImagesList) + 1);
                ImagesList[High(ImagesList)].Id := ImgId;
                ImagesList[High(ImagesList)].ContentType := GetImageContentType(Ext);
                ImagesList[High(ImagesList)].Base64Data := Base64Data;

                WriteString('      <image l:href="#' + ImgId + '"/>'#10);
              end;
            end;
          end;
        end;
      end;

      WriteString('  </body>'#10);

      // Запись картинок в конец файла (после </body>)
      for ImgIdx := 0 to High(ImagesList) do
      begin
        WriteString('  <binary id="' + ImagesList[ImgIdx].Id + '" content-type="' + ImagesList[ImgIdx].ContentType + '">'#10);
        WriteString(ImagesList[ImgIdx].Base64Data); // Base64 уже содержит #10 каждые 76 символов
        WriteString('  </binary>'#10);
      end;

      WriteString('</FictionBook>'#10);
      Result := True;
    finally
      FS.Free;
    end;
  finally
    IdMap.Free;
    SpineList.Free;
    unzClose(unzFile(Zip));
  end;
end;

end.
