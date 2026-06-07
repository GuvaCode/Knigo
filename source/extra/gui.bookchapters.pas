unit gui.bookchapters;

{$mode ObjFPC}{$H+}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout, rlgui.components, ReaderTools, math,
  fb2Reader;

type
  { Событие выбора главы }
  TChapterSelectedEvent = procedure(ChapterIndex: Integer; StartY: Single) of object;

  { Список глав }
  TChapterList = class(TControl)
  private
    FChapters: TFB2ChapterArray;
    FScrollY: Single;
    FMaxScroll: Single;
    FFont: TFont;
    FFontLoaded: Boolean;
    FFontSize: Integer;
    FSpacing: Single;
    FLineHeight: Single;
    FTitleColor: TColorB;
    FTextColor: TColorB;
    FHighlightColor: TColorB;
    FScrollBarColor: TColorB;
    FScrollBarBackColor: TColorB;
    FSelectedIndex: Integer;
    FOnChapterClick: TNotifyEvent;
    FItemPadding: Integer;
    FShowScrollBar: Boolean;
    FMouseDown: Boolean;
    FMouseDownY: Single;
    FScrollStart: Single;
    FWheelAccum: Single;
    procedure UpdateMaxScroll;
    function GetVisibleHeight: Single;
    procedure UpdateScroll(WheelDelta: Single);
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure SetChapters(const Chapters: TFB2ChapterArray);
    procedure ClearChapters;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure InvertColors;
    procedure ScrollToChapter(Index: Integer);
    procedure HandleKeyboard; // 🔑 Обработка клавиатуры
    property Chapters: TFB2ChapterArray read FChapters write SetChapters;
    property FontSize: Integer read FFontSize write FFontSize;
    property FontSpacing: Single read FSpacing write FSpacing;
    property TitleColor: TColorB read FTitleColor write FTitleColor;
    property TextColor: TColorB read FTextColor write FTextColor;
    property HighlightColor: TColorB read FHighlightColor write FHighlightColor;
    property ScrollBarColor: TColorB read FScrollBarColor write FScrollBarColor;
    property ScrollBarBackColor: TColorB read FScrollBarBackColor write FScrollBarBackColor;
    property ItemPadding: Integer read FItemPadding write FItemPadding;
    property ShowScrollBar: Boolean read FShowScrollBar write FShowScrollBar;
    property SelectedIndex: Integer read FSelectedIndex write FSelectedIndex;
    property OnChapterClick: TNotifyEvent read FOnChapterClick write FOnChapterClick;
  end;

  { Панель оглавления }
  TChaptersPanel = class(TControl)
  private
    FBackgroundColor: TColorB;
    FCloseButton: TImageButton;
    FFont: TFont;
    FFontLoaded: Boolean;
    FOnButtonClick: TNotifyEvent;
    FOverlayColor: TColorB;
    FTitle: String;
    FTitleColor: TColorB;
    FFontSize: Integer;
    FShowOverlay: Boolean;
    FChapterList: TChapterList;
    FChapters: TFB2ChapterArray;
    FOnChapterSelected: TChapterSelectedEvent;
    procedure SetOnButtonClick(AValue: TNotifyEvent);
    procedure OnChapterItemClick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure InvertColors;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure SetChapters(Reader: TFB2Reader);
    procedure UpdateScrollY(CurrentY: Single);
    procedure UpdateKeyboardScroll;
    property OnButtonClick: TNotifyEvent read FOnButtonClick write SetOnButtonClick;
    property CloseButton: TImageButton read FCloseButton write FCloseButton;
    property BackgroundColor: TColorB read FBackgroundColor write FBackgroundColor;
    property Font: TFont read FFont write FFont;
    property Title: String read FTitle write FTitle;
    property TitleColor: TColorB read FTitleColor write FTitleColor;
    property OverlayColor: TColorB read FOverlayColor write FOverlayColor;
    property ShowOverlay: Boolean read FShowOverlay write FShowOverlay;
    property OnChapterSelected: TChapterSelectedEvent read FOnChapterSelected write FOnChapterSelected;
  end;

implementation

{ TChapterList }

