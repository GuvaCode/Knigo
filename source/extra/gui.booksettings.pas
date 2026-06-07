unit gui.booksettings;

{$mode ObjFPC}{$H+}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout, rlgui.components, ReaderTools, math,
  fb2Reader;

type
  { Элемент настройки со стрелками }
  TSettingItem = class(TControl)
  private
    FCaption: string;
    FValue: string;
    FValues: TStringList;
    FIndex: Integer;
    FFont: TFont;
    FFontLoaded: Boolean;
    FFontSize: Integer;
    FSpacing: Single;
    FLabelColor: TColorB;
    FValueColor: TColorB;
    FButtonColor: TColorB;
    FButtonHoverColor: TColorB;
    FArrowLeftRect, FArrowRightRect: TRectangle;
    FOnValueChanged: TNotifyEvent;
    FLeftHovered, FRightHovered: Boolean;
    procedure SetValues(const AValues: TStringList);
    procedure SetValueIndex(const AIndex: Integer);
    procedure UpdateHitboxes;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure NextValue;
    procedure PrevValue;
    procedure HandleMouse;
    procedure InvertColors;
    property Caption: string read FCaption write FCaption;
    property Value: string read FValue;
    property ValueIndex: Integer read FIndex write SetValueIndex;
    property Values: TStringList read FValues write SetValues;
    property OnValueChanged: TNotifyEvent read FOnValueChanged write FOnValueChanged;
    property LabelColor: TColorB read FLabelColor write FLabelColor;
    property ValueColor: TColorB read FValueColor write FValueColor;
  end;

  { Элемент настройки со слайдером }

  { TSettingSlider }

  TSettingSlider = class(TControl)
  private
    FCaption: string;
    FStep: Integer;
    FValue: Integer;
    FMinValue, FMaxValue: Integer;
    FFont: TFont;
    FFontLoaded: Boolean;
    FFontSize: Integer;
    FSpacing: Single;
    FLabelColor: TColorB;
    FValueColor: TColorB;
    FSliderColor: TColorB;
    FSliderBackColor: TColorB;
    FSliderRect: TRectangle;
    FHandleRect: TRectangle;
    FMouseDown: Boolean;
    FMouseDownOffset: Single;
    FOnValueChanged: TNotifyEvent;
    procedure SetValue(const AValue: Integer);
    procedure UpdateSlider;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure HandleMouse;
    procedure InvertColors;
    property Caption: string read FCaption write FCaption;
    property Value: Integer read FValue write SetValue;
    property MinValue: Integer read FMinValue write FMinValue;
    property MaxValue: Integer read FMaxValue write FMaxValue;
    property OnValueChanged: TNotifyEvent read FOnValueChanged write FOnValueChanged;
    property LabelColor: TColorB read FLabelColor write FLabelColor;
    property ValueColor: TColorB read FValueColor write FValueColor;
    property Step: Integer read FStep write FStep;
  end;

  { 🔹 Кастомная кнопка с закруглёнными углами }
  TCustomButton = class(TControl)
  private
    FCaption: string;
    FNormalColor: TColorB;
    FHoverColor: TColorB;
    FPressedColor: TColorB;
    FTextColor: TColorB;
    FFont: TFont;
    FFontLoaded: Boolean;
    FFontSize: Integer;
    FIsHovered: Boolean;
    FIsPressed: Boolean;
    FOnButtonClick: TNotifyEvent;
    procedure HandleMouse;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure InvertColors;
    property Caption: string read FCaption write FCaption;
    property NormalColor: TColorB read FNormalColor write FNormalColor;
    property HoverColor: TColorB read FHoverColor write FHoverColor;
    property PressedColor: TColorB read FPressedColor write FPressedColor;
    property TextColor: TColorB read FTextColor write FTextColor;
    property OnButtonClick: TNotifyEvent read FOnButtonClick write FOnButtonClick;
  end;

  { Панель настроек }
  TSettingsPanel = class(TControl)
  private
    FBackgroundColor: TColorB;
    FCloseButton: TImageButton;
    FResetButton: TCustomButton;
    FFont: TFont;
    FFontLoaded: Boolean;
    FOnButtonClick: TNotifyEvent;
    FOverlayColor: TColorB;
    FTitle: String;
    FTitleColor: TColorB;
    FFontSize: Integer;
    FShowOverlay: Boolean;
    FLanguageItem: TSettingItem;
    FFontItem: TSettingItem;
    FFontSizeSlider: TSettingSlider;
    FPaddingSlider: TSettingSlider;
    FReader: TFB2Reader;
    procedure SetOnButtonClick(AValue: TNotifyEvent);
    procedure OnLanguageChanged(Sender: TObject);
    procedure OnFontChanged(Sender: TObject);
    procedure OnFontSizeChanged(Sender: TObject);
    procedure OnPaddingChanged(Sender: TObject);
    procedure OnResetClick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure InvertColors;
    procedure LoadFont(const FontPath: string; Size: Integer);
    procedure SetReader(AReader: TFB2Reader);
    procedure ApplySettings;
    property OnButtonClick: TNotifyEvent read FOnButtonClick write SetOnButtonClick;
    property CloseButton: TImageButton read FCloseButton write FCloseButton;
    property BackgroundColor: TColorB read FBackgroundColor write FBackgroundColor;
    property Font: TFont read FFont write FFont;
    property Title: String read FTitle write FTitle;
    property TitleColor: TColorB read FTitleColor write FTitleColor;
    property OverlayColor: TColorB read FOverlayColor write FOverlayColor;
    property ShowOverlay: Boolean read FShowOverlay write FShowOverlay;
    property Reader: TFB2Reader read FReader write SetReader;
  end;

