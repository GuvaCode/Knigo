unit rlgui.components;

{$mode ObjFPC}{$H+}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout;

type
  // Events
  TBooleanEvent = procedure(Sender: TObject; Toogle: Boolean) of object;
  TIntegerEvent = procedure(Sender: TObject; Active: Integer) of object;
  TSingleEvent = procedure(Sender: TObject; Value: Single) of object;
  TSingleAndTextEvent = procedure(Sender: TObject; TextValue: AnsiChar; Value: Single) of object;
  TVector2Event = procedure(Sender: TObject; Value: TVector2) of object;
  TTextEvent = procedure(Sender: TObject; Text: AnsiChar) of object;
  TColorEvent = procedure(Sender: TObject; Color: TColorB) of object;
  TColorHSVEvent = procedure(Sender: TObject; Color: TVector3) of object;
  TListViewEvent = procedure(Sender: TObject; scrollIndex, active: Integer) of object;

  { TButton }
  TButton = class(TControl)
  private
    FOnButtonClick: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnButtonClick: TNotifyEvent read FOnButtonClick write FOnButtonClick;
  end;


  { TImageButton }
  TImageButton = class(TControl)
  private
    FOnButtonClick: TNotifyEvent;
    FTexture: TTexture2D;
    FTextureLoaded: Boolean;
    FImageRect: TRectangle;
    FAutoSize: Boolean;
    FUseImageRect: Boolean;
    FPressOffset: Integer;
    FClickEffect: Boolean;
    FPressScale: Single;
    FIsPressed: Boolean;
    FPressStartTime: Double;
    procedure SetTexture(const Value: TTexture2D);
    procedure SetImageRect(const Value: TRectangle);
    procedure UpdateAutoSize;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure LoadTextureFromFile(const FileName: string);
    procedure LoadTextureFromImage(const Image: TImage);
    procedure UpdatePressState;
    property OnButtonClick: TNotifyEvent read FOnButtonClick write FOnButtonClick;
    property Texture: TTexture2D read FTexture write SetTexture;
    property ImageRect: TRectangle read FImageRect write SetImageRect;
    property AutoSize: Boolean read FAutoSize write FAutoSize;
    property UseImageRect: Boolean read FUseImageRect write FUseImageRect;
    property PressOffset: Integer read FPressOffset write FPressOffset;  // Смещение при нажатии (пиксели)
    property PressScale: Single read FPressScale write FPressScale;      // Масштаб при нажатии (0.9 = 90%)
    property ClickEffect: Boolean read FClickEffect write FClickEffect;  // Включить/выключить эффект
  end;

  { TToggleImageButton - кнопка-переключатель с изображением }
  TToggleImageButton = class(TControl)
  private
    FOnToggleClick: TBooleanEvent;
    FToggled: Boolean;
    FTextureOn: TTexture2D;
    FTextureOff: TTexture2D;
    FTextureLoadedOn: Boolean;
    FTextureLoadedOff: Boolean;
    FImageRect: TRectangle;
    FAutoSize: Boolean;
    FUseImageRect: Boolean;
    FPressOffset: Integer;
    FPressScale: Single;
    FClickEffect: Boolean;
    FIsPressed: Boolean;
    FPressStartTime: Double;
    FUseTextureRect: Boolean;
    FTextureRect: TRectangle;
    procedure SetTextureOn(const Value: TTexture2D);
    procedure SetTextureOff(const Value: TTexture2D);
    procedure SetImageRect(const Value: TRectangle);
    procedure UpdateAutoSize;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure LoadTextureFromFile(const OnFileName, OffFileName: string);
    procedure LoadTextureFromImage(const OnImage, OffImage: TImage);
    procedure UpdatePressState;
    property OnToggleClick: TBooleanEvent read FOnToggleClick write FOnToggleClick;
    property Toggled: Boolean read FToggled write FToggled;
    property TextureOn: TTexture2D read FTextureOn write SetTextureOn;
    property TextureOff: TTexture2D read FTextureOff write SetTextureOff;
    property ImageRect: TRectangle read FImageRect write SetImageRect;
    property AutoSize: Boolean read FAutoSize write FAutoSize;
    property UseImageRect: Boolean read FUseImageRect write FUseImageRect;
    property PressOffset: Integer read FPressOffset write FPressOffset;
    property PressScale: Single read FPressScale write FPressScale;
    property ClickEffect: Boolean read FClickEffect write FClickEffect;
  end;

  { TLabelButton }
  TLabelButton = class(TControl)
  private
    FOnButtonClick: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnButtonClick: TNotifyEvent read FOnButtonClick write FOnButtonClick;
  end;

  { TToggle }
  TToggle = class(TControl)
  private
    FOnToggleClick: TBooleanEvent;
    FToggle: Boolean;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnToggleClick: TBooleanEvent read FOnToggleClick write FOnToggleClick;
    property Toggle: Boolean read FToggle write FToggle;
  end;

  { TToggleGroup }
  TToggleGroup = class(TControl)
  private
    FActiveToggle: Integer;
    FOnToggleClick: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnToggleClick: TIntegerEvent read FOnToggleClick write FOnToggleClick;
    property ActiveToggle: Integer read FActiveToggle write FActiveToggle;
  end;

  { TToggleSlider }
  TToggleSlider = class(TControl)
  private
    FActiveToggle: Integer;
    FOnToggleClick: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnToggleClick: TIntegerEvent read FOnToggleClick write FOnToggleClick;
    property ActiveToggle: Integer read FActiveToggle write FActiveToggle;
  end;

  { TCheckBox }
  TCheckBox = class(TControl)
  private
    FChecked: Boolean;
    FOnChecked: TBooleanEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChecked: TBooleanEvent read FOnChecked write FOnChecked;
    property Checked: Boolean read FChecked  write FChecked;
  end;

  { TComboBox }

  TComboBox = class(TControl)
  private
    FActive: Integer;
    FOnChange: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TIntegerEvent read FOnChange write FOnChange;
    property Active: Integer read FActive write FACtive;
  end;

  { TDropdownBox }

  TDropdownBox = class(TControl)
  private
    FActive: Integer;
    FEditMode: Boolean;
    FOnChange: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TIntegerEvent read FOnChange write FOnChange;
    property Active: Integer read FActive write FACtive;
  end;

  { TSpinner }

  TSpinner = class(TControl)
  private
    FMaxValue: Integer;
    FMinValue: Integer;
    FValue: Integer;
    FEditMode: Boolean;
    FOnChange: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TIntegerEvent read FOnChange write FOnChange;
    property Value: Integer read FValue write FValue;
    property MaxValue: Integer read FMaxValue write FMaxValue;
    property MinValue: Integer read FMinValue write FMinValue;
    Property EditMode: Boolean read FEditMode write FEditMode;
  end;

  { TValueBox }

  TValueBox = class(TControl)
  private
    FMaxValue: Integer;
    FMinValue: Integer;
    FValue: Integer;
    FEditMode: Boolean;
    FOnChange: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TIntegerEvent read FOnChange write FOnChange;
    property Value: Integer read FValue write FValue;
    property MaxValue: Integer read FMaxValue write FMaxValue;
    property MinValue: Integer read FMinValue write FMinValue;
    Property EditMode: Boolean read FEditMode write FEditMode;
  end;

  { TValueFloat }
  TValueFloat = class(TControl)
  private
    FText: AnsiChar;
    FValue: Single;
    FEditMode: Boolean;
    FOnChange: TSingleAndTextEvent;
    FTextValue: AnsiChar;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TSingleAndTextEvent read FOnChange write FOnChange;
    property Value: Single read FValue write FValue;
    property TextValue: AnsiChar read FTextValue write FTextValue;
    Property EditMode: Boolean read FEditMode write FEditMode;
  end;

  { TTextBox }

  TTextBox = class(TControl)
  private
    FEditMode: Boolean;
    FOnChange: TTextEvent;
    FTextSize: Integer;
    FText: AnsiChar;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TTextEvent read FOnChange write FOnChange;
    property TextSize: Integer read FTextSize write FTextSize;
  end;

  { TStatusBar }
  TStatusBar = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
  end;

  { TDummyRec }
  TDummyRec = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
  end;

  { TGrid }
  TGrid = class(TControl)
  private
    FmouseCell: TVector2;
    FOnMouseCell: TVector2Event;
    FSpacing: single;
    FSubdivs: integer;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnMouseCell: TVector2Event read FOnMouseCell write FOnMouseCell;
    property Spacing: single read FSpacing write FSpacing;
    property Subdivs: integer read FSubdivs write FSubdivs;
  end;

  { TListView }
  TListView = class(TControl)
  private
    FActive, FscrollIndex: Integer;
    FOnChange: TListViewEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TListViewEvent read FOnChange write FOnChange;
    property ScrollIndex: Integer read  FScrollIndex;
    property Active: Integer read FActive;
  end;

  { TTabBar }

  TTabBar = class(TControl)
  private
    FActive: Integer;
    FCount: integer;
    FOnChange: TIntegerEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnChange: TIntegerEvent read FOnChange write FOnChange;
    property Active: integer read FActive write FActive;
  end;

  { TLabel }
  TLabel = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
  end;

  { TPanel }
  TPanel = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
  end;

  { TSimplePanel }
  TSimplePanel = class(TControl)
  private
    FAreaColor: TColorB;
    FBorderColor: TColorB;
    FColorAsBackground: Boolean;
    FDrawBorder: Boolean;
    FUsesStyleColor: Boolean;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property UsesStyleColor: Boolean read FUsesStyleColor write FUsesStyleColor;
    property DrawBorder: Boolean read FDrawBorder write FDrawBorder;
    property BorderColor: TColorB read FBorderColor write FBorderColor;
    property AreaColor: TColorB read FAreaColor write FAreaColor;
    property ColorAsBackground: Boolean read FColorAsBackground write FColorAsBackground;
  end;

  { TColorPanel }
  TColorPanel = class(TControl)
  private
    FColor: TColorB;
    FOnColor: TColorEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property Color: TColorB read FColor write FColor;
    property OnColor: TColorEvent read FOnColor write FOnColor;
  end;

  { TColorPanelHSV }
  TColorPanelHSV = class(TControl)
  private
    FColorHSV: TVector3;
    FOnColor: TColorHSVEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property Color: TVector3 read FColorHSV write FColorHSV;
    property OnColor: TColorHSVEvent read FOnColor write FOnColor;
  end;

  { TColorPicker }
  TColorPicker = class(TControl)
  private
    FColor: TColorB;
    FOnColor: TColorEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property Color: TColorB read FColor write FColor;
    property OnColor: TColorEvent read FOnColor write FOnColor;
  end;

  { TColorPickerHSV }
  TColorPickerHSV = class(TControl)
  private
    FColorHSV: TVector3;
    FOnColor: TColorHSVEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property Color: TVector3 read FColorHSV write FColorHSV;
    property OnColor: TColorHSVEvent read FOnColor write FOnColor;
  end;

  { TLine }
  TLine = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
  end;

  { TSlider }
  TSlider = class(TControl)
  private
    FCaptionRight: String;
    FMaxValue: Single;
    FMinValue: Single;
    FOnSliderChange: TSingleEvent;
    FValue: Single;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnSliderChange: TSingleEvent read FOnSliderChange write FOnSliderChange;
    property MinValue: Single read FMinValue write FMinValue;
    property MaxValue: Single read FMaxValue write FMaxValue;
    property Value: Single read FValue write FValue;
    property CaptionRight: String read FCaptionRight write FCaptionRight;
  end;

  { TSliderBar }
  TSliderBar = class(TControl)
  private
    FCaptionRight: String;
    FMaxValue: Single;
    FMinValue: Single;
    FOnSliderChange: TSingleEvent;
    FValue: Single;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnSliderChange: TSingleEvent read FOnSliderChange write FOnSliderChange;
    property MinValue: Single read FMinValue write FMinValue;
    property MaxValue: Single read FMaxValue write FMaxValue;
    property Value: Single read FValue write FValue;
    property CaptionRight: String read FCaptionRight write FCaptionRight;
  end;

  { TProgressBar }
  TProgressBar = class(TControl)
  private
    FCaptionRight: String;
    FMaxValue: Single;
    FMinValue: Single;
    FOnProgressChange: TSingleEvent;
    FValue: Single;
  protected
    procedure Paint; override;
  public
    constructor Create(AParent: TControl = nil);
    property OnProgressChange: TSingleEvent read FOnProgressChange write FOnProgressChange;
    property MinValue: Single read FMinValue write FMinValue;
    property MaxValue: Single read FMaxValue write FMaxValue;
    property Value: Single read FValue write FValue;
    property CaptionRight: String read FCaptionRight write FCaptionRight;
  end;