constructor TChapterList.Create(AParent: TControl);
begin
  inherited Create(AParent);
  FChapters := nil;
  FScrollY := 0;
  FMaxScroll := 0;
  FFontLoaded := False;
  FFontSize := 16;
  FSpacing := 0.3;
  FLineHeight := FFontSize * 1.4;
  FSelectedIndex := -1;
  FItemPadding := 8;
  FShowScrollBar := True;
  FMouseDown := False;
  FWheelAccum := 0;
  FTitleColor := ColorCreate(40, 40, 80, 255);
  FTextColor := ColorCreate(60, 60, 70, 255);
  FHighlightColor := ColorCreate(100, 100, 140, 100);
  FScrollBarColor := ColorCreate(150, 150, 160, 200);
  FScrollBarBackColor := ColorCreate(220, 220, 230, 100);
  FillChar(FFont, SizeOf(TFont), 0);
end;

destructor TChapterList.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);
  inherited Destroy;
end;

procedure TChapterList.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);
  FFontSize := Size;
  FLineHeight := Size * 1.4;
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

procedure TChapterList.SetChapters(const Chapters: TFB2ChapterArray);
begin
  FChapters := Chapters;
  FScrollY := 0;
  FSelectedIndex := -1;
  UpdateMaxScroll;
end;

procedure TChapterList.ClearChapters;
begin
  SetLength(FChapters, 0);
  FScrollY := 0;
  FSelectedIndex := -1;
  FMaxScroll := 0;
end;

function TChapterList.GetVisibleHeight: Single;
begin
  Result := Height - FItemPadding * 2;
  if Result < FLineHeight then Result := FLineHeight;
end;

procedure TChapterList.UpdateMaxScroll;
var
  TotalHeight: Single;
  i: Integer;
begin
  TotalHeight := FItemPadding * 2;
  for i := 0 to Length(FChapters) - 1 do
    TotalHeight := TotalHeight + FLineHeight;
  FMaxScroll := Max(0, TotalHeight - GetVisibleHeight);
  if FScrollY > FMaxScroll then FScrollY := FMaxScroll;
  if FScrollY < 0 then FScrollY := 0;
end;

procedure TChapterList.UpdateScroll(WheelDelta: Single);
begin
  FScrollY := FScrollY - WheelDelta * FLineHeight;
  if FScrollY < 0 then FScrollY := 0;
  if FScrollY > FMaxScroll then FScrollY := FMaxScroll;
end;

procedure TChapterList.ScrollToChapter(Index: Integer);
var
  TargetY: Single;
begin
  if (Index < 0) or (Index >= Length(FChapters)) then Exit;
  TargetY := Index * FLineHeight - 10;
  if TargetY < 0 then TargetY := 0;
  if TargetY > FMaxScroll then TargetY := FMaxScroll;
  FScrollY := TargetY;
end;

procedure TChapterList.InvertColors;
begin
  FTitleColor := InvertColor(FTitleColor);
  FTextColor := InvertColor(FTextColor);
  FHighlightColor := InvertColor(FHighlightColor);
  FScrollBarColor := InvertColor(FScrollBarColor);
  FScrollBarBackColor := InvertColor(FScrollBarBackColor);
end;

// 🔑 Обработка клавиатуры внутри списка
procedure TChapterList.HandleKeyboard;
var
  PageStep: Single;
begin
  // Стрелки ↑↓ для навигации по элементам
  if IsKeyPressed(KEY_UP) or IsKeyPressedRepeat(KEY_UP) then
  begin
    if FSelectedIndex > 0 then
    begin
      FSelectedIndex := FSelectedIndex - 1;
      ScrollToChapter(FSelectedIndex);
    end;
  end
  else if IsKeyPressed(KEY_DOWN) or IsKeyPressedRepeat(KEY_DOWN) then
  begin
    if FSelectedIndex < Length(FChapters) - 1 then
    begin
      FSelectedIndex := FSelectedIndex + 1;
      ScrollToChapter(FSelectedIndex);
    end;
  end
  // PageUp/PageDown для быстрой прокрутки
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
  end
  // Enter — эмуляция клика по выбранному элементу
  else if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_KP_ENTER) then
  begin
    if (FSelectedIndex >= 0) and (FSelectedIndex < Length(FChapters)) and Assigned(FOnChapterClick) then
      FOnChapterClick(Self);
  end;
end;

procedure TChapterList.Paint;
var
  i: Integer;
  CurrentY, ScreenY, DrawX: Single;
  ItemRect: TRectangle;
  MousePoint: TVector2;
  TxtColor: TColorB;
  TextPos: TVector2;
  Indent: Single;
  ScrollBarHeight, ScrollBarY, ScrollBarWidth: Single;
  Wheel: Single;
  MaxW: Single;
