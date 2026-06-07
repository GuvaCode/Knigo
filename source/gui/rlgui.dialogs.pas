unit rlgui.dialogs;

{$mode ObjFPC}{$H+}
{$WARN 5044 off : Symbol "$1" is not portable}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout, rlgui.filelist;

type
  TDialogResult = (drNone, drOK, drCancel);

  TFileDialogEvent = procedure(Sender: TObject; const FileName: string) of object;

  { TCustomFileDialog }

  TCustomFileDialog = class(TControl)
  private
    FResult: TDialogResult;
    FSelectedFileName: string;  // Переименовано, чтобы избежать конфликта
    FInitialDir: string;
    FFilter: string;
    FDialogTitle: string;  // Переименовано
    FFileList: TFileList;
    FFileNameEdit: array[0..1023] of Char;
    FFileNameEditMode: Boolean;
    FDragMode: Boolean;
    FPanOffset: TVector2;
    FOnFileSelected: TFileDialogEvent;

    procedure UpdateWindowTitle;
    procedure OnFileListSelected(Sender: TObject; const FilePath: string);
    procedure OnFileListDoubleClick(Sender: TObject; const FilePath: string);

  protected
    procedure Paint; override;
    function GetActionButtonText: string; virtual; abstract;
    function ValidateBeforeClose: Boolean; virtual;
    procedure DoFileSelected; virtual;

  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;

    function Execute: TDialogResult;
    procedure Close;
    procedure Cancel;
    procedure UpdateDialog;  // Переименовано

    property FileName: string read FSelectedFileName write FSelectedFileName;
    property InitialDir: string read FInitialDir write FInitialDir;
    property Filter: string read FFilter write FFilter;
    property DialogTitle: string read FDialogTitle write FDialogTitle;  // Переименовано
    property OnFileSelected: TFileDialogEvent read FOnFileSelected write FOnFileSelected;
  end;

  { TOpenDialog }

  TOpenDialog = class(TCustomFileDialog)
  protected
    function GetActionButtonText: string; override;
    function ValidateBeforeClose: Boolean; override;
    procedure DoFileSelected; override;
  end;

  { TSaveDialog }

  TSaveDialog = class(TCustomFileDialog)
  private
    FOverwriteWarningShown: Boolean;
    FShowWarningModal: Boolean;
    FSaveAfterWarning: Boolean;
    procedure DrawOverwriteWarning;
    function CheckFileExists(const FileName_: string): Boolean;

  protected
    function GetActionButtonText: string; override;
    function ValidateBeforeClose: Boolean; override;
    procedure DoFileSelected; override;

  public
    constructor Create(AParent: TControl = nil);
    procedure UpdateDialog;  // Переименовано
    function IsActiveDialog: Boolean;
  end;

implementation

//uses
  //rlgui.utils;

{ TCustomFileDialog }

constructor TCustomFileDialog.Create(AParent: TControl);
begin
  inherited Create(AParent);

  Width := 540;
  Height := 400;

  FResult := drNone;
  FSelectedFileName := '';
  FInitialDir := '';
  FFilter := '';
  FDialogTitle := 'Select File';
  FFileNameEditMode := False;
  FDragMode := False;
  FPanOffset := Vector2Create(0, 0);
  FillChar(FFileNameEdit, SizeOf(FFileNameEdit), 0);

  FFileList := TFileList.Create(Self);
  FFileList.Left := 12;
  FFileList.Top := 48;
  FFileList.Width := Width - 24;
  FFileList.Height := Height - 110;
  FFileList.OnFileSelected := @OnFileListSelected;
  FFileList.OnFileDoubleClick := @OnFileListDoubleClick;

  Visible := False;
end;

destructor TCustomFileDialog.Destroy;
begin
  FFileList.Free;
  inherited Destroy;
end;

procedure TCustomFileDialog.OnFileListSelected(Sender: TObject; const FilePath: string);
begin
  if not DirectoryExists(PChar(FilePath)) then
  begin
    FSelectedFileName := ExtractFileName(FilePath);
    StrLCopy(FFileNameEdit, PChar(FSelectedFileName), SizeOf(FFileNameEdit) - 1);
  end;
end;

procedure TCustomFileDialog.OnFileListDoubleClick(Sender: TObject; const FilePath: string);
begin
  if not DirectoryExists(PChar(FilePath)) then
  begin
    FSelectedFileName := ExtractFileName(FilePath);
    StrLCopy(FFileNameEdit, PChar(FSelectedFileName), SizeOf(FFileNameEdit) - 1);
    if ValidateBeforeClose then
    begin
      DoFileSelected;
      Close;
    end;
  end;