implementation

{ TButton }

procedure TButton.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiButton(R, PAnsiChar(Caption)) = 1 then
  begin
    if Assigned(FOnButtonClick) then FOnButtonClick(Self);
  end;
end;

constructor TButton.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 28;
  Height := 28;
  Top := 10;
  Left := 10;
end;

{ TImageButton }

constructor TImageButton.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 64;
  Height := 64;
  Top := 10;
  Left := 10;
  FTextureLoaded := False;
  FAutoSize := True;
  FUseImageRect := False;
  FImageRect := RectangleCreate(0, 0, 0, 0);
  FPressOffset := 2;      // Смещение на 2 пикселя при нажатии
  FPressScale := 0.95;    // Уменьшение до 95% при нажатии
  FClickEffect := True;   // Эффекты включены по умолчанию
  FIsPressed := False;
  FPressStartTime := 0;
end;

destructor TImageButton.Destroy;
begin
  if FTextureLoaded then
    UnloadTexture(FTexture);
  inherited Destroy;
end;

procedure TImageButton.SetTexture(const Value: TTexture2D);
begin
  if FTextureLoaded then
    UnloadTexture(FTexture);
  FTexture := Value;
  FTextureLoaded := True;
  UpdateAutoSize;
end;

procedure TImageButton.SetImageRect(const Value: TRectangle);
begin
  FImageRect := Value;
  FUseImageRect := True;
  UpdateAutoSize;