begin
  // 🔑 Обработка клавиатуры
  HandleKeyboard;

  // Обработка ввода мыши
  Wheel := GetMouseWheelMove();
  if Abs(Wheel) > 0.01 then
  begin
    FWheelAccum := FWheelAccum + Wheel;
    if Abs(FWheelAccum) >= 1.0 then
    begin
      UpdateScroll(Sign(FWheelAccum));
      FWheelAccum := 0;
    end;
  end;

  MousePoint := GetMousePosition();
  if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
  begin
    FMouseDown := True;
    FMouseDownY := MousePoint.Y;
    FScrollStart := FScrollY;
  end;
  if IsMouseButtonUp(MOUSE_BUTTON_LEFT) then FMouseDown := False;
  if FMouseDown then
  begin
    FScrollY := FScrollStart - (MousePoint.Y - FMouseDownY);
    if FScrollY < 0 then FScrollY := 0;
    if FScrollY > FMaxScroll then FScrollY := FMaxScroll;
  end;

  // Фон списка
  DrawRectangle(Left, Top, Width, Height, ColorAlpha(BLACK, 0));
  BeginScissorMode(Left, Top, Width, Height);

  CurrentY := Top + FItemPadding - FScrollY;
  DrawX := Left + FItemPadding;
  MaxW := Width - FItemPadding * 2 - 18;
  if MaxW < 50 then MaxW := 50;

  for i := 0 to Length(FChapters) - 1 do
  begin
    ScreenY := CurrentY;
    ItemRect := RectangleCreate(Left + 2, ScreenY, Width - 4, FLineHeight);

    if (ScreenY + FLineHeight > Top) and (ScreenY < Top + Height) then
    begin
      Indent := FChapters[i].Level * 20;
      TextPos.X := DrawX + Indent;
      TextPos.Y := ScreenY + 2;

      // Подсветка при наведении/выборе
      if CheckCollisionPointRec(MousePoint, ItemRect) or (i = FSelectedIndex) then
        DrawRectangleRounded(ItemRect, 0.1, 0, FHighlightColor);

      // Клик по главе
      if CheckCollisionPointRec(MousePoint, ItemRect) and IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      begin
        FSelectedIndex := i;
        if Assigned(FOnChapterClick) then FOnChapterClick(Self);
      end;

      // Цвет текста
      if i = FSelectedIndex then TxtColor := FTitleColor
      else if FChapters[i].Level = 0 then TxtColor := FTitleColor
      else TxtColor := FTextColor;

      // Маркер для вложенных глав
      if FChapters[i].Level > 0 then
        DrawCircle(trunc(TextPos.X) - 8, trunc(TextPos.Y) + FFontSize div 2, 2, TxtColor);

      // Отрисовка текста
      if FFontLoaded and (FFont.texture.id <> 0) then
        DrawTextEx(FFont, PAnsiChar(FChapters[i].Title), TextPos, FFontSize, FSpacing, TxtColor)
      else
        DrawText(PAnsiChar(FChapters[i].Title), Round(TextPos.X), Round(TextPos.Y), FFontSize, TxtColor);
    end;

    CurrentY := CurrentY + FLineHeight;
  end;
  EndScissorMode();

  // Полоса прокрутки
  if FShowScrollBar and (FMaxScroll > 0) then
  begin
    ScrollBarWidth := 8;
    ScrollBarHeight := Max(20, Round(GetVisibleHeight * GetVisibleHeight / (GetVisibleHeight + FMaxScroll)));
    ScrollBarY := Top + FItemPadding + Round((FScrollY / FMaxScroll) * (GetVisibleHeight - ScrollBarHeight));

    DrawRectangle(Left + Width - Round(ScrollBarWidth), Top + FItemPadding,
                  Round(ScrollBarWidth), Round(GetVisibleHeight), FScrollBarBackColor);
    DrawRectangle(Left + Width - Round(ScrollBarWidth), Round(ScrollBarY),
                  Round(ScrollBarWidth), Round(ScrollBarHeight), FScrollBarColor);
  end;
end;

{ TChaptersPanel }

procedure TChaptersPanel.SetOnButtonClick(AValue: TNotifyEvent);
begin
  FOnButtonClick := AValue;
  if Assigned(FCloseButton) then
    FCloseButton.OnButtonClick := AValue;
end;

procedure TChaptersPanel.OnChapterItemClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FChapterList.SelectedIndex;
  if (Idx >= 0) and (Idx < Length(FChapters)) and Assigned(FOnChapterSelected) then
    FOnChapterSelected(Idx, FChapters[Idx].StartY);
end;