implementation

{ TSettingItem }
constructor TSettingItem.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Height := 75;
  FValues := TStringList.Create;
  FIndex := 0;
  FFontSize := 16;
  FSpacing := 0.3;
  FLabelColor := ColorCreate(60, 60, 70, 255);
  FValueColor := ColorCreate(40, 40, 80, 255);
  FButtonColor := ColorCreate(200, 200, 210, 255);
  FButtonHoverColor := ColorCreate(180, 180, 200, 255);
  FFontLoaded := False;
  FillChar(FFont, SizeOf(TFont), 0);
  FLeftHovered := False;
  FRightHovered := False;
end;

destructor TSettingItem.Destroy;
begin
  FValues.Free;
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  inherited Destroy;
end;

procedure TSettingItem.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
end;

procedure TSettingItem.SetValues(const AValues: TStringList);
begin
  FValues.Assign(AValues);
  if FIndex >= FValues.Count then FIndex := 0;
  if FValues.Count > 0 then FValue := FValues[FIndex];
end;

procedure TSettingItem.SetValueIndex(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FValues.Count) then
  begin
    FIndex := AIndex;
    FValue := FValues[FIndex];
    if Assigned(FOnValueChanged) then FOnValueChanged(Self);
  end;
end;

// зоны клика
procedure TSettingItem.UpdateHitboxes;
var
  ArrowSize, ValueWidth, ControlWidth: Single;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then
    ValueWidth := MeasureTextEx(FFont, PAnsiChar(FValue), FFontSize, FSpacing).x
  else
    ValueWidth := MeasureText(PAnsiChar(FValue), FFontSize);

  ArrowSize := 28;
  // Если текст слишком длинный, уменьшаем отступы, чтобы кнопки влезли
  if (ArrowSize * 2 + ValueWidth + 40) > Width then
    ControlWidth := Width - 10
  else
    ControlWidth := ArrowSize * 2 + ValueWidth + 40;

  // Центрируем кнопки относительно значения
  FArrowLeftRect := RectangleCreate(Left + (Width - ControlWidth) / 2, Top + 35, ArrowSize, ArrowSize);
  FArrowRightRect := RectangleCreate(Left + (Width + ControlWidth) / 2 - ArrowSize, Top + 35, ArrowSize, ArrowSize);
end;

procedure TSettingItem.NextValue;
begin
  if FValues.Count > 0 then
  begin
    FIndex := (FIndex + 1) mod FValues.Count;
    FValue := FValues[FIndex];
    if Assigned(FOnValueChanged) then FOnValueChanged(Self);
  end;
end;