end;

procedure TImageButton.UpdateAutoSize;
begin
  if FAutoSize and FTextureLoaded then
  begin
    if FUseImageRect and (FImageRect.width > 0) and (FImageRect.height > 0) then
    begin
      Width := Round(FImageRect.width);
      Height := Round(FImageRect.height);
    end
    else
    begin
      Width := FTexture.width;
      Height := FTexture.height;
    end;
  end;
end;

procedure TImageButton.LoadTextureFromFile(const FileName: string);
begin
  if FTextureLoaded then
    UnloadTexture(FTexture);
  FTexture := LoadTexture(PAnsiChar(FileName));
  FTextureLoaded := True;
  SetTextureFilter(FTexture, TEXTURE_FILTER_BILINEAR);
  UpdateAutoSize;
end;

procedure TImageButton.LoadTextureFromImage(const Image: TImage);
begin
  if FTextureLoaded then
    UnloadTexture(FTexture);
  FTexture := raylib.LoadTextureFromImage(Image);
  FTextureLoaded := True;
  UpdateAutoSize;
end;

procedure TImageButton.UpdatePressState;
begin
  // Сбрасываем состояние нажатия через 0.1 секунды
  if FIsPressed and (FClickEffect) then
  begin
    if (GetTime() - FPressStartTime) >= 0.1 then
      FIsPressed := False;
  end;
