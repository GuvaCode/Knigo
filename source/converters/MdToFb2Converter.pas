unit MdToFb2Converter;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, LConvEncoding;

function ConvertMdToFb2(const MdFileName, Fb2FileName: string): Boolean;

implementation

type
  TConvElemType = (cetTitle1, cetTitle2, cetTitle3, cetParagraph, cetBlockquote, cetCode, cetHR);
  
  TConvElement = record
    ElemType: TConvElemType;
    Text: string;
  end;

  TConvElementArray = array of TConvElement;

  TConvImage = record
    Id: string;
    ContentType: string;
    Base64Data: string;
  end;

  TConvImageArray = array of TConvImage;

// === Вспомогательные функции ===

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

function EncodeBase64Bytes(const Data: TBytes): string;
const
  Base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  i, Len: Integer;
  B1, B2, B3: Byte;
begin
  Result := '';
  Len := Length(Data);
  i := 0;
  while i < Len do
  begin
    B1 := Data[i]; Inc(i);
    B2 := 0; if i < Len then begin B2 := Data[i]; Inc(i); end;
    B3 := 0; if i < Len then begin B3 := Data[i]; Inc(i); end;
    Result := Result + Base64Chars[(B1 shr 2) + 1];
    Result := Result + Base64Chars[((B1 and 3) shl 4) or (B2 shr 4) + 1];
    if i - 1 < Len then
      Result := Result + Base64Chars[((B2 and 15) shl 2) or (B3 shr 6) + 1]
    else
      Result := Result + '=';
    if i < Len then
      Result := Result + Base64Chars[(B3 and 63) + 1]
    else
      Result := Result + '=';
  end;
end;

function LoadFileBytes(const FileName: string): TBytes;
var
  FS: TFileStream;
begin
  Result := nil;
  if not SysUtils.FileExists(FileName) then Exit;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, FS.Size);
    if FS.Size > 0 then
      FS.ReadBuffer(Result[0], FS.Size);
  finally
    FS.Free;
  end;
end;