procedure TSettingItem.PrevValue;
begin
  if FValues.Count > 0 then
  begin
    FIndex := (FIndex - 1 + FValues.Count) mod FValues.Count;
    FValue := FValues[FIndex];
    if Assigned(FOnValueChanged) then FOnValueChanged(Self);
  end;
end;

procedure TSettingItem.HandleMouse;
var
  MousePoint: TVector2;
begin
  UpdateHitboxes;
  MousePoint := GetMousePosition();
  FLeftHovered := CheckCollisionPointRec(MousePoint, FArrowLeftRect);
  FRightHovered := CheckCollisionPointRec(MousePoint, FArrowRightRect);
  if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
  begin
    if CheckCollisionPointRec(MousePoint, FArrowLeftRect) then PrevValue
    else if CheckCollisionPointRec(MousePoint, FArrowRightRect) then NextValue;
  end;
end;

procedure TSettingItem.InvertColors;
begin
  FLabelColor := InvertColor(FLabelColor);
  FValueColor := InvertColor(FValueColor);
  FButtonColor := InvertColor(FButtonColor);
  FButtonHoverColor := InvertColor(FButtonHoverColor);
end;


procedure TSettingItem.Paint;
var
  TextPos, ValuePos: TVector2;
  CaptionWidth, ValueWidth: Single;
  ArrowBgColor, ArrowIconColor: TColorB;
  LCX, LCY, RCX, RCY: Single;
begin
  HandleMouse;
  DrawRectangle(Left, Top, Width, Height, ColorAlpha(BLACK, 0));

  // 1. Заголовок
  if FFontLoaded and (FFont.texture.id <> 0) then CaptionWidth := MeasureTextEx(FFont, PAnsiChar(FCaption), FFontSize, FSpacing).x
  else CaptionWidth := MeasureText(PAnsiChar(FCaption), FFontSize);
  TextPos.X := Left + (Width - CaptionWidth) / 2;
  TextPos.Y := Top + 6;
  if FFontLoaded and (FFont.texture.id <> 0) then DrawTextEx(FFont, PAnsiChar(FCaption), TextPos, FFontSize, FSpacing, FLabelColor)
  else DrawText(PAnsiChar(FCaption), Round(TextPos.X), Round(TextPos.Y), FFontSize, FLabelColor);

  // 2. Значение
  if FFontLoaded and (FFont.texture.id <> 0) then ValueWidth := MeasureTextEx(FFont, PAnsiChar(FValue), FFontSize, FSpacing).x
  else ValueWidth := MeasureText(PAnsiChar(FValue), FFontSize);
  ValuePos.X := Left + (Width - ValueWidth) / 2;
  ValuePos.Y := Top + 37;
  if FFontLoaded and (FFont.texture.id <> 0) then DrawTextEx(FFont, PAnsiChar(FValue), ValuePos, FFontSize, FSpacing, FValueColor)
  else DrawText(PAnsiChar(FValue), Round(ValuePos.X), Round(ValuePos.Y), FFontSize, FValueColor);

  ArrowIconColor := ColorCreate(40, 40, 70, 255);

  // 3. Левая кнопка (стрелка влево <)
  ArrowBgColor := FButtonColor;
  if FLeftHovered then ArrowBgColor := FButtonHoverColor;

  // Фон кнопки (Круг)
  LCX := FArrowLeftRect.X + FArrowLeftRect.Width / 2 - 5;
  LCY := FArrowLeftRect.Y + FArrowLeftRect.Height / 2;
  DrawCircleV(Vector2Create(LCX, LCY), FArrowLeftRect.Width/2 , ArrowBgColor);


  ArrowBgColor := FButtonColor;
  if FLeftHovered then ArrowBgColor := FButtonHoverColor;