end;

procedure TImageButton.Paint;
var
  R, DrawRect: TRectangle;
  SourceRect: TRectangle;
  MousePoint: TVector2;
  IsHovered: Boolean;
  DrawOffsetX, DrawOffsetY: Integer;
  DrawWidth, DrawHeight: Integer;
  Scale: Single;
  ColorMod: TColorB;
begin
  if not FTextureLoaded then Exit;

  // Обновляем состояние нажатия
  UpdatePressState;

  // Базовый прямоугольник
  R := RectangleCreate(Left, Top, Width, Height);
  MousePoint := GetMousePosition;
  IsHovered := CheckCollisionPointRec(MousePoint, R);

  // Определяем исходный прямоугольник текстуры
  if FUseImageRect and (FImageRect.width > 0) and (FImageRect.height > 0) then
    SourceRect := FImageRect
  else
    SourceRect := RectangleCreate(0, 0, FTexture.width, FTexture.height);

  // Эффекты нажатия
  if FClickEffect and FIsPressed then
  begin
    // Масштабирование
    Scale := FPressScale;
    DrawWidth := Round(Width * Scale);
    DrawHeight := Round(Height * Scale);
    DrawOffsetX := (Width - DrawWidth) div 2;
    DrawOffsetY := (Height - DrawHeight) div 2;

    DrawRect := RectangleCreate(
      Left + DrawOffsetX + FPressOffset,
      Top + DrawOffsetY + FPressOffset,
      DrawWidth,
      DrawHeight
    );

    // Затемнение при нажатии
    ColorMod := ColorCreate(180, 180, 180, 255);
  end
  else if FClickEffect and IsHovered then
  begin
    // Эффект наведения - немного светлее
    DrawRect := RectangleCreate(Left, Top, Width, Height);
    ColorMod := ColorCreate(230, 230, 230, 255);
  end
  else
  begin
    // Обычное состояние
    DrawRect := RectangleCreate(Left, Top, Width, Height);
    ColorMod := ColorAlpha(WHITE, 0.7);
  end;

  // Рисуем текстуру
  DrawTexturePro(FTexture, SourceRect, DrawRect, Vector2Create(0, 0), 0, ColorMod);

  // Рисуем рамку при наведении
 // if IsHovered and not FIsPressed then
  //  DrawRectangleLines(Left, Top, Width, Height, ColorCreate(255, 255, 255, 200));

  // Эффект "вдавленности" при нажатии
 { if FClickEffect and FIsPressed then
  begin
    DrawRectangleLinesEx(
      RectangleCreate(
        Left + FPressOffset,
        Top + FPressOffset,
        Width - FPressOffset * 2,
        Height - FPressOffset * 2
      ),
      1,
      ColorCreate(100, 100, 100, 150)
    );
  end; }

  // Обработка клика
  if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and IsHovered then
  begin
    FIsPressed := True;
    FPressStartTime := GetTime(); // Запоминаем время нажатия

    if Assigned(FOnButtonClick) then
      FOnButtonClick(Self);
  end;