end;

function TCustomFileDialog.Execute: TDialogResult;
begin
  if FInitialDir <> '' then
    FFileList.GoToDirectory(FInitialDir)
  else if FileExists(PChar(FSelectedFileName)) then
    FFileList.GoToDirectory(ExtractFilePath(FSelectedFileName))
  else
    FFileList.GoToDirectory(GetUserDir);

  if FFilter <> '' then
    FFileList.Filter := FFilter;

  if FSelectedFileName <> '' then
  begin
    StrLCopy(FFileNameEdit, PChar(ExtractFileName(FSelectedFileName)), SizeOf(FFileNameEdit) - 1);
    FFileList.SelectFile(ExtractFileName(FSelectedFileName));
  end;

  FResult := drNone;
  Visible := True;

  Result := drNone;
end;

procedure TCustomFileDialog.Close;
begin
  Visible := False;
  if FResult = drNone then
    FResult := drCancel;
end;

procedure TCustomFileDialog.Cancel;
begin
  FResult := drCancel;
  FSelectedFileName := '';
  FillChar(FFileNameEdit, SizeOf(FFileNameEdit), 0);
  Close;
end;

procedure TCustomFileDialog.UpdateWindowTitle;
begin
  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, TEXT_ALIGN_CENTER);
  GuiLabel(RectangleCreate(
    Left + 8,
    Top + 8,
    Width - 16,
    20), PChar(FDialogTitle));
end;

procedure TCustomFileDialog.Paint;
var
  mousePosition: TVector2;
  pathText: string;
  pathBuffer: array[0..1023] of Char;
  btnResult: Integer;
  currentDir: string;
begin
  if not Visible then Exit;

  mousePosition := GetMousePosition;

  // Window dragging
  if IsMouseButtonPressed(MOUSE_LEFT_BUTTON) then
  begin
    if CheckCollisionPointRec(mousePosition,
        RectangleCreate(Left, Top, Width, RAYGUI_WINDOWBOX_STATUSBAR_HEIGHT)) then
    begin
      FDragMode := True;
      FPanOffset.x := mousePosition.x - Left;
      FPanOffset.y := mousePosition.y - Top;
    end;
  end;

  if FDragMode then
  begin
    Left := Trunc(mousePosition.x - FPanOffset.x);
    Top := Trunc(mousePosition.y - FPanOffset.y);

    if Left < 0 then Left := 0;
    if Top < 0 then Top := 0;
    if Left > GetScreenWidth - Width then Left := GetScreenWidth - Width;
    if Top > GetScreenHeight - Height then Top := GetScreenHeight - Height;

    if IsMouseButtonReleased(MOUSE_LEFT_BUTTON) then
      FDragMode := False;
  end;

  // Draw window
  if GuiWindowBox(RectangleCreate(Left, Top, Width, Height), PChar(FDialogTitle)) <> 0 then
    Cancel;

  // Path display
  currentDir := FFileList.CurrentDirectory;
  if currentDir = '' then
    {$IFDEF WINDOWS}
    pathText := 'My Computer'
    {$ELSE}
    pathText := '/'
    {$ENDIF}
  else
    pathText := currentDir;

  StrLCopy(pathBuffer, PChar(pathText), SizeOf(pathBuffer) - 1);
  GuiLabel(RectangleCreate(Left + 12, Top + 32, 60, 24), 'Folder:');
  GuiLabel(RectangleCreate(Left + 72, Top + 32, Width - 84, 24), pathBuffer);

  // File list is updated automatically by its own Paint method

  // File name input
  GuiLabel(RectangleCreate(Left + 12, Top + Height - 60, 70, 24), 'File name:');
  if GuiTextBox(RectangleCreate(Left + 86, Top + Height - 60,
      Width - 210, 24), FFileNameEdit, SizeOf(FFileNameEdit) - 1, FFileNameEditMode) <> 0 then
  begin
    FFileNameEditMode := not FFileNameEditMode;
    if not FFileNameEditMode then
      FSelectedFileName := string(FFileNameEdit);
  end;

  // Action button
  btnResult := GuiButton(RectangleCreate(
    Left + Width - 108,
    Top + Height - 60,
    96, 24), PChar(GetActionButtonText));
  if btnResult <> 0 then
  begin
    if FFileNameEditMode then
      FSelectedFileName := string(FFileNameEdit);
    if ValidateBeforeClose then
    begin
      DoFileSelected;
      Close;
    end;
  end;

  // Cancel button
  if GuiButton(RectangleCreate(
    Left + Width - 108,
    Top + Height - 32,
    96, 24), 'Cancel') <> 0 then
    Cancel;
