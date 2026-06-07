unit gui.bookextra;

{$mode ObjFPC}{$H+}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout, rlgui.components, ReaderTools, math,
  gui.booknotes, fb2Reader;

type

  { TRoundPanel }

  { TNotesPanel }

  TNotesPanel = class(TControl)
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
    FNoteList: TNoteList;
    FNotes: TBookNoteArray;
    procedure SetOnButtonClick(AValue: TNotifyEvent);
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure InvertColors;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure SetNotes(Reader: TFB2Reader);
    property OnButtonClick: TNotifyEvent read FOnButtonClick write SetOnButtonClick;
    property CloseButton: TImageButton read FCloseButton write FCloseButton;
    property BackgroundColor: TColorB read FBackgroundColor write FBackgroundColor;
    property Font: TFont read FFont write FFont;
    property Title: String read FTitle write FTitle;
    property TitleColor: TColorB read FTitleColor write FTitleColor;
    property OverlayColor: TColorB read FOverlayColor write FOverlayColor;
    property ShowOverlay: Boolean read FShowOverlay write FShowOverlay;
  end;

implementation

{ TRoundPanel }

// ← Сеттер: обновляет обработчик кнопки при изменении свойства
procedure TNotesPanel.SetOnButtonClick(AValue: TNotifyEvent);
begin
  FOnButtonClick := AValue;
  if Assigned(FCloseButton) then
    FCloseButton.OnButtonClick := AValue;
end;

procedure TNotesPanel.Paint;
var
  PanelRect: TRectangle;
  TextWidth, TextHeight: Single;
  TextPos: TVector2;
  BtnTop, BtnCenterY: Single;
begin
  // Оверлей — рисуем ТОЛЬКО если включён, и ВАЖНО: после панели, чтобы не перекрывать клики
  if FShowOverlay then
    DrawRectangle(0, 0, GetScreenWidth, GetScreenHeight, ColorAlpha(FOverlayColor, 0.5));

  // Фон панели
  PanelRect := RectangleCreate(Left, Top, Width, Height);
  DrawRectangleRounded(PanelRect, 0.04, 0, FBackgroundColor);

  // Измерение текста
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

  // Центрирование заголовка по горизонтали
  TextPos.X := Left + (Width - TextWidth) / 2;

  // Центрирование по вертикали относительно кнопки
   BtnTop     := Top + 10;
  BtnCenterY := BtnTop + 16; // центр кнопки 32px
  TextPos.Y  := BtnCenterY - TextHeight / 2; // коррекция базовой линии

  DrawTextEx(FFont, PAnsiChar(FTitle), TextPos, FFontSize, 0.5, FTitleColor);

  // Обновляем позицию кнопки (важно: вызывается КАЖДЫЙ кадр!)
  FCloseButton.Width  := 32;
  FCloseButton.Height := 32;
  FCloseButton.Left   := Left + Width - 32 - 10;
  FCloseButton.Top    := Top + 10;
  FCloseButton.Visible := True;

  // Кнопка — дочерний элемент, её Draw() вызовется автоматически после Paint
  // НО: если используете кастомную систему отрисовки, убедитесь, что вызываете:
  // FCloseButton.Draw;
end;

constructor TNotesPanel.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 300;
  Height := 400;
  Top := 10;
  Left := 10;

  FBackgroundColor := RAYWHITE;
  FOverlayColor := BLACK;
  FTitleColor := ColorCreate(40, 40, 70, 255);
  FFontSize := 18;
  FFontLoaded := False;
  FShowOverlay := True; // по умолчанию включён
  FillChar(FFont, SizeOf(TFont), 0);

  FCloseButton := TImageButton.Create(Self);
  FCloseButton.Width := 32;
  FCloseButton.Height := 32;
  FCloseButton.Align := alNone;
  FCloseButton.Visible := False;

  FNoteList := TNoteList.Create(Self);
  FNoteList.Width := 350;
  FNoteList.Height := 350;
  FNoteList.Margins.SetMargins(0,50,0,8);
  FNotelist.Align := alClient;
  FNoteList.DrawSelection:= False;
  FNoteList.TitleColor := ColorCreate(40, 40, 80, 255);
  FNoteList.TextColor := ColorCreate(60, 60, 70, 255);

end;

destructor TNotesPanel.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);
  inherited Destroy;
end;

procedure TNotesPanel.InvertColors;
begin
  BackgroundColor := InvertColor(BackgroundColor);
  TitleColor := InvertColor(TitleColor);
  OverlayColor := InvertColor(OverlayColor);
  FNoteList.InvertColors;
end;

procedure TNotesPanel.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    UnloadFont(FFont);

  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
    FNoteList.LoadFont(FontPath, Size);
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
end;

procedure TNotesPanel.SetNotes(Reader: TFB2Reader);
begin
    // Получаем сноски из FB2
  FNotes := Reader.GetNotes;
  FNoteList.SetNotes(FNotes);
end;

end.