end;

{ TToggleImageButton }

constructor TToggleImageButton.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 64;
  Height := 64;
  Top := 10;
  Left := 10;
  FToggled := False;
  FTextureLoadedOn := False;
  FTextureLoadedOff := False;
  FAutoSize := True;
  FUseImageRect := False;
  FImageRect := RectangleCreate(0, 0, 0, 0);
  FPressOffset := 2;
  FPressScale := 0.95;
  FClickEffect := True;
  FIsPressed := False;
  FPressStartTime := 0;
end;

destructor TToggleImageButton.Destroy;
begin
  if FTextureLoadedOn then
    UnloadTexture(FTextureOn);
  if FTextureLoadedOff then
    UnloadTexture(FTextureOff);
  inherited Destroy;
end;

procedure TToggleImageButton.SetTextureOn(const Value: TTexture2D);
begin
  if FTextureLoadedOn then
    UnloadTexture(FTextureOn);
  FTextureOn := Value;
  FTextureLoadedOn := True;
  UpdateAutoSize;
end;

procedure TToggleImageButton.SetTextureOff(const Value: TTexture2D);
begin
  if FTextureLoadedOff then
    UnloadTexture(FTextureOff);
  FTextureOff := Value;
  FTextureLoadedOff := True;
  UpdateAutoSize;
end;

procedure TToggleImageButton.SetImageRect(const Value: TRectangle);
begin
  FImageRect := Value;
  FUseImageRect := True;
  UpdateAutoSize;
end;

procedure TToggleImageButton.UpdateAutoSize;
begin
  if not FAutoSize then Exit;

  if FUseImageRect and (FImageRect.width > 0) and (FImageRect.height > 0) then
  begin
    Width := Round(FImageRect.width);
    Height := Round(FImageRect.height);
  end
  else if FToggled and FTextureLoadedOn then
  begin
    Width := FTextureOn.width;
    Height := FTextureOn.height;
  end
  else if not FToggled and FTextureLoadedOff then
  begin
    Width := FTextureOff.width;
    Height := FTextureOff.height;
  end;
end;

procedure TToggleImageButton.LoadTextureFromFile(const OnFileName, OffFileName: string);
begin
  if FTextureLoadedOn then
    UnloadTexture(FTextureOn);
  if FTextureLoadedOff then
    UnloadTexture(FTextureOff);

  FTextureOn := LoadTexture(PAnsiChar(OnFileName));
  FTextureOff := LoadTexture(PAnsiChar(OffFileName));
  FTextureLoadedOn := True;
  FTextureLoadedOff := True;

  SetTextureFilter(FTextureOn, TEXTURE_FILTER_BILINEAR);
  SetTextureFilter(FTextureOff, TEXTURE_FILTER_BILINEAR);
  UpdateAutoSize;
end;

procedure TToggleImageButton.LoadTextureFromImage(const OnImage, OffImage: TImage);
begin
  if FTextureLoadedOn then
    UnloadTexture(FTextureOn);
  if FTextureLoadedOff then
    UnloadTexture(FTextureOff);

  FTextureOn := raylib.LoadTextureFromImage(OnImage);
  FTextureOff := raylib.LoadTextureFromImage(OffImage);
  FTextureLoadedOn := True;
  FTextureLoadedOff := True;
  UpdateAutoSize;
end;

procedure TToggleImageButton.UpdatePressState;
begin
  if FIsPressed and FClickEffect then
  begin
    if (GetTime() - FPressStartTime) >= 0.1 then
      FIsPressed := False;
  end;
end;

procedure TToggleImageButton.Paint;
var
  R, DrawRect: TRectangle;
  SourceRect: TRectangle;
  MousePoint: TVector2;
  IsHovered: Boolean;
  DrawOffsetX, DrawOffsetY: Integer;
  DrawWidth, DrawHeight: Integer;
  Scale: Single;
  ColorMod: TColorB;
  CurrentTexture: TTexture2D;
