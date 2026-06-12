unit RtfToFb2Converter;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, LConvEncoding;

function ConvertRtfToFb2(const RtfFileName, Fb2FileName: string): Boolean;

implementation

type
  TRtfState = record
    IsBold: Boolean;
    IsItalic: Boolean;
    IsUnderline: Boolean;
  end;

  TRtfRun = record
    Text: UTF8String;
    IsBold: Boolean;
    IsItalic: Boolean;
    IsUnderline: Boolean;
  end;

  TRtfRunArray = array of TRtfRun;

  TRtfParagraph = record
    Runs: TRtfRunArray;
  end;

  TRtfParagraphArray = array of TRtfParagraph;

// === Вспомогательные функции ===

// Собственная реализация проверки UTF-8, чтобы избежать ошибок компиляции
// в старых версиях FPC/Lazarus, где IsUTF8 может отсутствовать
function IsUTF8Str(const S: string): Boolean;
var
  i: Integer;
  c: Byte;
begin
  Result := True;
  i := 1;
  while i <= Length(S) do
  begin
    c := Ord(S[i]);
    if c < $80 then
      Inc(i)
    else if (c and $E0) = $C0 then
    begin
      if (i + 1 > Length(S)) or ((Ord(S[i+1]) and $C0) <> $80) then Exit(False);
      Inc(i, 2);
    end
    else if (c and $F0) = $E0 then
    begin
      if (i + 2 > Length(S)) or ((Ord(S[i+1]) and $C0) <> $80) or ((Ord(S[i+2]) and $C0) <> $80) then Exit(False);
      Inc(i, 3);
    end
    else
      Exit(False); // Недопустимый байт для UTF-8
  end;
end;

// Умная конвертация: если строка уже в UTF-8, оставляет как есть,
// иначе конвертирует из CP1251 (стандарт для русских RTF в Windows)
function ConvertToUTF8(const S: string): UTF8String;
begin
  if IsUTF8Str(S) then
    Result := UTF8String(S)
  else
    Result := CP1251ToUTF8(S);
end;