function EscapeXML(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

// Обработка инлайн-разметки: **жирный**, *курсив*, [ссылки](url), ![изображения](url)
function ProcessInline(const S: string; const BaseDir: string; var Images: TConvImageArray; var ImgCounter: Integer): string;
var
  i, j, k: Integer;
  Res, Temp, Url, Alt: string;
  IsBold, IsItalic: Boolean;
  ImgData: TBytes;
  Ext: string;
  ImgFileName: string;
begin
  Result := '';
  i := 1;
  IsBold := False;
  IsItalic := False;
  
  while i <= Length(S) do
  begin
    // 1. Изображение: ![alt](url)
    if (i <= Length(S)-3) and (S[i] = '!') and (S[i+1] = '[') then
    begin
      j := Pos('](', S, i+2);
      if j > 0 then
      begin
        k := PosEx(')', S, j+2);
        if k > 0 then
        begin
          Alt := Copy(S, i+2, j-i-2);
          Url := Copy(S, j+2, k-j-2);
          
          // Пытаемся загрузить локальный файл
          ImgFileName := Url;
          if not SysUtils.FileExists(ImgFileName) then
            ImgFileName := IncludeTrailingPathDelimiter(BaseDir) + Url;
            
          ImgData := LoadFileBytes(ImgFileName);
          if Length(ImgData) > 0 then
          begin
            Inc(ImgCounter);
            Ext := LowerCase(ExtractFileExt(Url));
            if Ext = '' then Ext := '.png';
            SetLength(Images, Length(Images) + 1);
            Images[High(Images)].Id := 'img_' + IntToStr(ImgCounter);
            Images[High(Images)].ContentType := GetImageContentType(Ext);
            Images[High(Images)].Base64Data := EncodeBase64Bytes(ImgData);
            Result := Result + '<image l:href="#' + Images[High(Images)].Id + '"/>';
          end
          else
            Result := Result + '[' + EscapeXML(Alt) + ']'; // Фоллбэк, если картинку не нашли
            
          i := k + 1;
          Continue;
        end;
      end;
    end;

    // 2. Ссылка: [text](url)
    if (S[i] = '[') and not IsBold and not IsItalic then
    begin
      j := Pos('](', S, i+1);
      if j > 0 then
      begin
        k := PosEx(')', S, j+2);
        if k > 0 then
        begin
          Temp := Copy(S, i+1, j-i-1);
          Url := Copy(S, j+2, k-j-2);
          Result := Result + '<a l:href="' + EscapeXML(Url) + '">' + EscapeXML(Temp) + '</a>';
          i := k + 1;
          Continue;
        end;
      end;
    end;

    // 3. Жирный шрифт: ** или __
    if (i <= Length(S)-1) and (S[i] = '*') and (S[i+1] = '*') then
    begin
      if IsBold then Result := Result + '</strong>' else Result := Result + '<strong>';
      IsBold := not IsBold;
      Inc(i, 2);
      Continue;
    end;
    
    if (i <= Length(S)-1) and (S[i] = '_') and (S[i+1] = '_') then
    begin
      if IsBold then Result := Result + '</strong>' else Result := Result + '<strong>';
      IsBold := not IsBold;
      Inc(i, 2);
      Continue;
    end;

    // 4. Курсив: * или _ (одиночные)
    if (S[i] = '*') or (S[i] = '_') then
    begin
      if IsItalic then Result := Result + '</emphasis>' else Result := Result + '<emphasis>';
      IsItalic := not IsItalic;
      Inc(i);
      Continue;
    end;

    // 5. Обычный символ
    Result := Result + EscapeXML(S[i]);
    Inc(i);
  end;

  // Закрываем незакрытые теги (на случай некорректного MD)
  if IsBold then Result := Result + '</strong>';
  if IsItalic then Result := Result + '</emphasis>';
end;

// === Парсер Markdown ===

procedure FlushBlock(var CurrentText: string; BlockType: TConvElemType; 
  var Elements: TConvElementArray; const BaseDir: string; 
  var Images: TConvImageArray; var ImgCounter: Integer);
begin
  if Trim(CurrentText) = '' then Exit;
  
  SetLength(Elements, Length(Elements) + 1);
  Elements[High(Elements)].ElemType := BlockType;
  
  if BlockType = cetCode then
    Elements[High(Elements)].Text := CurrentText // Уже экранирован
  else
    Elements[High(Elements)].Text := ProcessInline(CurrentText, BaseDir, Images, ImgCounter);
    
  CurrentText := '';
end;

function ParseMarkdownToElements(const MdContent: string; const BaseDir: string; 
  var Images: TConvImageArray; var ImgCounter: Integer): TConvElementArray;
var
  i, j, k: Integer;
  Line, Temp: string;
  CurrentText: string;
  CurrentBlockType: TConvElemType;
  InCodeBlock: Boolean;
begin
  SetLength(Result, 0);
  CurrentText := '';
  CurrentBlockType := cetParagraph;
  InCodeBlock := False;
  i := 1;

  while i <= Length(MdContent) do
  begin
    // Извлекаем строку
    j := i;
    while (j <= Length(MdContent)) and not (MdContent[j] in [#10, #13]) do Inc(j);
    Line := Copy(MdContent, i, j - i);
    
    // Продвигаем индекс за перенос строки
    if (j <= Length(MdContent)) and (MdContent[j] = #13) and (j+1 <= Length(MdContent)) and (MdContent[j+1] = #10) then
      Inc(j, 2)
    else if (j <= Length(MdContent)) and (MdContent[j] in [#10, #13]) then
      Inc(j);

    Line := Trim(Line);

    if InCodeBlock then
    begin
      if Line = '```' then
      begin
        InCodeBlock := False;
        FlushBlock(CurrentText, cetCode, Result, BaseDir, Images, ImgCounter);
      end
      else
      begin
        if CurrentText <> '' then CurrentText := CurrentText + #10;
        CurrentText := CurrentText + EscapeXML(Line);
      end;
    end
    else if Line = '```' then
    begin
      FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
      InCodeBlock := True;
    end
    else if Line = '' then
    begin
      FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
      // Добавляем пустую строку, если предыдущий элемент не был пустым
      if (Length(Result) > 0) and (Result[High(Result)].ElemType <> cetHR) then
      begin
        // В FB2 пустые строки внутри <p> не нужны, они регулируются структурой.
        // Но мы можем добавить cetHR или просто пропустить. Пропускаем.
      end;
    end
    else if (Length(Line) >= 1) and (Line[1] = '#') then
    begin
      FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
      k := 1;
      while (k <= Length(Line)) and (Line[k] = '#') do Inc(k);
      k := k - 1; // Количество решеток
      
      Temp := Trim(Copy(Line, k + 1, Length(Line) - k));
      // Убираем закрывающие решетки, если есть
      while (Length(Temp) > 0) and (Temp[Length(Temp)] = '#') do 
        Delete(Temp, Length(Temp), 1);
      Temp := Trim(Temp);

      SetLength(Result, Length(Result) + 1);
      if k = 1 then Result[High(Result)].ElemType := cetTitle1
      else if k = 2 then Result[High(Result)].ElemType := cetTitle2
      else Result[High(Result)].ElemType := cetTitle3;
      
      Result[High(Result)].Text := ProcessInline(Temp, BaseDir, Images, ImgCounter);
    end
    else if (Length(Line) >= 1) and (Line[1] = '>') then
    begin
      if CurrentBlockType <> cetBlockquote then
      begin
        FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
        CurrentBlockType := cetBlockquote;
      end;
      Temp := Trim(Copy(Line, 2, Length(Line) - 1));
      if CurrentText <> '' then CurrentText := CurrentText + ' ';
      CurrentText := CurrentText + Temp;
    end
    else if (Length(Line) >= 2) and ((Copy(Line, 1, 2) = '- ') or (Copy(Line, 1, 2) = '* ') or (Copy(Line, 1, 2) = '1.')) then
    begin
      // Списки в FB2 эмулируем через абзацы с маркерами
      if CurrentBlockType <> cetParagraph then
      begin
        FlushBlock(CurrentText, CurrentBlockType, Result, BaseDir, Images, ImgCounter);
        CurrentBlockType := cetParagraph;
      end;
      Temp := Trim(Copy(Line, 3, Length(Line) - 2));
      if CurrentText <> '' then CurrentText := CurrentText + #10;
      CurrentText := CurrentText + '• ' + Temp;
    end
    else if (Line = '---') or (Line = '***') or (Line = '___') then
    begin
      FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
      CurrentBlockType := cetParagraph;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].ElemType := cetHR;
    end
    else
    begin
      // Обычный текст
      if CurrentBlockType in [cetBlockquote, cetCode] then
      begin
        FlushBlock(CurrentText, CurrentBlockType, Result, BaseDir, Images, ImgCounter);
        CurrentBlockType := cetParagraph;
      end;
      if CurrentText <> '' then CurrentText := CurrentText + ' ';
      CurrentText := CurrentText + Line;
    end;

    i := j;
  end;
  
  // Финальный сброс
  if InCodeBlock then
    FlushBlock(CurrentText, cetCode, Result, BaseDir, Images, ImgCounter)
  else
    FlushBlock(CurrentText, cetParagraph, Result, BaseDir, Images, ImgCounter);
end;

// === Главная функция конвертации ===

function ConvertMdToFb2(const MdFileName, Fb2FileName: string): Boolean;
var
  MdContent: string;
  Elements: TConvElementArray;
  ElemIdx: Integer;
  Elem: TConvElement;
  Images: TConvImageArray;
  ImgIdx: Integer;
  ImgCounter: Integer;
  FS: TFileStream;
  BaseDir: string;
  BookTitle: string;

  procedure WriteString(const S: string);
  begin
    if Length(S) > 0 then
      FS.WriteBuffer(S[1], Length(S));
  end;

begin
  Result := False;
  if not SysUtils.FileExists(MdFileName) then Exit;

  BaseDir := ExtractFilePath(MdFileName);
  ImgCounter := 0;
  SetLength(Images, 0);

  try
    // Читаем файл. Предполагаем UTF-8, стандарт для Markdown
    with TFileStream.Create(MdFileName, fmOpenRead or fmShareDenyWrite) do
    try
      SetLength(MdContent, Size);
      if Size > 0 then
        ReadBuffer(MdContent[1], Size);
    finally
      Free;
    end;

    // Если файл не в UTF-8, пытаемся конвертировать из CP1251 (редко, но бывает)
    if not IsUTF8(MdContent) then
      MdContent := CP1251ToUTF8(MdContent);

    Elements := ParseMarkdownToElements(MdContent, BaseDir, Images, ImgCounter);
    if Length(Elements) = 0 then Exit;

    // Пытаемся извлечь заголовок книги из первого заголовка H1
    BookTitle := 'Конвертированный документ';
    for ElemIdx := 0 to High(Elements) do
    begin
      if Elements[ElemIdx].ElemType = cetTitle1 then
      begin
        BookTitle := Elements[ElemIdx].Text;
        Break;
      end;
    end;

    FS := TFileStream.Create(Fb2FileName, fmCreate);
    try
      WriteString('<?xml version="1.0" encoding="UTF-8"?>'#10);
      WriteString('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">'#10);
      
      // Описание
      WriteString('  <description>'#10);
      WriteString('    <title-info>'#10);
      WriteString('      <book-title>' + EscapeXML(BookTitle) + '</book-title>'#10);
      WriteString('      <author>'#10);
      WriteString('        <first-name>Автор</first-name>'#10);
      WriteString('      </author>'#10);
      WriteString('    </title-info>'#10);
      WriteString('  </description>'#10);
      
      // Тело документа
      WriteString('  <body>'#10);
      WriteString('    <section>'#10);

      for ElemIdx := 0 to High(Elements) do
      begin
        Elem := Elements[ElemIdx];
        case Elem.ElemType of
          cetTitle1:
          begin
            WriteString('      <title>'#10);
            WriteString('        <p>' + Elem.Text + '</p>'#10);
            WriteString('      </title>'#10);
          end;
          cetTitle2:
          begin
            WriteString('      <title>'#10);
            WriteString('        <p>' + Elem.Text + '</p>'#10);
            WriteString('      </title>'#10);
          end;
          cetTitle3:
          begin
            WriteString('      <subtitle>' + Elem.Text + '</subtitle>'#10);
          end;
          cetParagraph:
          begin
            // Заменяем переносы строк внутри абзаца на <br/> (для списков и т.д.)
            WriteString('      <p>' + StringReplace(Elem.Text, #10, '<br/>', [rfReplaceAll]) + '</p>'#10);
          end;
          cetBlockquote:
          begin
            WriteString('      <cite>'#10);
            WriteString('        <p>' + StringReplace(Elem.Text, #10, '<br/>', [rfReplaceAll]) + '</p>'#10);
            WriteString('      </cite>'#10);
          end;
          cetCode:
          begin
            WriteString('      <p>'#10);
            WriteString('        <strong>Код:</strong>'#10);
            WriteString('        <p>' + Elem.Text + '</p>'#10);
            WriteString('      </p>'#10);
          end;
          cetHR:
          begin
            WriteString('      <empty-line/>'#10);
          end;
        end;
      end;

      WriteString('    </section>'#10);
      WriteString('  </body>'#10);
      
      // Бинарные данные изображений
      for ImgIdx := 0 to High(Images) do
      begin
        WriteString('  <binary id="' + Images[ImgIdx].Id + '" content-type="' + Images[ImgIdx].ContentType + '">'#10);
        WriteString(Images[ImgIdx].Base64Data + #10);
        WriteString('  </binary>'#10);
      end;
      
      WriteString('</FictionBook>'#10);

      Result := True;
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

end.