begin
  // Выбор текущей текстуры в зависимости от состояния
  if FToggled then
  begin
    if not FTextureLoadedOn then Exit;
    CurrentTexture := FTextureOn;
  end
  else
  begin
    if not FTextureLoadedOff then Exit;
    CurrentTexture := FTextureOff;
  end;

  UpdatePressState;

  R := RectangleCreate(Left, Top, Width, Height);
  MousePoint := GetMousePosition;
  IsHovered := CheckCollisionPointRec(MousePoint, R);

  if FUseImageRect and (FImageRect.width > 0) and (FImageRect.height > 0) then
    SourceRect := FImageRect
  else
    SourceRect := RectangleCreate(0, 0, CurrentTexture.width, CurrentTexture.height);

  if FClickEffect and FIsPressed then
  begin
    Scale := FPressScale;
    DrawWidth := Round(Width * Scale);
    DrawHeight := Round(Height * Scale);
    DrawOffsetX := (Width - DrawWidth) div 2;
    DrawOffsetY := (Height - DrawHeight) div 2;

    DrawRect := RectangleCreate(
      Left + DrawOffsetX + FPressOffset,
      Top + DrawOffsetY + FPressOffset,
      DrawWidth,
      DrawHeight
    );
    ColorMod := ColorCreate(180, 180, 180, 255);
  end
  else if FClickEffect and IsHovered then
  begin
    DrawRect := RectangleCreate(Left, Top, Width, Height);
    ColorMod := ColorCreate(230, 230, 230, 255);
  end
  else
  begin
    DrawRect := RectangleCreate(Left, Top, Width, Height);
    ColorMod := ColorAlpha(WHITE, 0.7);
  end;

  DrawTexturePro(CurrentTexture, SourceRect, DrawRect, Vector2Create(0, 0), 0, ColorMod);

  // Обработка клика - переключение состояния
  if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and IsHovered then
  begin
    FIsPressed := True;
    FPressStartTime := GetTime();
    FToggled := not FToggled;  // Переключаем состояние
    UpdateAutoSize;            // Обновляем размер при AutoSize

    if Assigned(FOnToggleClick) then
      FOnToggleClick(Self, FToggled);
  end;
end;


{ TLabelButton }

procedure TLabelButton.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiLabelButton(R, PAnsiChar(Caption)) = 1 then
  begin
    if Assigned(FOnButtonClick) then FOnButtonClick(Self);
  end;
end;

constructor TLabelButton.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 28;
  Height := 28;
  Top := 10;
  Left := 10;
end;

{ TToggle }

procedure TToggle.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiToggle(R, PAnsiChar(Caption), @FToggle) = 0 then
  begin
    if Assigned(FOnToggleClick) then FOnToggleClick(Self, FToggle);
  end;
end;

constructor TToggle.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 28;
  Height := 28;
  Top := 10;
  Left := 10;
end;

{ TToggleGroup }

procedure TToggleGroup.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiToggleGroup(R, PAnsiChar(Caption), @FActiveToggle) > -1 then
  begin
    if Assigned(FOnToggleClick) then FOnToggleClick(Self, FActiveToggle);
  end;
end;

constructor TToggleGroup.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 100;
  Height := 100;
  Top := 10;
  Left := 10;
end;

{ TToggleSlider }

procedure TToggleSlider.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiToggleSlider(R, PAnsiChar(Caption), @FActiveToggle) > -1 then
  begin
    if Assigned(FOnToggleClick) then FOnToggleClick(Self, FActiveToggle);
  end;
end;

constructor TToggleSlider.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 100;
  Height := 100;
  Top := 10;
  Left := 10;
end;

{ TCheckBox }

procedure TCheckBox.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiCheckBox(R, PAnsiChar(Caption), @FChecked) = 0 then
  begin
    if Assigned(FOnChecked) then FOnChecked(Self, FChecked);
  end;
end;

constructor TCheckBox.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
  FChecked:=False;
end;

{ TComboBox }

procedure TComboBox.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiComboBox(R, PAnsiChar(Caption), @FActive) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self, FActive);
  end;
end;

constructor TComboBox.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;

end;

{ TDropdownBox }

procedure TDropdownBox.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiDropdownBox(R, PAnsiChar(Caption), @FActive, FEditMode) > 0 then
  begin
    FEditMode := not FEditMode;
    if Assigned(FOnChange) then FOnChange(Self, FActive);
  end;
end;

constructor TDropdownBox.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
  FEditMode := False;
end;

{ TSpinner }

