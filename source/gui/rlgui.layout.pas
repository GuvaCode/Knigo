unit rlgui.layout;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  raylib, raygui, Classes, SysUtils;

type
  TAlign = (alNone, alLeft, alTop, alRight, alBottom, alClient);

  TMargins = record
    Left: Integer;
    Top: Integer;
    Right: Integer;
    Bottom: Integer;

    procedure SetMargins(ALeft, ATop, ARight, ABottom: Integer);
    procedure SetAll(AValue: Integer);
  end;

  { TControl }

  TControl = class
  private
    FHint: string;
    FParent: TControl;
    FChildren: TList;
    FLeft: Integer;
    FTextAlignment: TGuiTextAlignment;
    FTextAlignmentVertical: TGuiTextAlignmentVertical;
    FTextWrapMode: TGuiTextWrapMode;
    FTop: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FAlign: TAlign;
    FVisible: Boolean;
    FCaption: string;
    FMargins: TMargins;
    FClientMargins: TMargins;
    FRelativeLeft: Integer;
    FRelativeTop: Integer;
    function GetComponentCount: Integer;
  protected
    procedure AlignControls; virtual;
    procedure Paint; virtual; abstract;
    function GetClientLeft: Integer; virtual;
    function GetClientTop: Integer; virtual;
    function GetClientRight: Integer; virtual;
    function GetClientBottom: Integer; virtual;

  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure AddChild(Child: TControl);
    procedure SetPosition(AX, AY: Integer);
    procedure Draw;
    procedure DrawTooltip;
    procedure UpdateLayout;
    property ComponentCount: Integer read GetComponentCount;
    property Children: TList read FChildren write FChildren;
    property Parent: TControl read FParent;
    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
    property Align: TAlign read FAlign write FAlign;
    property Visible: Boolean read FVisible write FVisible;
    property Caption: string read FCaption write FCaption;
    property Hint: string read FHint write FHint;
    property Margins: TMargins read FMargins write FMargins;
    property ClientMargins: TMargins read FClientMargins write FClientMargins;
    property TextAlignment: TGuiTextAlignment read FTextAlignment write FTextAlignment;
    property TextWrapMode: TGuiTextWrapMode read FTextWrapMode write FTextWrapMode;
    property TextAlignmentVertical: TGuiTextAlignmentVertical read FTextAlignmentVertical write FTextAlignmentVertical;
  end;

  { TRootControl }

  TGuiManager = class(TControl)
  private
  protected
    procedure Paint; override;
  public
    constructor Create;
    procedure Run;
  end;

implementation

{ TMargins }

procedure TMargins.SetMargins(ALeft, ATop, ARight, ABottom: Integer);
begin
  Left := ALeft;
  Top := ATop;
  Right := ARight;
  Bottom := ABottom;
end;

procedure TMargins.SetAll(AValue: Integer);
begin
  Left := AValue;
  Top := AValue;
  Right := AValue;
  Bottom := AValue;
end;

{ TControl }

constructor TControl.Create(AParent: TControl = nil);
begin
  inherited Create;
  FChildren := TList.Create;
  FParent := AParent;
  FWidth := 100;
  FHeight := 100;
  FAlign := alNone;
  FVisible := True;
  FCaption := '';
  FMargins.SetMargins(0, 0, 0, 0);
  FClientMargins.SetMargins(0, 0, 0, 0);
  FRelativeLeft := 0;
  FRelativeTop := 0;
  FTextAlignmentVertical := TEXT_ALIGN_MIDDLE;
  GuiEnableTooltip();
  if FParent <> nil then
    FParent.AddChild(Self);
end;

destructor TControl.Destroy;
var
  i: Integer;
begin
  for i := 0 to FChildren.Count - 1 do
    TControl(FChildren[i]).Free;
  FChildren.Free;
  inherited Destroy;
end;

procedure TControl.AddChild(Child: TControl);
begin
  FChildren.Add(Child);
  UpdateLayout;
end;

procedure TControl.UpdateLayout;
begin
  AlignControls;
end;

function TControl.GetClientLeft: Integer;
begin
  Result := Left + FClientMargins.Left;
end;

function TControl.GetClientTop: Integer;
begin
  Result := Top + FClientMargins.Top;
end;

function TControl.GetClientRight: Integer;
begin
  Result := Left + Width - FClientMargins.Right;
end;

function TControl.GetClientBottom: Integer;
begin
  Result := Top + Height - FClientMargins.Bottom;
end;

procedure TControl.SetPosition(AX, AY: Integer);
begin
  if FAlign = alNone then
  begin
    FRelativeLeft := AX;
    FRelativeTop := AY;
    if FParent <> nil then
    begin
      FLeft := FParent.GetClientLeft + AX;
      FTop := FParent.GetClientTop + AY;
    end
    else
    begin
      FLeft := AX;
      FTop := AY;
    end;
  end
  else
  begin
    FLeft := AX;
    FTop := AY;
  end;
end;

function TControl.GetComponentCount: Integer;
begin
  result := FChildren.Count;
end;

