unit gui.booknotes;

{$mode ObjFPC}{$H+}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout, rlgui.components, ReaderTools, math, fb2Reader;

type

  { TNoteList }

  TNoteList = class(TControl)
  private
    FColor: TColorB;
    FDrawSelection: Boolean;
    FNotes: TBookNoteArray;
    FScrollY: Single;
    FMaxScroll: Single;
    FFont: TFont;
    FFontLoaded: Boolean;
    FFontSize: Integer;
    FFontSpacing: Single;
    FLineHeight: Single;
    FTitleColor: TColorB;
    FTextColor: TColorB;
    FHighlightColor: TColorB;
    FScrollBarColor: TColorB;
    FScrollBarBackColor: TColorB;
    FSelectedNote: Integer;
    FOnNoteSelected: TIntegerEvent;
    FItemPadding: Integer;
    FShowScrollBar: Boolean;
    FMaxLineWidth: Single;
    procedure UpdateMaxScroll;
    function GetVisibleHeight: Single;
    function GetNoteItemHeight(Index: Integer; MaxW: Single): Single;
    function WrapText(const Text: string; MaxWidth: Single; out Lines: TStringList): Integer;
    procedure UpdateKeyboardScroll;
  protected
    procedure Paint; override;
    procedure UpdateScroll(WheelDelta: Single);
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure SetNotes(const Notes: TBookNoteArray);
    procedure ClearNotes;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure UpdateMouseScroll;
    procedure InvertColors;
    property Notes: TBookNoteArray read FNotes write SetNotes;
    property FontSize: Integer read FFontSize write FFontSize;
    property FontSpacing: Single read FFontSpacing write FFontSpacing;
    property TitleColor: TColorB read FTitleColor write FTitleColor;
    property TextColor: TColorB read FTextColor write FTextColor;
    property HighlightColor: TColorB read FHighlightColor write FHighlightColor;
    property ScrollBarColor: TColorB read FScrollBarColor write FScrollBarColor;
    property ScrollBarBackColor: TColorB read FScrollBarBackColor write FScrollBarBackColor;
    property Color: TColorB read FColor write FColor;
    property ItemPadding: Integer read FItemPadding write FItemPadding;
    property ShowScrollBar: Boolean read FShowScrollBar write FShowScrollBar;
    property SelectedNote: Integer read FSelectedNote;
    property OnNoteSelected: TIntegerEvent read FOnNoteSelected write FOnNoteSelected;
    property DrawSelection: Boolean read FDrawSelection write FDrawSelection;
  end;

implementation

{ TNoteList }

constructor TNoteList.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 300;
  Height := 400;
  Top := 10;
  Left := 10;

  FNotes := nil;
  FScrollY := 0;
  FMaxScroll := 0;
  FFontLoaded := False;
  FFontSize := 16;
  FFontSpacing := 0.5;
  FLineHeight := FFontSize * 1.5;
  FSelectedNote := -1;
  FItemPadding := 8;
  FShowScrollBar := True;
  FMaxLineWidth := 0;
  FColor := RayWhite;
  FTitleColor := ColorCreate(40, 40, 70, 255);
  FTextColor := ColorCreate(60, 60, 70, 255);
  FHighlightColor := ColorCreate(200, 200, 220, 100);
  FScrollBarColor := ColorCreate(150, 150, 160, 200);
  FScrollBarBackColor := ColorCreate(220, 220, 230, 100);
  FDrawSelection := True;
  FillChar(FFont, SizeOf(TFont), 0);
end;

destructor TNoteList.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);
  inherited Destroy;
end;

procedure TNoteList.SetNotes(const Notes: TBookNoteArray);
begin
  FNotes := Notes;
  FScrollY := 0;
  FSelectedNote := -1;
  UpdateMaxScroll;
end;

procedure TNoteList.ClearNotes;
begin
  SetLength(FNotes, 0);
  FScrollY := 0;
  FSelectedNote := -1;
  FMaxScroll := 0;
end;

procedure TNoteList.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);

  FFontSize := Size;
  FLineHeight := Size * 1.5;

  if SysUtils.FileExists(FontPath) then
  begin
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;

  UpdateMaxScroll;
end;

function TNoteList.GetVisibleHeight: Single;
begin
  Result := Height - FItemPadding * 2;
  if Result < FLineHeight then Result := FLineHeight;
end;

// Безопасный перенос текста без обрезки байт UTF-8
function TNoteList.WrapText(const Text: string; MaxWidth: Single; out Lines: TStringList): Integer;
var
  Words: TStringList;
  LineText, NewLine: string;
  LineSize: TVector2;
  WordIdx: Integer;
  CurrentFont: TFont;
  LocalFontSize, LocalSpacing: Single;