procedure TSpinner.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);

  if  CheckCollisionPointRec(GetMousePosition, R) then
  FEditMode := true else FEditMode := false;

  if GuiSpinner(R, PAnsiChar(Caption), @FValue, FMinValue, FMaxValue, FEditMode) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self, FValue);
  end;
end;

constructor TSpinner.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
  FEditMode := False;
  FMinValue := 0;
  FMaxValue := 100;
end;

{ TValueBox }

procedure TValueBox.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);

  if  CheckCollisionPointRec(GetMousePosition, R) then
  FEditMode := true else FEditMode := false;

  if GuiValueBox(R, PAnsiChar(Caption), @FValue, FMinValue, FMaxValue, FEditMode) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self, FValue);
  end;
end;

constructor TValueBox.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
  FEditMode := False;
  FMinValue := 0;
  FMaxValue := 100;
end;

{ TValueFloat }

procedure TValueFloat.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);

  if  CheckCollisionPointRec(GetMousePosition, R) then
  FEditMode := true else FEditMode := false;

  if GuiValueBoxFloat(R, PAnsiChar(Caption), @FTextValue, @FValue, FEditMode) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self, FTextValue, FValue);
  end;
end;

constructor TValueFloat.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;

  FEditMode := False;
end;

{ TTextBox }

procedure TTextBox.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);

  if  CheckCollisionPointRec(GetMousePosition, R) then
  FEditMode := true else FEditMode := false;

  if GuiTextBox(R, @FText, FTextSize, FEditMode) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self, FText);
  end;
end;

constructor TTextBox.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
  FEditMode := False;
  FTextSize := 40;
end;

{ TStatusBar }

procedure TStatusBar.Paint;
var R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  GuiStatusBar(R, PAnsiChar(Caption));
end;

constructor TStatusBar.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
end;

{ TDummyRec }

procedure TDummyRec.Paint;
var R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  GuiDummyRec(R, PAnsiChar(Caption));
end;

constructor TDummyRec.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 20;
  Top := 10;
  Left := 10;
end;

{ TGrid }

procedure TGrid.Paint;
var
  R: TRectangle;
begin     // GetMousePosition
  //FOnMouseCell
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiGrid(R, PAnsiChar(Caption), FSpacing, FSubdivs, @FMouseCell) = 0 then
  begin
    if Assigned(FOnMouseCell) then FOnMouseCell(Self, FmouseCell);
  end;
end;

constructor TGrid.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 200;
  Top := 10;
  Left := 10;
  FSpacing := 64;
  FSubdivs := 4;
end;

{ TListView }

constructor TListView.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 120;
  Height := 200;
  Top := 10;
  Left := 10;
end;

procedure TListView.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiListView(R, PAnsiChar(Caption), @FScrollIndex, @FActive) = 0 then
  begin
    if Assigned(FOnChange) then FOnChange(Self,FScrollIndex, FActive);
  end;
end;

{ TTabBar }

constructor TTabBar.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 80;
  Height := 24;
  Top := 10;
  Left := 10;
  FActive := 0;
  FCount := 3;
end;

procedure TTabBar.Paint;
var
  R: TRectangle;
  Tabs: array of PAnsiChar;
  TabText: string;
  i, StartPos, TabIndex, EndPos: Integer;
  TabName: string;
  TempStrings: array of string;  // Храним строки отдельно
begin
  R := RectangleCreate(Left, Top, Width, Height);

  TabText := Caption;

  if TabText = '' then
    TabText := 'One;Two;Three';

  // Подсчитываем количество табов
  FCount := 1;
  for i := 1 to Length(TabText) do
    if TabText[i] = ';' then
      Inc(FCount);

  // Создаем массивы
  SetLength(Tabs, FCount);
  SetLength(TempStrings, FCount);

  StartPos := 1;
  TabIndex := 0;

  for i := 1 to Length(TabText) do
  begin
    if (TabText[i] = ';') or (i = Length(TabText)) then
    begin
      if TabText[i] = ';' then
        EndPos := i - 1
      else
        EndPos := i;

      // Сохраняем строку во временный массив
      TempStrings[TabIndex] := Copy(TabText, StartPos, EndPos - StartPos + 1);
      // Берем указатель на сохраненную строку
      Tabs[TabIndex] := PAnsiChar(TempStrings[TabIndex]);
      Inc(TabIndex);
      StartPos := i + 1;
    end;
  end;

  // Вызов GuiTabBar
  if FCount > 0 then
  begin
    if GuiTabBar(R, @Tabs[0], FCount, @FActive) >= 0 then
    begin
      if Assigned(FOnChange) then
        FOnChange(Self, FActive);
    end;
  end;