//  DrawRectangleRounded(FArrowLeftRect, 0.3, 0, ArrowBgColor);

 // LCX := FArrowLeftRect.X + FArrowLeftRect.Width / 2;
 // LCY := FArrowLeftRect.Y + FArrowLeftRect.Height / 2;

  DrawTriangle(Vector2Create(LCX - 5, LCY),
               Vector2Create(LCX + 6, LCY + 7),
               Vector2Create(LCX + 6, LCY - 7), ArrowIconColor);


  // Стрелка < (Острие влево)
  // P1: Острие (слева), P2, P3: Основание (справа)
  DrawTriangle(
    Vector2Create(LCX - 5, LCY),       // Острие
    Vector2Create(LCX + 6, LCY - 7),   // Верх основания
    Vector2Create(LCX + 6, LCY + 7),   // Низ основания
    ArrowIconColor
  );

  // 4. Правая кнопка (стрелка вправо >)
  ArrowBgColor := FButtonColor;
  if FRightHovered then ArrowBgColor := FButtonHoverColor;

  // Фон кнопки (Круг)
  RCX := FArrowRightRect.X + FArrowRightRect.Width / 2;
  RCY := FArrowRightRect.Y + FArrowRightRect.Height / 2;
  DrawCircleV(Vector2Create(RCX, RCY), FArrowRightRect.Width/2 - 1, ArrowBgColor);

  // Стрелка > (Острие вправо)
  // P1: Острие (справа), P2, P3: Основание (слева)
  DrawTriangle(
    Vector2Create(RCX + 5, RCY),       // Острие
    Vector2Create(RCX - 6, RCY - 7),   // Верх основания
    Vector2Create(RCX - 6, RCY + 7),   // Низ основания
    ArrowIconColor
  );
end;

{ TSettingSlider }
constructor TSettingSlider.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Height := 85;
  FMinValue := 10;
  FMaxValue := 100;
  FValue := 50;
  FFontSize := 16;
  FSpacing := 0.3;
  FLabelColor := ColorCreate(60, 60, 70, 255);
  FValueColor := ColorCreate(40, 40, 80, 255);
  FSliderColor := ColorCreate(100, 100, 140, 255);
  FSliderBackColor := ColorCreate(220, 220, 230, 200);
  FFontLoaded := False;
  FMouseDown := False;
  FillChar(FFont, SizeOf(TFont), 0);
  FStep := 1;
end;

destructor TSettingSlider.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  inherited Destroy;
end;

procedure TSettingSlider.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
  UpdateSlider;
end;

procedure TSettingSlider.SetValue(const AValue: Integer);
begin
  FValue := AValue;
  if FValue < FMinValue then FValue := FMinValue;
  if FValue > FMaxValue then FValue := FMaxValue;


  if FStep > 1 then FValue := (FValue + (FStep div 2)) div FStep * FStep;

  UpdateSlider;
  if Assigned(FOnValueChanged) then FOnValueChanged(Self);
end;

procedure TSettingSlider.UpdateSlider;
var
  SliderWidth: Single;
begin
  SliderWidth := Width - 50;
  FSliderRect := RectangleCreate(Left + 25, Top + 40, SliderWidth, 8);
  FHandleRect := RectangleCreate(Left + 25 + (FValue - FMinValue) / (FMaxValue - FMinValue) * SliderWidth - 8, Top + 34, 16, 24);
end;

procedure TSettingSlider.HandleMouse;
var
  MousePoint: TVector2;
  SliderWidth, Ratio: Single;
begin
  UpdateSlider;
  MousePoint := GetMousePosition();
  if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
  begin
    if CheckCollisionPointRec(MousePoint, FHandleRect) then
    begin
      FMouseDown := True;
      FMouseDownOffset := MousePoint.X - FHandleRect.X;
    end
    else if CheckCollisionPointRec(MousePoint, FSliderRect) then
    begin
      Ratio := (MousePoint.X - FSliderRect.X) / FSliderRect.Width;
      FValue := Round(FMinValue + Ratio * (FMaxValue - FMinValue));

      if FStep > 1 then FValue := (FValue + (FStep div 2)) div FStep * FStep;
      if FValue < FMinValue then FValue := FMinValue;
      if FValue > FMaxValue then FValue := FMaxValue;
      UpdateSlider;
      if Assigned(FOnValueChanged) then FOnValueChanged(Self);
    end;
  end;
  if IsMouseButtonUp(MOUSE_BUTTON_LEFT) then FMouseDown := False;
  if FMouseDown then
  begin
    SliderWidth := FSliderRect.Width;
    Ratio := (MousePoint.X - FMouseDownOffset - FSliderRect.X) / SliderWidth;
    FValue := Round(FMinValue + Ratio * (FMaxValue - FMinValue));

    if FStep > 1 then FValue := (FValue + (FStep div 2)) div FStep * FStep;
    if FValue < FMinValue then FValue := FMinValue;
    if FValue > FMaxValue then FValue := FMaxValue;
    UpdateSlider;
    if Assigned(FOnValueChanged) then FOnValueChanged(Self);
  end;