begin
  Lines := TStringList.Create;
  Words := TStringList.Create;
  try
    Words.Delimiter := ' ';
    Words.StrictDelimiter := True;
    Words.QuoteChar := #0;
    Words.DelimitedText := Text;

    if FFontLoaded and (FFont.texture.id <> 0) then
    begin
      CurrentFont := FFont;
      LocalFontSize := FFontSize;
      LocalSpacing := FFontSpacing;
    end
    else
    begin
      CurrentFont.texture.id := 0;
      LocalFontSize := FFontSize;
      LocalSpacing := 0;
    end;

    LineText := '';
    for WordIdx := 0 to Words.Count - 1 do
    begin
      if LineText = '' then
        NewLine := Words[WordIdx]
      else
        NewLine := LineText + ' ' + Words[WordIdx];

      if CurrentFont.texture.id <> 0 then
        LineSize := MeasureTextEx(CurrentFont, PAnsiChar(NewLine), LocalFontSize, LocalSpacing)
      else
        LineSize := Vector2Create(MeasureText(PAnsiChar(NewLine), Round(LocalFontSize)), LocalFontSize);

      if LineSize.x > MaxWidth then
      begin
        if LineText <> '' then
        begin
          Lines.Add(LineText);
          LineText := Words[WordIdx];
        end
        else
        begin
          // Одно длинное слово не влезает → добавляем как есть
          Lines.Add(Words[WordIdx]);
          LineText := '';
        end;
      end
      else
        LineText := NewLine;
    end;

    if LineText <> '' then Lines.Add(LineText);
    Result := Lines.Count;
  finally
    Words.Free;
  end;
end;

// Вычисляет точную высоту записи
function TNoteList.GetNoteItemHeight(Index: Integer; MaxW: Single): Single;
var
  Lines: TStringList;
  LineCount: Integer;
  NoteText: string;
begin
  if (Index < 0) or (Index >= Length(FNotes)) then
  begin
    Result := FLineHeight + FItemPadding;
    Exit;
  end;

  NoteText := Trim(FNotes[Index].Text);
  if NoteText = '' then
    Result := FLineHeight + FItemPadding
  else
  begin
    LineCount := WrapText(NoteText, MaxW, Lines);
    Lines.Free;
    // Заголовок (1) + Текст (N строк) + Отступ снизу
    Result := FLineHeight + (LineCount * FLineHeight) + FItemPadding;
  end;
end;

procedure TNoteList.UpdateMaxScroll;
var
  TotalHeight: Single;
  i: Integer;
  ItemH: Single;
begin
  TotalHeight := FItemPadding; // Верхний отступ
  FMaxLineWidth := Width - FItemPadding - 18; // Точная ширина текста
  if FMaxLineWidth < 50 then FMaxLineWidth := 50;

  for i := 0 to Length(FNotes) - 1 do
  begin
    ItemH := GetNoteItemHeight(i, FMaxLineWidth);
    TotalHeight := TotalHeight + ItemH;
  end;

  TotalHeight := TotalHeight + FItemPadding; // Нижний отступ

  FMaxScroll := Max(0, TotalHeight - GetVisibleHeight);
  if FScrollY > FMaxScroll then FScrollY := FMaxScroll;
  if FScrollY < 0 then FScrollY := 0;
end;

procedure TNoteList.UpdateScroll(WheelDelta: Single);
begin
  FScrollY := FScrollY - WheelDelta * FLineHeight;
  if FScrollY < 0 then FScrollY := 0;
  if FScrollY > FMaxScroll then FScrollY := FMaxScroll;
end;

procedure TNoteList.UpdateMouseScroll;
var
  Wheel: Single;
begin
  Wheel := GetMouseWheelMove();
  if Wheel <> 0 then UpdateScroll(Wheel);
end;

procedure TNoteList.InvertColors;
begin
  TitleColor := InvertColor(TitleColor);
  Color := InvertColor(Color);
  HighlightColor := InvertColor(HighlightColor);
  TextColor := InvertColor(TextColor);
  ScrollBarColor := InvertColor(ScrollBarColor);
  ScrollBarBackColor := InvertColor(ScrollBarBackColor);
end;

// ← НОВАЯ ПРОЦЕДУРА: Обработка клавиатуры
procedure TNoteList.UpdateKeyboardScroll;
var
  PageStep: Single;
begin
  if IsKeyPressed(KEY_UP) or IsKeyPressedRepeat(KEY_UP) then
    UpdateScroll(1.0)
  else if IsKeyPressed(KEY_DOWN) or IsKeyPressedRepeat(KEY_DOWN) then
    UpdateScroll(-1.0)
  else if IsKeyPressed(KEY_PAGE_UP) then
  begin
    PageStep := GetVisibleHeight / FLineHeight;
    if PageStep < 1.0 then PageStep := 1.0;
    UpdateScroll(PageStep);
  end
  else if IsKeyPressed(KEY_PAGE_DOWN) then
  begin
    PageStep := GetVisibleHeight / FLineHeight;
    if PageStep < 1.0 then PageStep := 1.0;
    UpdateScroll(-PageStep);
  end;
end;