function EscapeXML(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

function ParseRtfToParagraphs(const RtfContent: string): TRtfParagraphArray;
var
  i, j, k: Integer;
  c: Char;
  CtrlWord, Param, HexStr: string;
  StateStack: array of TRtfState;
  SkipDepth: Integer;
  CurrentRun: TRtfRun;
  CurrentParagraph: TRtfParagraph;
  ByteVal: Integer;
  CodePoint: Integer;
  Ch: UTF8String;

  procedure FinalizeRun;
  begin
    if CurrentRun.Text <> '' then
    begin
      SetLength(CurrentParagraph.Runs, Length(CurrentParagraph.Runs) + 1);
      CurrentParagraph.Runs[High(CurrentParagraph.Runs)] := CurrentRun;
      CurrentRun.Text := '';
    end;
  end;

  procedure FinalizeParagraph;
  begin
    FinalizeRun;
    if Length(CurrentParagraph.Runs) > 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := CurrentParagraph;
    end;
    SetLength(CurrentParagraph.Runs, 0);
  end;

begin
  SetLength(Result, 0);
  SetLength(StateStack, 1);
  StateStack[0].IsBold := False;
  StateStack[0].IsItalic := False;
  StateStack[0].IsUnderline := False;

  SkipDepth := 0;
  CurrentRun.Text := '';
  CurrentRun.IsBold := False;
  CurrentRun.IsItalic := False;
  CurrentRun.IsUnderline := False;

  i := 1;
  while i <= Length(RtfContent) do
  begin
    c := RtfContent[i];

    if c = '{' then
    begin
      if SkipDepth > 0 then
        Inc(SkipDepth)
      else
      begin
        SetLength(StateStack, Length(StateStack) + 1);
        StateStack[High(StateStack)] := StateStack[High(StateStack) - 1];
      end;
    end
    else if c = '}' then
    begin
      if SkipDepth > 0 then
        Dec(SkipDepth)
      else
      begin
        FinalizeRun;
        if Length(StateStack) > 1 then
          SetLength(StateStack, Length(StateStack) - 1);
      end;
    end
    else if c = '\' then
    begin
      Inc(i);
      if i > Length(RtfContent) then Break;
      c := RtfContent[i];

      if c in ['a'..'z', 'A'..'Z'] then
      begin
        j := i;
        while (j <= Length(RtfContent)) and (RtfContent[j] in ['a'..'z', 'A'..'Z']) do
          Inc(j);

        CtrlWord := LowerCase(Copy(RtfContent, i, j - i));
        i := j - 1;

        Param := '';
        if (i + 1 <= Length(RtfContent)) and (RtfContent[i + 1] in ['0'..'9', '-']) then
        begin
          k := i + 1;
          while (k <= Length(RtfContent)) and (RtfContent[k] in ['0'..'9', '-']) do
            Inc(k);
          Param := Copy(RtfContent, i + 1, k - i - 1);
          i := k - 1;
        end
        else if (i + 1 <= Length(RtfContent)) and (RtfContent[i + 1] = ' ') then
          Inc(i);

        if SkipDepth = 0 then
        begin
          if CtrlWord = 'fonttbl' then SkipDepth := 1
          else if CtrlWord = 'colortbl' then SkipDepth := 1
          else if CtrlWord = 'stylesheet' then SkipDepth := 1
          else if CtrlWord = 'info' then SkipDepth := 1
          else if CtrlWord = 'pict' then SkipDepth := 1
          else if CtrlWord = 'header' then SkipDepth := 1
          else if CtrlWord = 'footer' then SkipDepth := 1
          else if CtrlWord = 'footnote' then SkipDepth := 1
          else if CtrlWord = 'par' then
          begin
            FinalizeParagraph;
          end
          else if CtrlWord = 'line' then
          begin
            CurrentRun.Text := CurrentRun.Text + ConvertToUTF8(#10);
          end
          else if CtrlWord = 'tab' then
          begin
            CurrentRun.Text := CurrentRun.Text + ConvertToUTF8(#9);
          end
          else if CtrlWord = 'b' then
          begin
            FinalizeRun;
            StateStack[High(StateStack)].IsBold := (Param = '') or (Param = '1');
            CurrentRun.IsBold := StateStack[High(StateStack)].IsBold;
          end
          else if CtrlWord = 'i' then
          begin
            FinalizeRun;
            StateStack[High(StateStack)].IsItalic := (Param = '') or (Param = '1');
            CurrentRun.IsItalic := StateStack[High(StateStack)].IsItalic;
          end
          else if CtrlWord = 'ul' then
          begin
            FinalizeRun;
            StateStack[High(StateStack)].IsUnderline := (Param = '') or (Param = '1');
            CurrentRun.IsUnderline := StateStack[High(StateStack)].IsUnderline;
          end
          else if CtrlWord = 'ulnone' then
          begin
            FinalizeRun;
            StateStack[High(StateStack)].IsUnderline := False;
            CurrentRun.IsUnderline := False;
          end
          else if CtrlWord = 'u' then
          begin
            if Param <> '' then
            begin
              try
                CodePoint := StrToInt(Param);
                // Формируем UTF-8 символ из Unicode code point
                if CodePoint < $80 then
                  Ch := UTF8String(Char(CodePoint))
                else if CodePoint < $800 then
                  Ch := UTF8String(Char($C0 or (CodePoint shr 6)) + Char($80 or (CodePoint and $3F)))
                else
                  Ch := UTF8String(Char($E0 or (CodePoint shr 12)) + Char($80 or ((CodePoint shr 6) and $3F)) + Char($80 or (CodePoint and $3F)));

                CurrentRun.Text := CurrentRun.Text + Ch;
              except
                CurrentRun.Text := CurrentRun.Text + '?';
              end;
            end;
            // Пропускаем следующий символ '?' если он есть (стандарт RTF для fallback)
            if (i + 1 <= Length(RtfContent)) and (RtfContent[i + 1] = '?') then
              Inc(i);
          end;
        end;
      end
      else if c = '''' then
      begin
        if SkipDepth = 0 then
        begin
          if i + 2 <= Length(RtfContent) then
          begin
            HexStr := Copy(RtfContent, i + 1, 2);
            try
              ByteVal := StrToInt('$' + HexStr);
              // Конвертируем байт ANSI (например, русскую букву из CP1251) в UTF-8
              CurrentRun.Text := CurrentRun.Text + ConvertToUTF8(string(Char(ByteVal)));
            except
              CurrentRun.Text := CurrentRun.Text + '?';
            end;
            i := i + 2;
          end;
        end
        else
          i := i + 2;
      end
      else if c in ['{', '}', '\'] then
      begin
        if SkipDepth = 0 then
          CurrentRun.Text := CurrentRun.Text + ConvertToUTF8(string(c));
      end;
    end
    else
    begin
      if SkipDepth = 0 then
      begin
        if (CurrentRun.Text <> '') and
           ((CurrentRun.IsBold <> StateStack[High(StateStack)].IsBold) or
            (CurrentRun.IsItalic <> StateStack[High(StateStack)].IsItalic) or
            (CurrentRun.IsUnderline <> StateStack[High(StateStack)].IsUnderline)) then
        begin
          FinalizeRun;
          CurrentRun.IsBold := StateStack[High(StateStack)].IsBold;
          CurrentRun.IsItalic := StateStack[High(StateStack)].IsItalic;
          CurrentRun.IsUnderline := StateStack[High(StateStack)].IsUnderline;
        end;
        // Конвертируем каждый обычный символ в UTF-8 при добавлении
        CurrentRun.Text := CurrentRun.Text + ConvertToUTF8(string(c));
      end;
    end;

    Inc(i);
  end;

  FinalizeParagraph;
end;

// === Главная функция конвертации ===

function ConvertRtfToFb2(const RtfFileName, Fb2FileName: string): Boolean;
var
  RtfContent: string;
  Paragraphs: TRtfParagraphArray;
  ParaIdx, RunIdx: Integer;
  FS: TFileStream;
  RunText: string;

  procedure WriteString(const S: string);
  begin
    if Length(S) > 0 then
      FS.WriteBuffer(S[1], Length(S));
  end;

begin
  Result := False;
  if not SysUtils.FileExists(RtfFileName) then Exit;

  try
    RtfContent := '';
    with TFileStream.Create(RtfFileName, fmOpenRead or fmShareDenyWrite) do
    try
      SetLength(RtfContent, Size);
      if Size > 0 then
        ReadBuffer(RtfContent[1], Size);
    finally
      Free;
    end;

    if RtfContent = '' then Exit;

    Paragraphs := ParseRtfToParagraphs(RtfContent);
    if Length(Paragraphs) = 0 then Exit;

    FS := TFileStream.Create(Fb2FileName, fmCreate);
    try
      WriteString('<?xml version="1.0" encoding="UTF-8"?>'#10);
      WriteString('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">'#10);
      WriteString('  <description>'#10);
      WriteString('    <title-info>'#10);
      WriteString('      <book-title>Конвертированный документ</book-title>'#10);
      WriteString('      <author>'#10);
      WriteString('        <first-name>Неизвестный</first-name>'#10);
      WriteString('      </author>'#10);
      WriteString('    </title-info>'#10);
      WriteString('  </description>'#10);
      WriteString('  <body>'#10);
      WriteString('    <section>'#10);

      for ParaIdx := 0 to High(Paragraphs) do
      begin
        // Пропускаем полностью пустые абзацы
        RunText := '';
        for RunIdx := 0 to High(Paragraphs[ParaIdx].Runs) do
          RunText := RunText + string(Paragraphs[ParaIdx].Runs[RunIdx].Text);

        if Trim(RunText) = '' then
          Continue;

        WriteString('      <p>'#10);

        for RunIdx := 0 to High(Paragraphs[ParaIdx].Runs) do
        begin
          with Paragraphs[ParaIdx].Runs[RunIdx] do
          begin
            if Text = '' then Continue;

            // Формируем открывающие теги
            if IsBold and IsItalic then
              WriteString('        <strong><emphasis>')
            else if IsBold then
              WriteString('        <strong>')
            else if IsItalic then
              WriteString('        <emphasis>');

            // Text уже в UTF8String, приводим к string для WriteBuffer и EscapeXML
            WriteString('          ' + EscapeXML(string(Text)));

            // Формируем закрывающие теги
            if IsBold and IsItalic then
              WriteString('</emphasis></strong>'#10)
            else if IsBold then
              WriteString('</strong>'#10)
            else if IsItalic then
              WriteString('</emphasis>'#10)
            else
              WriteString(#10);
          end;
        end;

        WriteString('      </p>'#10);
      end;

      WriteString('    </section>'#10);
      WriteString('  </body>'#10);
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