end;

procedure TSettingSlider.InvertColors;
begin
  FLabelColor := InvertColor(FLabelColor);
  FValueColor := InvertColor(FValueColor);
  FSliderColor := InvertColor(FSliderColor);
  FSliderBackColor := InvertColor(FSliderBackColor);
end;

procedure TSettingSlider.Paint;
var
  TextPos, ValuePos: TVector2;
  ValueStr: string;
  TxtW: Single;
begin
  HandleMouse;
  DrawRectangle(Left, Top, Width, Height, ColorAlpha(BLACK, 0));
  if FFontLoaded and (FFont.texture.id <> 0) then TxtW := MeasureTextEx(FFont, PAnsiChar(FCaption), FFontSize, FSpacing).x
  else TxtW := MeasureText(PAnsiChar(FCaption), FFontSize);
  TextPos.X := Left + (Width - TxtW) / 2;
  TextPos.Y := Top + 6;
  if FFontLoaded and (FFont.texture.id <> 0) then DrawTextEx(FFont, PAnsiChar(FCaption), TextPos, FFontSize, FSpacing, FLabelColor)
  else DrawText(PAnsiChar(FCaption), Round(TextPos.X), Round(TextPos.Y), FFontSize, FLabelColor);

  DrawRectangleRounded(FSliderRect, 0.5, 0, FSliderBackColor);
  DrawRectangleRounded(RectangleCreate(FSliderRect.X, FSliderRect.Y, (FValue - FMinValue) / (FMaxValue - FMinValue) * FSliderRect.Width, FSliderRect.Height), 0.5, 0, FSliderColor);
  DrawRectangleRounded(FHandleRect, 0.3, 0, FSliderColor);
  DrawRectangleRounded(RectangleCreate(FHandleRect.X + 2, FHandleRect.Y + 2, FHandleRect.Width - 4, FHandleRect.Height - 4), 0.3, 0, RAYWHITE);

  ValueStr := IntToStr(FValue);
  if FFontLoaded and (FFont.texture.id <> 0) then
  begin
    TxtW := MeasureTextEx(FFont, PAnsiChar(ValueStr), FFontSize, FSpacing).x;
    ValuePos.X := Left + Width - TxtW + 10;
    ValuePos.Y := FSliderRect.Y - 2;
    DrawTextEx(FFont, PAnsiChar(ValueStr), ValuePos, FFontSize, FSpacing, FValueColor);
  end
  else
  begin
    TxtW := MeasureText(PAnsiChar(ValueStr), FFontSize);
    DrawText(PAnsiChar(ValueStr), Round(Left + Width - TxtW - 10), Round(FSliderRect.Y - 2), FFontSize, FValueColor);
  end;
end;

{ TCustomButton }
constructor TCustomButton.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 140;
  Height := 36;
  FCaption := 'Сбросить';
  FNormalColor := ColorCreate(200, 200, 210, 255);
  FHoverColor := ColorCreate(180, 180, 200, 255);
  FPressedColor := ColorCreate(160, 160, 180, 255);
  FTextColor := ColorCreate(40, 40, 60, 255);
  FFontLoaded := False;
  FFontSize := 14;
  FIsHovered := False;
  FIsPressed := False;
  FillChar(FFont, SizeOf(TFont), 0);
end;

destructor TCustomButton.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  inherited Destroy;
end;

procedure TCustomButton.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
end;