procedure TChaptersPanel.Paint;
var
  PanelRect: TRectangle;
  TextWidth, TextHeight: Single;
  TextPos: TVector2;
  BtnTop, BtnCenterY: Single;
begin
  // Оверлей
  if FShowOverlay then
    DrawRectangle(0, 0, GetScreenWidth, GetScreenHeight, ColorAlpha(FOverlayColor, 0.5));

  // Фон панели
  PanelRect := RectangleCreate(Left, Top, Width, Height);
  DrawRectangleRounded(PanelRect, 0.04, 0, FBackgroundColor);

  // Заголовок
  if FFontLoaded and (FFont.texture.id <> 0) then
  begin
    TextWidth  := MeasureTextEx(FFont, PAnsiChar(FTitle), FFontSize, 0.5).x;
    TextHeight := MeasureTextEx(FFont, PAnsiChar(FTitle), FFontSize, 0.5).y;
  end
  else
  begin
    TextWidth  := MeasureText(PAnsiChar(FTitle), FFontSize);
    TextHeight := FFontSize;
  end;

  TextPos.X := Left + (Width - TextWidth) / 2;
  BtnTop     := Top + 10;
  BtnCenterY := BtnTop + 16;
  TextPos.Y  := BtnCenterY - TextHeight / 2;

  DrawTextEx(FFont, PAnsiChar(FTitle), TextPos, FFontSize, 0.5, FTitleColor);

  // Кнопка закрытия
  FCloseButton.Width  := 32;
  FCloseButton.Height := 32;
  FCloseButton.Left   := Left + Width - 32 - 10;
  FCloseButton.Top    := Top + 10;
  FCloseButton.Visible := True;
end;

constructor TChaptersPanel.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 320;
  Height := 450;
  Top := 10;
  Left := 10;

  FBackgroundColor := RAYWHITE;
  FOverlayColor := BLACK;
  FTitleColor := ColorCreate(40, 40, 70, 255);
  FFontSize := 18;
  FFontLoaded := False;
  FShowOverlay := True;
  FillChar(FFont, SizeOf(TFont), 0);

  FCloseButton := TImageButton.Create(Self);
  FCloseButton.Width := 32;
  FCloseButton.Height := 32;
  FCloseButton.Align := alNone;
  FCloseButton.Visible := False;

  FChapterList := TChapterList.Create(Self);
  FChapterList.Width := Width;
  FChapterList.Height := Height - 50;
  FChapterList.Left := 0;
  FChapterList.Align := alClient;
  FChapterList.Margins.SetMargins(0, 50, 0, 10); // Отступ сверху 50px под заголовок
  FChapterList.OnChapterClick := @OnChapterItemClick;
  FChapterList.TitleColor := ColorCreate(40, 40, 80, 255);
  FChapterList.TextColor := ColorCreate(60, 60, 70, 255);
  FChapterList.HighlightColor := ColorCreate(100, 100, 140, 100);
end;

destructor TChaptersPanel.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);
  inherited Destroy;
end;

procedure TChaptersPanel.InvertColors;
begin
  BackgroundColor := InvertColor(BackgroundColor);
  TitleColor := InvertColor(TitleColor);
  OverlayColor := InvertColor(OverlayColor);
  FChapterList.InvertColors;
end;

procedure TChaptersPanel.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);

  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
    FChapterList.LoadFont(FontPath, Size);
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
end;

procedure TChaptersPanel.SetChapters(Reader: TFB2Reader);
begin
  FChapters := Reader.Chapters;
  FChapterList.SetChapters(FChapters);
end;

procedure TChaptersPanel.UpdateScrollY(CurrentY: Single);
var
  i, ClosestIdx: Integer;
  MinDist, Dist: Single;
begin
  ClosestIdx := -1;
  MinDist := 1e10;

  for i := 0 to High(FChapters) do
  begin
    Dist := Abs(FChapters[i].StartY - CurrentY);
    if Dist < MinDist then
    begin
      MinDist := Dist;
      ClosestIdx := i;
    end;
  end;

  if (ClosestIdx >= 0) and (ClosestIdx <> FChapterList.SelectedIndex) then
  begin
    FChapterList.SelectedIndex := ClosestIdx;
    FChapterList.ScrollToChapter(ClosestIdx);
  end;
end;

// 🔑 Делегирует обработку клавиатуры списку
procedure TChaptersPanel.UpdateKeyboardScroll;
begin
  if Visible and FChapterList.Visible then
    FChapterList.HandleKeyboard;
end;

end.
