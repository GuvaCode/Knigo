unit fb2Reader;
{$mode ObjFPC}{$H+}
{$WARN 5093 off : function result variable of a managed type does not seem to be initialized}
{$WARN 4045 off : Comparison might be always true due to range of constant and expression}
{$WARN 2031 off : compiler switches are not supported in // styled comments}
interface

uses
  Classes, SysUtils, raylib, Math, LConvEncoding, ReaderTools;

const
  PADDING_Y = 26;

type
  TElementType = (etParagraph, etTitle, etSubtitle, etImage, etEmptyLine,
    etVerse, etEmphasis, etCover);

  TFB2Element = record
    ElemType: TElementType;
    Text: string;
    Indent: integer;
    ImageTex: TTexture2D;
    ImageLoaded: boolean;
    ImgW, ImgH: integer;
  end;
  TFB2ElementArray = array of TFB2Element;

  // ИСПРАВЛЕНИЕ 1: Добавлено поле LineHeight для надежного расчета отступов
  TLayoutLine = record
    Text: string;
    XPos: single;
    YPos: single;
    ElemType: TElementType;
    Spacing: single;
    LineHeight: single;
  end;

  TLayoutImage = record
    Texture: TTexture2D;
    XPos, YPos: single;
    Width, Height: single;
  end;

  TFb2Chapter = record
    Title: string;
    Level: integer;
    StartY: single;
  end;
  TFB2ChapterArray = array of TFB2Chapter;

  TFB2Renderer = record
    Elements: TFB2ElementArray;
    Lines: array of TLayoutLine;
    Images: array of TLayoutImage;
    Chapters: TFB2ChapterArray;
    Font: TFont;
    TitleFont: TFont;
    SubtitleFont: TFont;
    ScrollY: single;
    MaxScroll: single;
    TotalHeight: single;
    Title: string;
    Author: string;
  end;

  TBinaryEntry = record
    Id, Data: string;
  end;
  TBinaryList = array of TBinaryEntry;

type
  { TFB2Reader }
  TFB2Reader = class
  private
    FBaseFontPath: string;
    FProgressColor: TColor;
    FProgressColorBack: TColorB;
    FRenderer: TFB2Renderer;
    FFileName: string;
    FNormalColor, FTitleColor, FSubtitleColor, FVerseColor: TColorB;
    FSubtitleFontPath: string;
    FTitleFontPath: string;
    FSCREEN_W: integer;
    FSCREEN_H: integer;
    FONT_SIZE: integer;
    LINE_HEIGHT: single;
    PADDING_X: integer;
    FAutoScroll: boolean;
    FAutoScrollSpeed: single;
    FSelectedChapterIndex: integer;
    function GetChapters: TFB2ChapterArray;
    function ParseInternal(const FileName: string;
      var Title_, Author_: string): TFB2ElementArray;
    procedure LayoutInternal(Width: integer);
    function GetIsLoaded: boolean;
    function GetVisibleContentHeight: single;
    procedure SetPadding(AValue: integer);
  public
    constructor Create;
    destructor Destroy; override;
    function LoadBook(const FileName: string): boolean;
    function GetCoverImage: TTexture2D;
    function GetAnnotation: pansichar;
    function GetNotes: TBookNoteArray;
    function GetNotesCount: integer;
    procedure Draw(Width, Height: integer);
    procedure UpdateScroll(WheelDelta: single;
      KeyUp, KeyDown, KeyPageUp, KeyPageDown: boolean);
    procedure ReloadFonts;
    procedure InvertColors;
    procedure ReloadLayout;
    procedure GoToChapter(ChapterIndex: integer);
    property Title: string read FRenderer.Title;
    property Author: string read FRenderer.Author;
    property Chapters: TFB2ChapterArray read GetChapters;
    property ScrollY: single read FRenderer.ScrollY write FRenderer.ScrollY;
    property MaxScroll: single read FRenderer.MaxScroll;
    property TotalHeight: single read FRenderer.TotalHeight;
    property IsLoaded: boolean read GetIsLoaded;
    property AutoScrollEnabled: boolean read FAutoScroll write FAutoScroll;
    property AutoScrollSpeed: single read FAutoScrollSpeed write FAutoScrollSpeed;
    property NormalTextColor: TColorB read FNormalColor write FNormalColor;
    property TitleTextColor: TColorB read FTitleColor write FTitleColor;
    property SubtitleTextColor: TColorB read FSubtitleColor write FSubtitleColor;
    property VerseTextColor: TColorB read FVerseColor write FVerseColor;
    property TextSize: integer read FONT_SIZE write FONT_SIZE;
    property Padding: integer read PADDING_X write SetPadding;
    property BaseFontPath: string read FBaseFontPath write FBaseFontPath;
    property TitleFontPath: string read FTitleFontPath write FTitleFontPath;
    property SubtitleFontPath: string read FSubtitleFontPath write FSubtitleFontPath;
    property ProgressColorBack: TColorB read FProgressColorBack write FProgressColorBack;
    property ProgressColor: TColor read FProgressColor write FProgressColor;
  end;

implementation

{ TFB2Reader }
constructor TFB2Reader.Create;
begin
  inherited Create;
  FNormalColor := ColorCreate(60, 60, 70, 255);
  FTitleColor := ColorCreate(40, 40, 70, 255);
  FSubtitleColor := ColorCreate(80, 80, 90, 255);
  FVerseColor := ColorCreate(50, 50, 60, 255);
  FProgressColor := ColorCreate(153, 152, 157, 255);
  FProgressColorBack := ColorCreate(225, 225, 226, 200);
  FAutoScroll := False;
  FAutoScrollSpeed := 1.0;
  FSCREEN_W := GetRenderWidth;
  FSCREEN_H := GetRenderHeight;
  FONT_SIZE := 24;
  LINE_HEIGHT := FONT_SIZE;
  PADDING_X := 64;
  FSelectedChapterIndex := -1;
end;

destructor TFB2Reader.Destroy;
var
  i: integer;
begin
  for i := 0 to Length(FRenderer.Images) - 1 do
    if FRenderer.Images[i].Texture.id <> 0 then UnloadTexture(FRenderer.Images[i].Texture);
  if FRenderer.Font.texture.id <> 0 then UnloadFont(FRenderer.Font);
  if FRenderer.TitleFont.texture.id <> 0 then UnloadFont(FRenderer.TitleFont);
  if FRenderer.SubtitleFont.texture.id <> 0 then UnloadFont(FRenderer.SubtitleFont);
  inherited Destroy;
end;

function TFB2Reader.GetIsLoaded: boolean;
begin
  Result := Length(FRenderer.Elements) > 0;
end;

function TFB2Reader.GetVisibleContentHeight: single;
begin
  Result := FSCREEN_H - PADDING_Y;
  if Result < LINE_HEIGHT then Result := LINE_HEIGHT;
end;

procedure TFB2Reader.SetPadding(AValue: integer);
begin
  if PADDING_X = AValue then Exit;
  if PADDING_X >= 64 then PADDING_X := AValue
  else
    PADDING_X := 64;
end;

function TFB2Reader.LoadBook(const FileName: string): boolean;
begin
  Result := False;
  if not SysUtils.FileExists(FileName) then Exit;
  FFileName := FileName;
  FRenderer.Elements := ParseInternal(FileName, FRenderer.Title, FRenderer.Author);
  if IsLoaded then
  begin
    LayoutInternal(FSCREEN_W);
    Result := True;
  end;
end;

function TFB2Reader.GetCoverImage: TTexture2D;
var
  i: integer;
begin
  Result.id := 0;
  if not IsLoaded then Exit;
  for i := 0 to Length(FRenderer.Elements) - 1 do
  begin
    if FRenderer.Elements[i].ElemType = etCover then
    begin
      if FRenderer.Elements[i].ImageLoaded then Result := FRenderer.Elements[i].ImageTex
      else
        Result.id := 0;
      Exit;
    end;
  end;
end;

function TFB2Reader.GetAnnotation: pansichar;
var
  Content, RawTag, TagName: string;
  FS: TFileStream;
  j, k: integer;
  InAnnotation: boolean;
  AnnotationText: string;
begin
  Result := nil;
  AnnotationText := '';
  if not SysUtils.FileExists(FFileName) then Exit;
  try
    FS := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Content, FS.Size);
      if FS.Size > 0 then FS.ReadBuffer(Content[1], FS.Size);
    finally
      FS.Free;
    end;
    ConvertEncodingIfNeeded(Content);
    Content := StringReplace(Content, #0, '', [rfReplaceAll]);
    j := Pos('<annotation>', Content);
    if j = 0 then j := Pos('<annotation ', Content);
    if j > 0 then
    begin
      j := Pos('>', Content, j) + 1;
      InAnnotation := True;
      while InAnnotation and (j <= Length(Content)) do
      begin
        if Content[j] = '<' then
        begin
          k := Pos('>', Content, j);
          if k = 0 then Break;
          RawTag := Trim(Copy(Content, j + 1, k - j - 1));
          if Pos('/', RawTag) = 1 then
          begin
            TagName := Trim(Copy(RawTag, 2, Length(RawTag) - 1));
            if TagName = 'annotation' then InAnnotation := False;
          end;
          j := k + 1;
        end
        else
        begin
          k := j;
          while (k <= Length(Content)) and (Content[k] <> '<') do Inc(k);
          if k > j then AnnotationText :=
              AnnotationText + DecodeXMLEntities(Copy(Content, j, k - j));
          j := k;
        end;
      end;
      AnnotationText := Trim(AnnotationText);
      AnnotationText := StringReplace(AnnotationText, #10, ' ', [rfReplaceAll]);
      AnnotationText := StringReplace(AnnotationText, #13, ' ', [rfReplaceAll]);
      AnnotationText := StringReplace(AnnotationText, #9, ' ', [rfReplaceAll]);
      while Pos('  ', AnnotationText) > 0 do
        AnnotationText := StringReplace(AnnotationText, '  ', ' ', [rfReplaceAll]);
      if AnnotationText <> '' then
      begin
        Result := StrAlloc(Length(AnnotationText) + 1);
        StrPCopy(Result, AnnotationText);
      end;
    end;
  except
    on E: Exception do WriteLn('Annotation parse error: ', E.Message);
  end;
end;

function TFB2Reader.GetNotes: TBookNoteArray;
var
  Content, RawTag, TagName, CurrentNoteId, CurrentNoteTitle, CurrentNoteText: string;
  FS: TFileStream;
  i, j, k, NoteIndex, CurrentDepth: integer;
  InNotesBody, InSection, InNote, InTitle, InContentTag: boolean;
begin
  SetLength(Result, 0);
  if not SysUtils.FileExists(FFileName) then Exit;
  try
    FS := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Content, FS.Size);
      if FS.Size > 0 then FS.ReadBuffer(Content[1], FS.Size);
    finally
      FS.Free;
    end;
    ConvertEncodingIfNeeded(Content);
    Content := StringReplace(Content, #0, '', [rfReplaceAll]);
    InNotesBody := False;
    i := 1;
    while i <= Length(Content) - 10 do
    begin
      if Content[i] = '<' then
      begin
        if CompareText(Copy(Content, i + 1, 4), 'body') = 0 then
        begin
          k := Pos('>', Content, i);
          if k > i then
          begin
            RawTag := Copy(Content, i + 1, k - i - 1);
            if (Length(RawTag) > 0) and (RawTag[1] <> '/') and (RawTag[Length(RawTag)] <> '/') then
            begin
              if CompareText(GetAttrValue(RawTag, 'name'), 'notes') = 0 then
              begin
                InNotesBody := True;
                i := k + 1;
                Break;
              end;
            end;
          end;
        end;
      end;
      Inc(i);
    end;
    if not InNotesBody then Exit;
    InSection := False;
    InNote := False;
    InTitle := False;
    InContentTag := False;
    CurrentNoteId := '';
    CurrentNoteTitle := '';
    CurrentNoteText := '';
    CurrentDepth := 0;
    NoteIndex := 0;
    while i <= Length(Content) do
    begin
      if CompareText(Copy(Content, i, 7), '</body>') = 0 then Break;
      if Content[i] = '<' then
      begin
        k := Pos('>', Content, i);
        if k = 0 then Break;
        RawTag := Trim(Copy(Content, i + 1, k - i - 1));
        if (Length(RawTag) > 0) and (RawTag[1] = '/') then
        begin
          TagName := Trim(Copy(RawTag, 2, Length(RawTag) - 1));
          if TagName = 'section' then
          begin
            Dec(CurrentDepth);
            if InNote and (CurrentDepth <= 0) then
            begin
              if CurrentNoteId <> '' then
              begin
                SetLength(Result, Length(Result) + 1);
                Result[NoteIndex].Id := CurrentNoteId;
                Result[NoteIndex].Title := Trim(CurrentNoteTitle);
                Result[NoteIndex].Text := Trim(CurrentNoteText);
                Inc(NoteIndex);
              end;
              InNote := False;
              CurrentNoteId := '';
              CurrentNoteTitle := '';
              CurrentNoteText := '';
            end;
          end
          else if TagName = 'title' then InTitle := False
          else if InContentTag and IsContentTag(TagName) then InContentTag := False;
        end
        else
        begin
          TagName := '';
          j := 1;
          while (j <= Length(RawTag)) and not (RawTag[j] in [' ', '/', '>']) do
          begin
            TagName := TagName + RawTag[j];
            Inc(j);
          end;
          if TagName = 'section' then
          begin
            Inc(CurrentDepth);
            InSection := True;
            CurrentNoteId := GetAttrValue(RawTag, 'id');
            if CurrentNoteId <> '' then
            begin
              InNote := True;
              CurrentNoteTitle := '';
              CurrentNoteText := '';
            end;
          end
          else if (TagName = 'title') and InNote then InTitle := True
          else if InNote and IsContentTag(TagName) then InContentTag := True;
        end;
        i := k + 1;
      end
      else
      begin
        if InTitle and InNote then
        begin
          k := Pos('<', Content, i);
          if k = 0 then k := Length(Content) + 1;
          CurrentNoteTitle := CurrentNoteTitle + DecodeXMLEntities(Copy(Content, i, k - i));
          i := k;
        end
        else if InContentTag and InNote then
        begin
          ExtractTextContent(i, Content, CurrentNoteText);
        end
        else
        begin
          k := Pos('<', Content, i);
          if k = 0 then Break;
          i := k;
        end;
      end;
    end;
  except
    on E: Exception do WriteLn('Notes parse error: ', E.Message);
  end;
end;

function TFB2Reader.GetNotesCount: integer;
var
  Notes: TBookNoteArray;
begin
  Notes := GetNotes;
  Result := Length(Notes);
end;

function SnapToLine(Value, LineHeight: single): single;
begin
  Result := Round(Value / LineHeight) * LineHeight;
end;

procedure TFB2Reader.UpdateScroll(WheelDelta: single;
  KeyUp, KeyDown, KeyPageUp, KeyPageDown: boolean);
var
  PageStep: single;
begin
  if not IsLoaded then Exit;
  if IsKeyPressed(KEY_SPACE) then FAutoScroll := not FAutoScroll;
  if FAutoScroll then
  begin
    if not (KeyUp or KeyDown or IsKeyDown(KEY_W) or IsKeyDown(KEY_S)) then
      FRenderer.ScrollY := FRenderer.ScrollY + FAutoScrollSpeed;
  end
  else
  begin
    FRenderer.ScrollY := FRenderer.ScrollY - WheelDelta;
    if KeyUp or IsKeyDown(KEY_W) then FRenderer.ScrollY := FRenderer.ScrollY - LINE_HEIGHT;
    if KeyDown or IsKeyDown(KEY_S) then FRenderer.ScrollY := FRenderer.ScrollY + LINE_HEIGHT;
    PageStep := GetVisibleContentHeight;
    if IsKeyPressed(KEY_PAGE_UP) then FRenderer.ScrollY :=
        SnapToLine(FRenderer.ScrollY - PageStep, LINE_HEIGHT);
    if IsKeyReleased(KEY_PAGE_DOWN) then
      FRenderer.ScrollY := SnapToLine(FRenderer.ScrollY + PageStep, LINE_HEIGHT);
    if IsKeyPressedRepeat(KEY_PAGE_UP) then FRenderer.ScrollY :=
        FRenderer.ScrollY - PageStep;
    if IsKeyPressedRepeat(KEY_PAGE_DOWN) then FRenderer.ScrollY :=
        FRenderer.ScrollY + PageStep;
  end;
  if FRenderer.ScrollY < 0.0 then FRenderer.ScrollY := 0.0;
  if FRenderer.ScrollY > FRenderer.MaxScroll then FRenderer.ScrollY := FRenderer.MaxScroll;
end;

procedure TFB2Reader.ReloadFonts;
begin
  FRenderer.Font.texture.id := 0;
  FRenderer.TitleFont.texture.id := 0;
  FRenderer.SubtitleFont.texture.id := 0;
  LINE_HEIGHT := FONT_SIZE;
  if SysUtils.FileExists(BaseFontPath) then
    LoadFontWithPreset(FRenderer.Font, FONT_SIZE, pansichar(BaseFontPath), 3);
  if SysUtils.FileExists(TitleFontPath) then
    LoadFontWithPreset(FRenderer.TitleFont, FONT_SIZE, pansichar(TitleFontPath), 3);
  if SysUtils.FileExists(SubtitleFontPath) then
    LoadFontWithPreset(FRenderer.SubtitleFont, FONT_SIZE, pansichar(SubtitleFontPath), 3);
end;

procedure TFB2Reader.InvertColors;
begin
  NormalTextColor := InvertColor(NormalTextColor);
  TitleTextColor := InvertColor(TitleTextColor);
  SubtitleTextColor := InvertColor(SubtitleTextColor);
  VerseTextColor := InvertColor(VerseTextColor);
  ProgressColor := InvertColor(ProgressColor);
  ProgressColorBack := InvertColor(ProgressColorBack);
end;

procedure TFB2Reader.ReloadLayout;
begin
  LayoutInternal(FSCREEN_W);
end;

procedure TFB2Reader.GoToChapter(ChapterIndex: integer);
begin
  if (ChapterIndex >= 0) and (ChapterIndex < Length(FRenderer.Chapters)) then
  begin
    FSelectedChapterIndex := ChapterIndex;
    FRenderer.ScrollY := FRenderer.Chapters[ChapterIndex].StartY;
    if FRenderer.ScrollY < 0 then FRenderer.ScrollY := 0;
    if FRenderer.ScrollY > FRenderer.MaxScroll then FRenderer.ScrollY := FRenderer.MaxScroll;
  end;
end;

// ИСПРАВЛЕНИЕ 2: Использование Line.LineHeight вместо глобального LINE_HEIGHT для отсечения
procedure TFB2Reader.Draw(Width, Height: integer);
var
  i: integer;
  ScreenY, ImgScreenY: single;
  Line: TLayoutLine;
  Img: TLayoutImage;
  TxtColor: TColorB;
  SrcRect, DstRect: TRectangle;
  VisibleH: single;
  CurrentFont: TFont;
  FontSize, Spacing: single;
  Progress: single;
  BarH, BarY, FillW: single;
  OldMaxScroll, ScrollRatio: single;
  PosVec: TVector2;
  TextSize_: TVector2;
begin
  if IsWindowResized then
  begin
    OldMaxScroll := FRenderer.MaxScroll;
    ScrollRatio := 0.0;
    if OldMaxScroll > 0 then ScrollRatio := FRenderer.ScrollY / OldMaxScroll;
    FSCREEN_W := GetRenderWidth;
    FSCREEN_H := GetRenderHeight;
    LayoutInternal(FSCREEN_W);
    if (FSelectedChapterIndex >= 0) and (FSelectedChapterIndex <
      Length(FRenderer.Chapters)) then
      FRenderer.ScrollY := FRenderer.Chapters[FSelectedChapterIndex].StartY
    else
    begin
      if FRenderer.MaxScroll > 0 then FRenderer.ScrollY := ScrollRatio * FRenderer.MaxScroll
      else
        FRenderer.ScrollY := 0;
    end;
    if FRenderer.ScrollY < 0 then FRenderer.ScrollY := 0;
    if FRenderer.ScrollY > FRenderer.MaxScroll then FRenderer.ScrollY := FRenderer.MaxScroll;
  end;
  VisibleH := Height;
  BeginScissorMode(0, 0, Width, Trunc(VisibleH));
  for i := 0 to Length(FRenderer.Lines) - 1 do
  begin
    Line := FRenderer.Lines[i];
    ScreenY := Line.YPos - FRenderer.ScrollY;

    // ИСПОЛЬЗУЕМ Line.LineHeight для точного отсечения
    if (ScreenY + Line.LineHeight > 0) and (ScreenY < Height) then
    begin
      case Line.ElemType of
        etTitle:
        begin
          CurrentFont := FRenderer.TitleFont;
          FontSize := FONT_SIZE;
          Spacing := 0.5;
          TxtColor := FTitleColor;
        end;
        etSubtitle:
        begin
          CurrentFont := FRenderer.SubtitleFont;
          FontSize := FONT_SIZE;
          Spacing := 0.5;
          TxtColor := FSubtitleColor;
        end;
        etVerse, etEmphasis:
        begin
          CurrentFont := FRenderer.SubtitleFont;
          FontSize := FONT_SIZE;
          Spacing := 0.5;
          TxtColor := FVerseColor;
        end;
        else
        begin
          CurrentFont := FRenderer.Font;
          FontSize := FONT_SIZE;
          Spacing := 0.5;
          TxtColor := FNormalColor;
        end;
      end;
      PosVec := Vector2Create(Line.XPos, ScreenY);
      if Line.ElemType in [etTitle, etSubtitle] then
      begin
        TextSize_ := MeasureTextEx(CurrentFont, pansichar(Line.Text), FontSize, Spacing);
        PosVec.X := (Width - TextSize_.x) / 2;
      end;
      if CurrentFont.texture.id <> 0 then
        DrawTextEx(CurrentFont, pansichar(Line.Text), PosVec, FontSize, Line.Spacing, TxtColor);
    end;
  end;
  for i := 0 to Length(FRenderer.Images) - 1 do
  begin
    Img := FRenderer.Images[i];
    ImgScreenY := Img.YPos - FRenderer.ScrollY;
    if (ImgScreenY + Img.Height > 0) and (ImgScreenY < Height) and (Img.Texture.id <> 0) then
    begin
      SrcRect := RectangleCreate(0, 0, Img.Width, Img.Height);
      DstRect := RectangleCreate(Img.XPos, ImgScreenY, Img.Width, Img.Height);
      DrawTexturePro(Img.Texture, SrcRect, DstRect, Vector2Create(0, 0), 0, WHITE);
    end;
  end;
  EndScissorMode();
  if FRenderer.MaxScroll > 0.0 then Progress := FRenderer.ScrollY / FRenderer.MaxScroll
  else
    Progress := 0.0;
  BarH := 6.0;
  BarY := Height - BarH;
  FillW := Width * Progress;
  DrawRectangle(0, Round(BarY), Width, Round(BarH), FProgressColorBack);
  DrawRectangle(0, Round(BarY), Round(FillW), Round(BarH), FProgressColor);
end;

function TFB2Reader.ParseInternal(const FileName: string;
  var Title_, Author_: string): TFB2ElementArray;
var
  Content, RawTag, TagName, AttrVal, BinId, BinData: string;
  i, j, k, PEnd, BStart, BEnd, idx: integer;
  InBody: boolean;
  InTitle: boolean;
  SectDepth: integer;
  Elem: TFB2Element;
  FS: TFileStream;
  BinMap: TBinaryList;
  CoverPos, ImgPos, HrefPos, CoverIdEndPos: integer;
  CoverID: string;
  CoverTexture: TTexture2D;
begin
  SetLength(Result, 0);
  SetLength(BinMap, 0);
  Title_ := '';
  Author_ := '';
  CoverTexture.id := 0;
  InBody := False;
  SectDepth := 0;
  InTitle := False;
  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Content, FS.Size);
      if FS.Size > 0 then FS.ReadBuffer(Content[1], FS.Size);
    finally
      FS.Free;
    end;
    ConvertEncodingIfNeeded(Content);
    Content := StringReplace(Content, #0, '', [rfReplaceAll]);

    // <binary>
    j := 1;
    while j <= Length(Content) do
    begin
      j := FindSubStr('<binary', Content, j);
      if j = 0 then Break;
      i := FindSubStr('id="', Content, j);
      if i = 0 then i := FindSubStr('id=''', Content, j);
      if i > 0 then
      begin
        Inc(i, 4);
        PEnd := Pos('"', Content, i);
        if PEnd = 0 then PEnd := Pos('''', Content, i);
        if (PEnd > i) and (PEnd <= Length(Content)) then
        begin
          BinId := Copy(Content, i, PEnd - i);
          BStart := FindSubStr('>', Content, j);
          if (BStart > 0) and (BStart < Length(Content)) then
          begin
            BEnd := FindSubStr('</binary>', Content, BStart + 1);
            if (BEnd > BStart) and (BEnd <= Length(Content)) then
            begin
              BinData := Copy(Content, BStart + 1, BEnd - BStart - 1);
              BinData := StringReplace(BinData, #10, '', [rfReplaceAll]);
              BinData := StringReplace(BinData, #13, '', [rfReplaceAll]);
              BinData := StringReplace(BinData, #9, '', [rfReplaceAll]);
              BinData := StringReplace(BinData, ' ', '', [rfReplaceAll]);
              if Length(BinData) > 50 then
              begin
                SetLength(BinMap, Length(BinMap) + 1);
                BinMap[High(BinMap)].Id := BinId;
                BinMap[High(BinMap)].Data := BinData;
              end;
            end
            else
              Break;
          end;
        end;
      end;
      j := FindSubStr('</binary>', Content, j);
      if j <= 0 then Break;
      Inc(j, 9);
    end;

    // Обложка
    CoverPos := Pos('<coverpage>', Content);
    if CoverPos > 0 then
    begin
      ImgPos := Pos('<image', Content, CoverPos);
      if (ImgPos > CoverPos) and (ImgPos < CoverPos + 1000) then
      begin
        HrefPos := Pos('href="#', Content, ImgPos);
        if HrefPos = 0 then HrefPos := Pos('l:href="#', Content, ImgPos);
        if HrefPos = 0 then HrefPos := Pos('xlink:href="#', Content, ImgPos);
        if HrefPos > 0 then
        begin
          HrefPos := Pos('#', Content, HrefPos);
          if HrefPos > 0 then
          begin
            Inc(HrefPos);
            CoverIdEndPos := Pos('"', Content, HrefPos);
            if CoverIdEndPos = 0 then CoverIdEndPos := Pos('''', Content, HrefPos);
            if (CoverIdEndPos > HrefPos) and (CoverIdEndPos <= Length(Content)) then
            begin
              CoverID := Copy(Content, HrefPos, CoverIdEndPos - HrefPos);
              for idx := 0 to High(BinMap) do
              begin
                if BinMap[idx].Id = CoverID then
                begin
                  CoverTexture := LoadTextureFromBase64(BinMap[idx].Data);
                  Break;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    // Метаданные
    j := Pos('<book-title>', Content);
    if j > 0 then
    begin
      j := j + Length('<book-title>');
      k := Pos('</book-title>', Content, j);
      if k > j then Title_ := DecodeXMLEntities(Trim(Copy(Content, j, k - j)));
    end;
    j := Pos('<first-name>', Content);
    if j > 0 then
    begin
      k := Pos('</first-name>', Content, j);
      if k > j then Author_ := DecodeXMLEntities(
          Trim(Copy(Content, j + Length('<first-name>'), k - j - Length('<first-name>')))) + ' ';
      j := Pos('<last-name>', Content);
      if j > 0 then
      begin
        k := Pos('</last-name>', Content, j);
        if k > j then Author_ := Author_ +
            DecodeXMLEntities(Trim(Copy(Content, j + Length('<last-name>'), k -
            j - Length('<last-name>'))));
      end;
    end;

    // <body>
    j := Pos('<body>', Content);
    if j = 0 then j := Pos('<body ', Content);
    if j > 0 then
    begin
      j := Pos('>', Content, j) + 1;
      InBody := True;
    end;
    while InBody and (j <= Length(Content)) do
    begin
      if Content[j] = '<' then
      begin
        k := Pos('>', Content, j);
        if k = 0 then Break;
        RawTag := Trim(Copy(Content, j + 1, k - j - 1));
        if Pos('/', RawTag) = 1 then
        begin
          TagName := Trim(Copy(RawTag, 2, Length(RawTag) - 1));
          if TagName = 'section' then Dec(SectDepth);
          if TagName = 'body' then InBody := False;
          if TagName = 'title' then InTitle := False;
        end
        else
        begin
          TagName := '';
          i := 1;
          while (i <= Length(RawTag)) and (RawTag[i] <> ' ') and (RawTag[i] <> '/') and
            (RawTag[i] <> '>') do
          begin
            TagName := TagName + RawTag[i];
            Inc(i);
          end;
          if TagName = 'binary' then
          begin
            BEnd := FindSubStr('</binary>', Content, j);
            if BEnd > 0 then j := BEnd + Length('</binary>') - 1
            else
              Break;
          end
          else if TagName = 'image' then
          begin
            i := Pos('href="#', RawTag);
            if i = 0 then i := Pos('href=''', RawTag);
            if i = 0 then i := Pos('l:href="#', RawTag);
            if i = 0 then i := Pos('xlink:href="#', RawTag);
            if i > 0 then
            begin
              i := Pos('#', RawTag, i);
              if i > 0 then
              begin
                Inc(i);
                PEnd := Pos('"', RawTag, i);
                if PEnd = 0 then PEnd := Pos('''', RawTag, i);
                if (PEnd > i) and (PEnd <= Length(RawTag)) then
                begin
                  AttrVal := Copy(RawTag, i, PEnd - i);
                  for idx := 0 to High(BinMap) do
                  begin
                    if BinMap[idx].Id = AttrVal then
                    begin
                      SetLength(Result, Length(Result) + 1);
                      Result[High(Result)].ElemType := etImage;
                      Result[High(Result)].ImageTex := LoadTextureFromBase64(BinMap[idx].Data);
                      Result[High(Result)].ImageLoaded := (Result[High(Result)].ImageTex.id <> 0);
                      if Result[High(Result)].ImageLoaded then
                      begin
                        Result[High(Result)].ImgW := Result[High(Result)].ImageTex.Width;
                        Result[High(Result)].ImgH := Result[High(Result)].ImageTex.Height;
                      end
                      else
                      begin
                        Result[High(Result)].ImgW := MAX_IMG_W;
                        Result[High(Result)].ImgH := MAX_IMG_H;
                      end;
                      Break;
                    end;
                  end;
                end;
              end;
            end;
          end
          else if TagName = 'title' then
          begin
            InTitle := True;
            Elem := Default(TFB2Element);
            Elem.ElemType := etTitle;
            Elem.Indent := SectDepth;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'subtitle' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etSubtitle;
            Elem.Indent := SectDepth;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'poem' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etEmptyLine;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'stanza' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etEmptyLine;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'v' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etVerse;
            Elem.Indent := 0;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'emphasis' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etEmphasis;
            Elem.Indent := 0;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'p' then
          begin
            Elem := Default(TFB2Element);
            if InTitle then Elem.ElemType := etTitle
            else
              Elem.ElemType := etParagraph;
            Elem.Indent := SectDepth;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'empty-line' then
          begin
            Elem := Default(TFB2Element);
            Elem.ElemType := etEmptyLine;
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Elem;
          end
          else if TagName = 'section' then Inc(SectDepth);
        end;
        j := k + 1;
      end
      else
      begin
        if Length(Result) > 0 then
        begin
          k := j;
          while (k <= Length(Content)) and (Content[k] <> '<') do Inc(k);
          if Result[High(Result)].ElemType in [etTitle, etSubtitle, etParagraph,
            etVerse, etEmphasis] then
            Result[High(Result)].Text := Result[High(Result)].Text +
              DecodeXMLEntities(Copy(Content, j, k - j));
          j := k;
        end
        else
          Inc(j);
      end;
    end;

    // Вставляем обложку в начало
    if CoverTexture.id <> 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      for idx := Length(Result) - 1 downto 1 do Result[idx] := Result[idx - 1];
      Result[0].ElemType := etCover;
      Result[0].ImageTex := CoverTexture;
      Result[0].ImageLoaded := True;
      Result[0].ImgW := CoverTexture.Width;
      Result[0].ImgH := CoverTexture.Height;
    end;
  except
    on E: Exception do WriteLn('Parse error: ', E.Message);
  end;
end;

function TFB2Reader.GetChapters: TFB2ChapterArray;
begin
  Result := FRenderer.Chapters;
end;

// ИСПРАВЛЕНИЕ 3: Динамический расчет высоты строки (FontSize * 1.35)
procedure TFB2Reader.LayoutInternal(Width: integer);
var
  i, wc: integer;
  Words: TStringList;
  CurLine, LineText: string;
  LineSize: TVector2;
  CurY: single;
  Elem: TFB2Element;
  FontSize, DefSpacing, JustifySpacing, TargetWidth, MeasuredWidth, LineStep: single;
  CurrentFont: TFont;
begin
  Words := TStringList.Create;
  Words.Delimiter := ' ';
  Words.StrictDelimiter := True;
  Words.QuoteChar := #0;
  CurY := PADDING_Y;
  TargetWidth := Width - PADDING_X * 2;
  DefSpacing := 0.5;
  SetLength(FRenderer.Lines, 0);
  SetLength(FRenderer.Images, 0);
  SetLength(FRenderer.Chapters, 0);

  for i := 0 to Length(FRenderer.Elements) - 1 do
  begin
    Elem := FRenderer.Elements[i];
    CurLine := '';
    FontSize := FONT_SIZE;

    if (Elem.ElemType = etTitle) or (Elem.ElemType = etSubtitle) then
    begin
      if (Elem.ElemType = etTitle) and (Trim(Elem.Text) <> '') then
      begin
        SetLength(FRenderer.Chapters, Length(FRenderer.Chapters) + 1);
        FRenderer.Chapters[High(FRenderer.Chapters)].Title := Trim(Elem.Text);
        FRenderer.Chapters[High(FRenderer.Chapters)].Level := Elem.Indent;
        FRenderer.Chapters[High(FRenderer.Chapters)].StartY := CurY;
      end;
      if Elem.ElemType = etTitle then CurrentFont := FRenderer.TitleFont
      else
        CurrentFont := FRenderer.SubtitleFont;

      // НАДЕЖНЫЙ РАСЧЕТ ВЫСОТЫ СТРОКИ
      LineStep := FontSize * 1.35;
      if LineStep < 20.0 then LineStep := 20.0;

      Words.DelimitedText := Elem.Text;
      wc := 0;
      while wc < Words.Count do
      begin
        LineText := CurLine + Words[wc];
        LineSize := MeasureTextEx(CurrentFont, pansichar(LineText), FontSize, DefSpacing);
        if (CurLine <> '') and (LineSize.x > TargetWidth - 20) then
        begin
          SetLength(FRenderer.Lines, Length(FRenderer.Lines) + 1);
          FRenderer.Lines[High(FRenderer.Lines)].Text := CurLine;
          FRenderer.Lines[High(FRenderer.Lines)].YPos := CurY;
          FRenderer.Lines[High(FRenderer.Lines)].ElemType := Elem.ElemType;
          FRenderer.Lines[High(FRenderer.Lines)].XPos := PADDING_X;
          FRenderer.Lines[High(FRenderer.Lines)].Spacing := DefSpacing;
          FRenderer.Lines[High(FRenderer.Lines)].LineHeight := LineStep; // <-- СОХРАНЯЕМ

          CurY := CurY + LineStep; // <-- ИСПОЛЬЗУЕМ НАДЕЖНЫЙ ШАГ
          CurLine := Words[wc] + ' ';
        end
        else
          CurLine := LineText + ' ';
        Inc(wc);
      end;
      if CurLine <> '' then
      begin
        SetLength(FRenderer.Lines, Length(FRenderer.Lines) + 1);
        FRenderer.Lines[High(FRenderer.Lines)].Text := CurLine;
        FRenderer.Lines[High(FRenderer.Lines)].YPos := CurY;
        FRenderer.Lines[High(FRenderer.Lines)].ElemType := Elem.ElemType;
        FRenderer.Lines[High(FRenderer.Lines)].XPos := PADDING_X;
        FRenderer.Lines[High(FRenderer.Lines)].Spacing := DefSpacing;
        FRenderer.Lines[High(FRenderer.Lines)].LineHeight := LineStep; // <-- СОХРАНЯЕМ

        CurY := CurY + LineStep; // <-- ИСПОЛЬЗУЕМ НАДЕЖНЫЙ ШАГ
      end;
      CurY := CurY + 8;
    end
    else if (Elem.ElemType = etParagraph) or (Elem.ElemType = etVerse) or
      (Elem.ElemType = etEmphasis) then
    begin
      CurrentFont := FRenderer.Font;
      Words.DelimitedText := Elem.Text;
      if Words.Count > 0 then
      begin
        // НАДЕЖНЫЙ РАСЧЕТ ВЫСОТЫ СТРОКИ
        LineStep := FontSize * 1.35;
        if LineStep < 20.0 then LineStep := 20.0;

        wc := 0;
        while wc < Words.Count do
        begin
          LineText := CurLine + Words[wc];
          LineSize := MeasureTextEx(CurrentFont, pansichar(LineText), FontSize, DefSpacing);
          if (CurLine <> '') and (LineSize.x > TargetWidth) then
          begin
            SetLength(FRenderer.Lines, Length(FRenderer.Lines) + 1);
            FRenderer.Lines[High(FRenderer.Lines)].Text := CurLine;
            FRenderer.Lines[High(FRenderer.Lines)].YPos := CurY;
            FRenderer.Lines[High(FRenderer.Lines)].ElemType := Elem.ElemType;
            FRenderer.Lines[High(FRenderer.Lines)].XPos := PADDING_X;
            FRenderer.Lines[High(FRenderer.Lines)].LineHeight := LineStep; // <-- СОХРАНЯЕМ

            MeasuredWidth := MeasureTextEx(CurrentFont, pansichar(CurLine), FontSize, DefSpacing).x;
            if (MeasuredWidth < TargetWidth) and (Length(CurLine) > 6) then
            begin
              JustifySpacing := DefSpacing + (TargetWidth - MeasuredWidth) / (Length(CurLine) - 1);
              if JustifySpacing > DefSpacing * 2.5 then JustifySpacing := DefSpacing * 2.5;
            end
            else
              JustifySpacing := DefSpacing;
            FRenderer.Lines[High(FRenderer.Lines)].Spacing := JustifySpacing;

            CurY := CurY + LineStep; // <-- ИСПОЛЬЗУЕМ НАДЕЖНЫЙ ШАГ
            CurLine := Words[wc] + ' ';
          end
          else
            CurLine := LineText + ' ';
          Inc(wc);
        end;
        if CurLine <> '' then
        begin
          SetLength(FRenderer.Lines, Length(FRenderer.Lines) + 1);
          FRenderer.Lines[High(FRenderer.Lines)].Text := CurLine;
          FRenderer.Lines[High(FRenderer.Lines)].YPos := CurY;
          FRenderer.Lines[High(FRenderer.Lines)].ElemType := Elem.ElemType;
          FRenderer.Lines[High(FRenderer.Lines)].XPos := PADDING_X;
          FRenderer.Lines[High(FRenderer.Lines)].Spacing := DefSpacing;
          FRenderer.Lines[High(FRenderer.Lines)].LineHeight := LineStep; // <-- СОХРАНЯЕМ

          CurY := CurY + LineStep; // <-- ИСПОЛЬЗУЕМ НАДЕЖНЫЙ ШАГ
        end;
      end;
    end
    else if Elem.ElemType = etEmptyLine then
    begin
      LineStep := FontSize * 1.35;
      if LineStep < 20.0 then LineStep := 20.0;
      CurY := CurY + (LineStep * 0.6);
    end
    else if (Elem.ElemType = etImage) or (Elem.ElemType = etCover) then
    begin
      if Elem.ImageLoaded then
      begin
        SetLength(FRenderer.Images, Length(FRenderer.Images) + 1);
        FRenderer.Images[High(FRenderer.Images)].Texture := Elem.ImageTex;
        FRenderer.Images[High(FRenderer.Images)].XPos := (Width - Elem.ImgW) / 2;
        FRenderer.Images[High(FRenderer.Images)].YPos := CurY;
        FRenderer.Images[High(FRenderer.Images)].Width := Elem.ImgW;
        FRenderer.Images[High(FRenderer.Images)].Height := Elem.ImgH;
        CurY := CurY + Elem.ImgH + 15;
      end;
    end;
    if Elem.Indent > 0 then CurY := CurY + 8;
  end;
  FRenderer.TotalHeight := CurY + PADDING_Y;
  FRenderer.MaxScroll := Max(0.0, FRenderer.TotalHeight - FSCREEN_H);
  if FRenderer.ScrollY < 0.0 then FRenderer.ScrollY := 0.0;
  if FRenderer.ScrollY > FRenderer.MaxScroll then FRenderer.ScrollY := FRenderer.MaxScroll;
  Words.Free;
end;

end.