end;



{ TLabel }
procedure TLabel.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  GuiLabel(R, PAnsiChar(Caption));
end;

constructor TLabel.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 30;
  Top := 10;
  Left := 10;
end;

{ TPanel }

constructor TPanel.Create(AParent: TControl = nil);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
end;

procedure TPanel.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  GuiPanel(R, PAnsiChar(Caption));
end;

{ TSimplePanel }

procedure TSimplePanel.Paint;
var TmpColor: TColorB;
begin
  if FUsesStyleColor then
    TmpColor := GetColor(GuiGetStyle(UILABEL, BASE_COLOR_NORMAL))
  else
    TmpColor := FAreaColor;

  if FColorAsBackground then
   GetColor(GuiGetStyle(DEFAULT, BACKGROUND_COLOR));

  DrawRectangle(Left, Top, Width, Height, TmpColor);

  if FUsesStyleColor then
    TmpColor := GetColor(GuiGetStyle(Default, BORDER_COLOR_NORMAL))
  else
    TmpColor := FBorderColor;

  if FDrawBorder then
  begin

    DrawRectangleLines(Left, Top, Width, Height, TmpColor);
  end;
end;

constructor TSimplePanel.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
  FBorderColor := Black;
  FAreaColor := RayWhite;
  FUsesStyleColor := True;
  FDrawBorder := True;
  FColorAsBackground := False;
end;

{ TColorPanel }

procedure TColorPanel.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiColorPanel(R, PAnsiChar(Caption), @FColor) = 0 then
  begin
    if Assigned(FOnColor) then FOnColor(Self, FColor);
  end;
end;

constructor TColorPanel.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
  FColor := RED;
end;

{ TColorPanelHSV }

procedure TColorPanelHSV.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiColorPanelHSV(R, PAnsiChar(Caption), @FColorHSV) = 0 then
  begin
    if Assigned(FOnColor) then FOnColor(Self, FColorHSV);
  end;
end;

constructor TColorPanelHSV.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
  FColorHSV := Vector3Create(125, 124, 124);
end;

{ TColorPicker }

procedure TColorPicker.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiColorPicker(R, PAnsiChar(Caption), @FColor) = 0 then
  begin
    if Assigned(FOnColor) then FOnColor(Self, FColor);
  end;
end;

constructor TColorPicker.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
  FColor := BLUE;
end;

{ TColorPickerHSV }

procedure TColorPickerHSV.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiColorPickerHSV(R, PAnsiChar(Caption), @FColorHSV) = 0 then
  begin
    if Assigned(FOnColor) then FOnColor(Self, FColorHSV);
  end;
end;

constructor TColorPickerHSV.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 150;
  FColorHSV := Vector3Create(125, 124, 124);
end;

{ TLine }

procedure TLine.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  GuiLine(R, PAnsiChar(Caption));
end;

constructor TLine.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 200;
  Height := 30;
end;

{ TSlider }

procedure TSlider.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiSlider(R, PAnsiChar(Caption), PAnsiChar(CaptionRight), @FValue, FMinValue, FMaxValue) = 1 then
  begin
    if Assigned(OnSliderChange) then OnSliderChange(Self, Value);
  end;
end;

constructor TSlider.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 128;
  Height := 20;
  Top := 10;
  Left := 10;
  FMinValue := 0;
  FMaxValue := 1;
end;

{ TSliderBar }

procedure TSliderBar.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiSliderBar(R, PAnsiChar(Caption), PAnsiChar(CaptionRight), @FValue, FMinValue, FMaxValue) = 1 then
  begin
    if Assigned(OnSliderChange) then OnSliderChange(Self, Value);
  end;
end;

constructor TSliderBar.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 128;
  Height := 20;
  Top := 10;
  Left := 10;
  FMinValue := 0;
  FMaxValue := 1;
end;

{ TProgressBar }

procedure TProgressBar.Paint;
var
  R: TRectangle;
begin
  R := RectangleCreate(Left, Top, Width, Height);
  if GuiProgressBar(R, PAnsiChar(Caption), PAnsiChar(CaptionRight), @FValue, FMinValue, FMaxValue) = 1 then
  begin
    if Assigned(OnProgressChange) then OnProgressChange(Self, Value);
  end;
end;

constructor TProgressBar.Create(AParent: TControl);
begin
  inherited Create(AParent);
  Width := 128;
  Height := 20;
  Top := 10;
  Left := 10;
  FMinValue := 0;
  FMaxValue := 1;
end;

end.