procedure TNoteList.Paint;
var
  i: Integer;
  CurrentY, ScreenY, DrawX, ItemHeight: Single;
  NoteRect: TRectangle;
  MousePoint: TVector2;
  TitleText, BodyText: string;
  BodyLines: TStringList;
  LineIdx: Integer;
  ScrollBarHeight, ScrollBarY, ScrollBarWidth: Single;
  VisibleTop, VisibleBottom: Single;
begin
  if FFontLoaded and (FFont.texture.id = 0) then FFontLoaded := False;

  // Обновляем ввод
  UpdateMouseScroll;
  UpdateKeyboardScroll;

  // Фон и рамка
  DrawRectangle(Left, Top, Width, Height, FColor);


  BeginScissorMode(Left, Top, Width, Height);

  CurrentY := Top + FItemPadding - FScrollY;
  DrawX := Left + FItemPadding;
  MousePoint := GetMousePosition;

  FMaxLineWidth := Width - FItemPadding - 18;
  if FMaxLineWidth < 50 then FMaxLineWidth := 50;

  VisibleTop := Top;
  VisibleBottom := Top + Height;

  for i := 0 to Length(FNotes) - 1 do
  begin
    ItemHeight := GetNoteItemHeight(i, FMaxLineWidth);
    ScreenY := CurrentY;

    // Пропуск невидимых записей
    if (ScreenY + ItemHeight < VisibleTop) or (ScreenY > VisibleBottom) then
    begin
      CurrentY := CurrentY + ItemHeight;
      Continue;
    end;

    // Область клика
    NoteRect := RectangleCreate(Left + 2, ScreenY, Width - 4, ItemHeight);

    if CheckCollisionPointRec(MousePoint, NoteRect) then
    begin
      if FDrawSelection then
      DrawRectangle(Round(NoteRect.x), Round(NoteRect.y),
                    Round(NoteRect.width), Round(NoteRect.height),
                    FHighlightColor);

      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      begin
        FSelectedNote := i;
        if Assigned(FOnNoteSelected) then FOnNoteSelected(Self, i);
      end;
    end;

    if (FSelectedNote = i) and FDrawSelection then
      DrawRectangle(Round(NoteRect.x), Round(NoteRect.y),
                    Round(NoteRect.width), Round(NoteRect.height),
                    ColorCreate(180, 180, 220, 100));

    // Заголовок
    TitleText := FNotes[i].Title;
    if TitleText = '' then TitleText := '[' + IntToStr(i + 1) + ']';

    if FFontLoaded and (FFont.texture.id <> 0) then
      DrawTextEx(FFont, PAnsiChar(TitleText), Vector2Create(DrawX, ScreenY),
                 FFontSize, FFontSpacing, FTitleColor)
    else
      DrawText(PAnsiChar(TitleText), Left + Round(FItemPadding), Round(ScreenY),
               FFontSize, FTitleColor);

    // Текст сноски
    BodyText := Trim(FNotes[i].Text);
    if BodyText <> '' then
    begin
      BodyLines := nil;
      try
        WrapText(BodyText, FMaxLineWidth, BodyLines);
        ScreenY := ScreenY + FLineHeight; // Отступ после заголовка

        for LineIdx := 0 to BodyLines.Count - 1 do
        begin
          if (ScreenY + FLineHeight > VisibleTop) and (ScreenY < VisibleBottom) then
          begin
            if FFontLoaded and (FFont.texture.id <> 0) then
              DrawTextEx(FFont, PAnsiChar(BodyLines[LineIdx]),
                         Vector2Create(DrawX {+ 10}, ScreenY),
                         FFontSize, FFontSpacing, FTextColor)
            else
              DrawText(PAnsiChar(BodyLines[LineIdx]),
                       Left + Round(FItemPadding) {+ 10}, Round(ScreenY),
                       FFontSize, FTextColor);
          end;
          ScreenY := ScreenY + FLineHeight;
        end;
      finally
        if Assigned(BodyLines) then BodyLines.Free;
      end;
    end;

    // Переход к следующей записи на ВЫЧИСЛЕННУЮ высоту
    CurrentY := CurrentY + ItemHeight;
  end;

  EndScissorMode();

  // Полоса прокрутки
  if FShowScrollBar and (FMaxScroll > 0) then
  begin
    ScrollBarWidth := 8;
    ScrollBarHeight := Max(20, (GetVisibleHeight / (GetVisibleHeight + FMaxScroll)) * GetVisibleHeight);
    ScrollBarY := Top + (FScrollY / FMaxScroll) * (GetVisibleHeight - ScrollBarHeight);

    DrawRectangle(Left + Width - Round(ScrollBarWidth), Top,
                  Round(ScrollBarWidth), Height, FScrollBarBackColor);
    DrawRectangle(Left + Width - Round(ScrollBarWidth), Round(ScrollBarY),
                  Round(ScrollBarWidth), Round(ScrollBarHeight), FScrollBarColor);
  end;
end;

end.