procedure TCustomButton.HandleMouse;
var
  MousePos: TVector2;
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  MousePos := GetMousePosition();
  FIsHovered := CheckCollisionPointRec(MousePos, R);
  if FIsHovered then
  begin
    if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then FIsPressed := True;
    if IsMouseButtonReleased(MOUSE_BUTTON_LEFT) then
    begin
      if FIsPressed and Assigned(FOnButtonClick) then FOnButtonClick(Self);
      FIsPressed := False;
    end;
  end
  else
  begin
    if IsMouseButtonReleased(MOUSE_BUTTON_LEFT) then FIsPressed := False;
  end;
end;

procedure TCustomButton.Paint;
var
  TextPos: TVector2;
  TxtW, TxtH: Single;
  BtnColor: TColorB;
  R: TRectangle;
begin
  HandleMouse;
  if FIsPressed then BtnColor := FPressedColor
  else if FIsHovered then BtnColor := FHoverColor
  else BtnColor := FNormalColor;
  R := RectangleCreate(Left, Top, Width, Height);
  DrawRectangleRounded(R, 0.2, 0, BtnColor);
  if FFontLoaded and (FFont.texture.id <> 0) then
  begin
    TxtW := MeasureTextEx(FFont, PAnsiChar(FCaption), FFontSize, 0.5).x;
    TxtH := MeasureTextEx(FFont, PAnsiChar(FCaption), FFontSize, 0.5).y;
    TextPos.X := Left + (Width - TxtW) / 2;
    TextPos.Y := Top + (Height - TxtH) / 2;
    DrawTextEx(FFont, PAnsiChar(FCaption), TextPos, FFontSize, 0.5, FTextColor);
  end
  else
  begin
    TxtW := MeasureText(PAnsiChar(FCaption), FFontSize);
    TxtH := FFontSize;
    DrawText(PAnsiChar(FCaption), Round(Left + (Width - TxtW) / 2), Round(Top + (Height - TxtH) / 2), FFontSize, FTextColor);
  end;
end;

procedure TCustomButton.InvertColors;
begin
  FNormalColor := InvertColor(FNormalColor);
  FHoverColor := InvertColor(FHoverColor);
  FPressedColor := InvertColor(FPressedColor);
  FTextColor := InvertColor(FTextColor);
end;

{ TSettingsPanel }
procedure TSettingsPanel.SetOnButtonClick(AValue: TNotifyEvent);
begin
  FOnButtonClick := AValue;
  if Assigned(FCloseButton) then FCloseButton.OnButtonClick := AValue;
end;

procedure TSettingsPanel.OnLanguageChanged(Sender: TObject);
begin
  if Assigned(FReader) then ApplySettings;
end;

procedure TSettingsPanel.OnFontChanged(Sender: TObject);
begin
  if Assigned(FReader) then ApplySettings;
end;

procedure TSettingsPanel.OnFontSizeChanged(Sender: TObject);
begin
  if Assigned(FReader) then
  begin
    FReader.TextSize := FFontSizeSlider.Value;
    FReader.ReloadFonts;
    FReader.ReloadLayout;
  end;
end;

procedure TSettingsPanel.OnPaddingChanged(Sender: TObject);
begin
  if Assigned(FReader) then ApplySettings;
end;

procedure TSettingsPanel.OnResetClick(Sender: TObject);
begin
  if Assigned(FReader) then
  begin
    FLanguageItem.ValueIndex := 0;
    FFontItem.ValueIndex := 0;
    FFontSizeSlider.Value := 24;
    FPaddingSlider.Value := 64;
    FPaddingSlider.MinValue:=64;

    FReader.TextSize := 24;

    FReader.BaseFontPath     := 'data/fonts/DejaVuSans.ttf';
    FReader.TitleFontPath    := 'data/fonts/DejaVuSans-Bold.ttf';
    FReader.SubtitleFontPath := 'data/fonts/DejaVuSans-Oblique.ttf';

    FReader.ReloadFonts;
    FReader.ReloadLayout;
  end;
end;