procedure TControl.AlignControls;
var
  i: Integer;
  c: TControl;
  ClientLeft, ClientTop, ClientRight, ClientBottom: Integer;
  AvailableLeft, AvailableTop, AvailableRight, AvailableBottom: Integer;
begin
  ClientLeft := GetClientLeft;
  ClientTop := GetClientTop;
  ClientRight := GetClientRight;
  ClientBottom := GetClientBottom;

  // Начальная доступная область
  AvailableLeft := 0;
  AvailableTop := 0;
  AvailableRight := ClientRight - ClientLeft;
  AvailableBottom := ClientBottom - ClientTop;

  // ПРОХОД 1: alTop (сверху вниз)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alTop) then Continue;

    c.Left := ClientLeft + AvailableLeft + c.Margins.Left;
    c.Top := ClientTop + AvailableTop + c.Margins.Top;
    c.Width := (AvailableRight - AvailableLeft) - c.Margins.Left - c.Margins.Right;
    if c.Width < 0 then c.Width := 0;

    // Сдвигаем верхнюю границу вниз
    AvailableTop := AvailableTop + c.Height + c.Margins.Top + c.Margins.Bottom;
  end;

  // ПРОХОД 2: alBottom (снизу вверх)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alBottom) then Continue;

    c.Width := (AvailableRight - AvailableLeft) - c.Margins.Left - c.Margins.Right;
    if c.Width < 0 then c.Width := 0;
    c.Left := ClientLeft + AvailableLeft + c.Margins.Left;
    c.Top := ClientTop + AvailableBottom - c.Height - c.Margins.Bottom;

    // Сдвигаем нижнюю границу вверх
    AvailableBottom := AvailableBottom - c.Height - c.Margins.Top - c.Margins.Bottom;
  end;

  // ПРОХОД 3: alLeft (слева направо)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alLeft) then Continue;

    c.Top := ClientTop + AvailableTop + c.Margins.Top;
    c.Left := ClientLeft + AvailableLeft + c.Margins.Left;
    c.Height := (AvailableBottom - AvailableTop) - c.Margins.Top - c.Margins.Bottom;
    if c.Height < 0 then c.Height := 0;

    // Сдвигаем левую границу вправо
    AvailableLeft := AvailableLeft + c.Width + c.Margins.Left + c.Margins.Right;
  end;

  // ПРОХОД 4: alRight (справа налево)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alRight) then Continue;

    c.Height := (AvailableBottom - AvailableTop) - c.Margins.Top - c.Margins.Bottom;
    if c.Height < 0 then c.Height := 0;
    c.Top := ClientTop + AvailableTop + c.Margins.Top;
    c.Left := ClientLeft + AvailableRight - c.Width - c.Margins.Right;

    // Сдвигаем правую границу влево
    AvailableRight := AvailableRight - c.Width - c.Margins.Left - c.Margins.Right;
  end;

  // ПРОХОД 5: alClient (заполняет оставшееся пространство)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alClient) then Continue;

    c.Left := ClientLeft + AvailableLeft + c.Margins.Left;
    c.Top := ClientTop + AvailableTop + c.Margins.Top;
    c.Width := (AvailableRight - AvailableLeft) - c.Margins.Left - c.Margins.Right;
    c.Height := (AvailableBottom - AvailableTop) - c.Margins.Top - c.Margins.Bottom;
    if c.Width < 0 then c.Width := 0;
    if c.Height < 0 then c.Height := 0;
  end;

  // ПРОХОД 6: alNone (абсолютное позиционирование)
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    if (not c.Visible) or (c.Align <> alNone) then Continue;

    c.Left := ClientLeft + c.FRelativeLeft;
    c.Top := ClientTop + c.FRelativeTop;
  end;

  // Рекурсивно выравниваем дочерние элементы
  for i := 0 to FChildren.Count - 1 do
  begin
    c := TControl(FChildren[i]);
    c.AlignControls;
  end;
end;

procedure TControl.Draw;
var
  i: Integer;
begin
  if not Visible then Exit;

  UpdateLayout;

  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, TextAlignment);
  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT_VERTICAL, TextAlignmentVertical);
  GuiSetStyle(DEFAULT, TEXT_WRAP_MODE, TextWrapMode);

  Paint;

  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, TEXT_ALIGN_LEFT);
  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT_VERTICAL, TEXT_ALIGN_MIDDLE);
  GuiSetStyle(DEFAULT, TEXT_WRAP_MODE, TEXT_WRAP_NONE);

  for i := 0 to FChildren.Count - 1 do
    TControl(FChildren[i]).Draw;
end;

procedure TControl.DrawTooltip;
begin
  if FHint <> '' then GuiSetTooltip(PAnsiChar(FHint));
end;

{ TGuiManager }

constructor TGuiManager.Create;
begin
  inherited Create(nil);
  Width := GetScreenWidth;
  Height := GetScreenHeight;
  FTextAlignmentVertical := TEXT_ALIGN_MIDDLE;
end;

procedure TGuiManager.Paint;
begin
  Width := GetScreenWidth;
  Height := GetScreenHeight;
end;

procedure TGuiManager.Run;
begin
  Draw;
end;

end.