end;

function TCustomFileDialog.ValidateBeforeClose: Boolean;
begin
  Result := FSelectedFileName <> '';
end;

procedure TCustomFileDialog.DoFileSelected;
begin
  if Assigned(FOnFileSelected) then
    FOnFileSelected(Self, FSelectedFileName);
end;

procedure TCustomFileDialog.UpdateDialog;
begin
  // Обновление диалога
  if Visible then
    Paint;
end;

{ TOpenDialog }

function TOpenDialog.GetActionButtonText: string;
begin
  Result := 'Open';
end;

function TOpenDialog.ValidateBeforeClose: Boolean;
var
  fullPath: string;
begin
  Result := False;

  if FileName = '' then
    Exit;

  fullPath := IncludeTrailingPathDelimiter(FFileList.CurrentDirectory) + FileName;

  if FileExists(PChar(fullPath)) then
  begin
    FileName := fullPath;
    Result := True;
  end;
end;

procedure TOpenDialog.DoFileSelected;
begin
  inherited DoFileSelected;
end;

{ TSaveDialog }

constructor TSaveDialog.Create(AParent: TControl);
begin
  inherited Create(AParent);
  FOverwriteWarningShown := False;
  FShowWarningModal := False;
  FSaveAfterWarning := False;
  DialogTitle := 'Save File';
end;

function TSaveDialog.GetActionButtonText: string;
begin
  Result := 'Save';
end;

function TSaveDialog.ValidateBeforeClose: Boolean;
var
  fullPath: string;
begin
  Result := False;

  if FileName = '' then
    Exit;

  fullPath := IncludeTrailingPathDelimiter(FFileList.CurrentDirectory) + FileName;

  if CheckFileExists(fullPath) then
  begin
    FShowWarningModal := True;
    FSaveAfterWarning := True;
    Result := False;
  end
  else
  begin
    FileName := fullPath;
    Result := True;
  end;
end;

procedure TSaveDialog.DoFileSelected;
begin
  inherited DoFileSelected;
end;

function TSaveDialog.CheckFileExists(const FileName_: string): Boolean;
begin
  Result := FileExists(PChar(FileName_));
end;

procedure TSaveDialog.DrawOverwriteWarning;
var
  warningBounds: TRectangle;
  buttonYes, buttonNo: TRectangle;
  resultYes, resultNo: Integer;
  oldTextAlignment: Integer;
begin
  warningBounds := RectangleCreate(
    Left + Width / 2 - 150,
    Top + Height / 2 - 60,
    300, 120
  );

  oldTextAlignment := GuiGetStyle(DEFAULT, TEXT_ALIGNMENT);

  DrawRectangle(0, 0, GetScreenWidth, GetScreenHeight, ColorCreate(0, 0, 0, 180));

  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, TEXT_ALIGN_CENTER);
  GuiWindowBox(warningBounds, 'Warning');

  GuiLabel(RectangleCreate(
    warningBounds.x + 10,
    warningBounds.y + 30,
    warningBounds.width - 20,
    30), PChar(Format('File "%s" already exists!', [ExtractFileName(FileName)])));

  GuiLabel(RectangleCreate(
    warningBounds.x + 10,
    warningBounds.y + 55,
    warningBounds.width - 20,
    20), 'Overwrite?');

  buttonYes := RectangleCreate(
    warningBounds.x + warningBounds.width - 200,
    warningBounds.y + warningBounds.height - 40,
    90, 30
  );
  resultYes := GuiButton(buttonYes, 'Yes');

  buttonNo := RectangleCreate(
    warningBounds.x + warningBounds.width - 100,
    warningBounds.y + warningBounds.height - 40,
    90, 30
  );
  resultNo := GuiButton(buttonNo, 'No');

  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, oldTextAlignment);

  if resultYes <> 0 then
  begin
    FShowWarningModal := False;
    if FSaveAfterWarning then
    begin
      FileName := IncludeTrailingPathDelimiter(FFileList.CurrentDirectory) + FileName;
      Close;
    end;
  end;

  if resultNo <> 0 then
  begin
    FShowWarningModal := False;
    FSaveAfterWarning := False;
  end;
end;

procedure TSaveDialog.UpdateDialog;
begin
  if not Visible then Exit;

  if FShowWarningModal then
  begin
    DrawOverwriteWarning;
    Exit;
  end;

  if Visible then
    Paint;
end;

function TSaveDialog.IsActiveDialog: Boolean;
begin
  if FShowWarningModal then
    Result := True
  else
    Result := Visible;
end;

end.