procedure TSettingsPanel.ApplySettings;
begin
  if Assigned(FReader) then
  begin

    case FFontItem.ValueIndex of
    0: begin
         FReader.BaseFontPath     := 'data/fonts/DejaVuSans.ttf';
         FReader.TitleFontPath    := 'data/fonts/DejaVuSans-Bold.ttf';
         FReader.SubtitleFontPath := 'data/fonts/DejaVuSans-Oblique.ttf';
       end;
    1: begin
         FReader.BaseFontPath     := 'data/fonts/ArialNarrow.ttf';
         FReader.TitleFontPath    := 'data/fonts/ArialNarrow-Bold.ttf';
         FReader.SubtitleFontPath := 'data/fonts/ArialNarrow-Italic.ttf';
       end;
    2: begin
         FReader.BaseFontPath     := 'data/fonts/Times.ttf';
         FReader.TitleFontPath    := 'data/fonts/Times-Bold.ttf';
         FReader.SubtitleFontPath := 'data/fonts/Times-Italic.ttf';
       end;
    3: begin
         FReader.BaseFontPath     := 'data/fonts/LiterataBook.otf';
         FReader.TitleFontPath    := 'data/fonts/LiterataBook-Bold.otf';
         FReader.SubtitleFontPath := 'data/fonts/LiterataBook-Italic.otf';
       end;
    4: begin
         FReader.BaseFontPath     := 'data/fonts/Bookerly.ttf';
         FReader.TitleFontPath    := 'data/fonts/Bookerly-Bold.ttf';
         FReader.SubtitleFontPath := 'data/fonts/Bookerly-Italic.ttf';
       end;

    end;
    FReader.Padding:=FPaddingSlider.Value;
    {
    if FFontItem.ValueIndex = 0 then
    FReader.BaseFontPath := 'data/fonts/DejaVuSans.ttf'

    else if FFontItem.ValueIndex = 1 then FReader.BaseFontPath := 'data/fonts/Arial.ttf'

    else if FFontItem.ValueIndex = 2 then FReader.BaseFontPath := 'data/fonts/Times.ttf';
    }
    FReader.ReloadFonts;
    FReader.ReloadLayout;
  end;
end;

procedure TSettingsPanel.Paint;
var
  PanelRect: TRectangle;
  TextWidth, TextHeight: Single;
  TextPos: TVector2;
  BtnTop, BtnCenterY: Single;
  ItemY: Single;
begin

  FPaddingSlider.MaxValue := (GetRenderWidth div 2)- 256;
  if Freader.Padding >=  FPaddingSlider.MaxValue then
  begin
    Freader.Padding :=  FPaddingSlider.MaxValue;
    FPaddingSlider.Value:=  Freader.Padding;
  end;
  if FShowOverlay then
    DrawRectangle(0, 0, GetRenderWidth, GetRenderHeight, ColorAlpha(FOverlayColor, 0.5));

  PanelRect := RectangleCreate(Left, Top, Width, Height);
  DrawRectangleRounded(PanelRect, 0.04, 0, FBackgroundColor);

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

  FCloseButton.Width  := 32;
  FCloseButton.Height := 32;
  FCloseButton.Left   := Left + Width - 32 - 10;
  FCloseButton.Top    := Top + 10;
  FCloseButton.Visible := True;

  ItemY := Top + 45;

  FLanguageItem.Left := Left + (Width - FLanguageItem.Width) div 2;
  FLanguageItem.Top := Round(ItemY);
  ItemY := ItemY + FLanguageItem.Height - 5;

  FFontItem.Left := Left + (Width - FFontItem.Width) div 2;
  FFontItem.Top := Round(ItemY);
  ItemY := ItemY + FFontItem.Height - 5;

  FFontSizeSlider.Left := Left + (Width - FFontSizeSlider.Width) div 2;
  FFontSizeSlider.Top := Round(ItemY);
  ItemY := ItemY + FFontSizeSlider.Height - 15;

  FPaddingSlider.Left := Left + (Width - FPaddingSlider.Width) div 2;
  FPaddingSlider.Top := Round(ItemY);

  FResetButton.Left := Left + (Width - FResetButton.Width) div 2;
  FResetButton.Top := Round(ItemY + 75);
end;

constructor TSettingsPanel.Create(AParent: TControl);
var
  Fonts, Languages: TStringList;
begin
  inherited Create(AParent);
  Width := 350;
  Height := 520;
  Top := 10;
  Left := 10;

  FBackgroundColor := RAYWHITE;
  FOverlayColor := BLACK;
  FTitleColor := ColorCreate(40, 40, 70, 255);
  FFontSize := 18;
  FFontLoaded := False;
  FShowOverlay := True;
  FillChar(FFont, SizeOf(TFont), 0);
  FReader := nil;

  FCloseButton := TImageButton.Create(Self);
  FCloseButton.Width := 32;
  FCloseButton.Height := 32;
  FCloseButton.Align := alNone;
  FCloseButton.Visible := False;

  Languages := TStringList.Create;
  Languages.Add('English');
  Languages.Add('Русский');
  Languages.Add('Deutsch');
  FLanguageItem := TSettingItem.Create(Self);
  FLanguageItem.Width := 280;
  FLanguageItem.Caption := 'Язык:';
  FLanguageItem.Values := Languages;
  FLanguageItem.ValueIndex := 0;
  FLanguageItem.OnValueChanged := @OnLanguageChanged;
  Languages.Free;

  Fonts := TStringList.Create;
  Fonts.Add('DejaVu Sans');
  Fonts.Add('Arial');
  Fonts.Add('Times New Roman');
  Fonts.Add('Literata Book');
  Fonts.Add('Bookerly');
  FFontItem := TSettingItem.Create(Self);
  FFontItem.Width := 280;
  FFontItem.Caption := 'Шрифт:';
  FFontItem.Values := Fonts;
  FFontItem.ValueIndex := 0;
  FFontItem.OnValueChanged := @OnFontChanged;
  Fonts.Free;

  FFontSizeSlider := TSettingSlider.Create(Self);
  FFontSizeSlider.Width := 280;
  FFontSizeSlider.Caption := 'Размер шрифта:';
  FFontSizeSlider.MinValue := 22;
  FFontSizeSlider.MaxValue := 128;
  FFontSizeSlider.Value := 22;
  FFontSizeSlider.Step := 2; // (только чётные: 22, 24, 26...)

  FFontSizeSlider.OnValueChanged := @OnFontSizeChanged;

  FPaddingSlider := TSettingSlider.Create(Self);
  FPaddingSlider.Width := 280;
  FPaddingSlider.Caption := 'Размер отступов:';
  FPaddingSlider.MinValue := 64;
  FPaddingSlider.MaxValue := 100;
  FPaddingSlider.Value := 64;
  FPaddingSlider.OnValueChanged := @OnPaddingChanged;

  FResetButton := TCustomButton.Create(Self);
  FResetButton.Caption := 'Сбросить';
  FResetButton.OnButtonClick := @OnResetClick;
end;

destructor TSettingsPanel.Destroy;
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  inherited Destroy;
end;

procedure TSettingsPanel.InvertColors;
begin
  BackgroundColor := InvertColor(BackgroundColor);
  TitleColor := InvertColor(TitleColor);
  OverlayColor := InvertColor(OverlayColor);

  FLanguageItem.InvertColors;
  FFontItem.InvertColors;
  FFontSizeSlider.InvertColors;
  FPaddingSlider.InvertColors;
  FResetButton.InvertColors;
end;

procedure TSettingsPanel.LoadFont(const FontPath: string; Size: Integer);
begin
  if FFontLoaded and (FFont.texture.id <> 0) then UnloadFont(FFont);
  if SysUtils.FileExists(FontPath) then
  begin
    FFontSize := Size;
    LoadFontWithPreset(FFont, FFontSize, PAnsiChar(FontPath), 3);
    SetTextureFilter(FFont.texture, TEXTURE_FILTER_BILINEAR);
    FFontLoaded := True;

    FLanguageItem.LoadFont(FontPath, Size - 2);
    FFontItem.LoadFont(FontPath, Size - 2);
    FFontSizeSlider.LoadFont(FontPath, Size - 2);
    FPaddingSlider.LoadFont(FontPath, Size - 2);
    FResetButton.LoadFont(FontPath, Size - 4);
  end
  else
  begin
    FillChar(FFont, SizeOf(TFont), 0);
    FFontLoaded := False;
  end;
end;

procedure TSettingsPanel.SetReader(AReader: TFB2Reader);
begin
  FReader := AReader;
  if Assigned(FReader) then FFontSizeSlider.Value := FReader.TextSize;
end;

end.
