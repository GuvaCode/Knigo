program Knigo;

{$mode objfpc}{$H+}

uses
{$IFDEF LINUX} cthreads,{$ENDIF}
 Classes, SysUtils, CustApp, raylib, raygui,
 rlgui.layout, rlgui.components, // gui
 Fb2Reader, ReaderTools, gui.booknotes, gui.bookextra, gui.bookchapters, gui.booksettings; // readers

type
  { TRayApplication }
  TRayApplication = class(TCustomApplication)
  protected
    FReader: TFB2Reader;
    GuiManager, GuiSubManager: TGuiManager;
    BookPanel: TSimplePanel;
    BtnBack, BtnScrollUp, BtnContents, BtnFooNotes, BtnSettings, BtnHelp: TImageButton;
    BtnTheme, BtnHideBar: TToggleImageButton;
    BgColor: TColorB;
    NotesPanel: TNotesPanel;
    ChaptersPanel: TChaptersPanel;
    SettingsPanel: TSettingsPanel;
    //FSettingsPanelW: Integer;
    //FSettingsPanelH: Integer;
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowHideBookBtn(Sender: TObject; Toggle: Boolean);
    procedure ChangeTheme(Sender: TObject; Toggle: Boolean);
    procedure SlideUp(Sender: TObject);
    procedure ShowNotes(Sender: TObject);

    procedure ShowChapters(Sender: TObject);
    procedure HideAllPanel(Sender: TObject);
    procedure ChapterSelected(Idx: Integer; StartY: Single);
    procedure ShowSettings(Sender: TObject);

  end;

  const AppTitle = 'Knigo - 0.1';
  fntPath = 'data/fonts/';
{ TRayApplication }

constructor TRayApplication.Create(TheOwner: TComponent);
var MyIcon: TImage;
   NewMarginX, NewMarginY: Integer;
begin
  inherited Create(TheOwner);

  InitWindow(800, 600, AppTitle); // for window settings, look at example - window flags
  SetWindowState(FLAG_VSYNC_HINT or FLAG_WINDOW_RESIZABLE or FLAG_WINDOW_HIGHDPI);

  if FileExists('data/my-icon.png') then // load icon
  begin
    MyIcon := LoadImage('data/my-icon.png');
    SetWindowIcon(MyIcon);
    UnloadImage(MyIcon);
  end;

  // create the readers
   FReader := TFB2Reader.Create;//(fntPath + 'DejaVuSans.ttf', fntPath + 'DejaVuSans-Bold.ttf', fntPath + 'DejaVuSans-Oblique.ttf');
   FReader.BaseFontPath     := fntPath + 'DejaVuSans.ttf';
   FReader.TitleFontPath    := fntPath + 'DejaVuSans-Bold.ttf';
   FReader.SubtitleFontPath := fntPath + 'DejaVuSans-Oblique.ttf';
   FReader.TextSize:= 26;
   FReader.ReloadFonts;
   BgColor := RAYWHITE;

   if not FReader.LoadBook('test.fb2') then
   begin
     WriteLn('Failed to load book');
     Halt(1);
   end;

   // gui
  GuiManager := TGuiManager.Create;
  GuiSubManager := TGuiManager.Create;
  GuiSubManager.Visible:=False;

  BookPanel := TSimplePanel.Create(GuiManager);
  BookPanel.Align := alLeft;
  BookPanel.Width:= 52;
  BookPanel.Margins.SetMargins(2, 2, 2, 6);
  BookPanel.ClientMargins.SetMargins(0, 0, 0, 0);
  BookPanel.UsesStyleColor := False;
  BookPanel.AreaColor := BgColor;
  BookPanel.DrawBorder:= False;

  BtnBack := TImageButton.Create(BookPanel);
  BtnBack.Align := alTop;
  BtnBack.Height := 48;
  BtnBack.Margins.SetMargins(2, 4, 2, 2);
  BtnBack.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnBack.LoadTextureFromFile('data/gui/ico_back.png');

  BtnScrollUp := TImageButton.Create(BookPanel);
  BtnScrollUp.Align := alTop;
  BtnScrollUp.Height := 48;
  BtnScrollUp.Margins.SetMargins(2, 4, 2, 2);
  BtnScrollUp.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnScrollUp.LoadTextureFromFile('data/gui/ico_scroll_top.png');
  BtnScrollUp.OnButtonClick := @SlideUp;

  BtnContents := TImageButton.Create(BookPanel);
  BtnContents.Align := alTop;
  BtnContents.Height := 48;
  BtnContents.Margins.SetMargins(2, 2, 2, 2);
  BtnContents.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnContents.LoadTextureFromFile('data/gui/ico_contents.png');
  BtnContents.OnButtonClick := @ShowChapters;

  BtnFooNotes := TImageButton.Create(BookPanel);
  BtnFooNotes.Align := alTop;
  BtnFooNotes.Height := 48;
  BtnFooNotes.Margins.SetMargins(2, 2, 2, 2);
  BtnFooNotes.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnFooNotes.LoadTextureFromFile('data/gui/ico_foonotes.png');
  BtnFooNotes.OnButtonClick := @ShowNotes;

  BtnTheme := TToggleImageButton.Create(BookPanel);
  BtnTheme.Align := alTop;
  BtnTheme.Height := 48;
  BtnTheme.Margins.SetMargins(2, 2, 2, 2);
  BtnTheme.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnTheme.LoadTextureFromFile('data/gui/ico_light.png','data/gui/ico_dark.png' );
  BtnTheme.OnToggleClick:= @ChangeTheme;

  BtnHideBar := TToggleImageButton.Create(BookPanel);
  BtnHideBar.Align := alBottom;
  BtnHideBar.Height := 48;
  BtnHideBar.Margins.SetMargins(2, 2, 2, 4);
  BtnHideBar.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnHideBar.LoadTextureFromFile('data/gui/ico_bar_1.png','data/gui/ico_bar_0.png' );
  BtnHideBar.OnToggleClick := @ShowHideBookBtn;
  BtnHideBar.Toggled:= True;


  BtnHelp := TImageButton.Create(BookPanel);
  BtnHelp.Align := alBottom;
  BtnHelp.Height := 48;
  BtnHelp.Margins.SetMargins(2, 2, 2, 2);
  BtnHelp.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnHelp.LoadTextureFromFile('data/gui/ico_help.png');

  BtnSettings := TImageButton.Create(BookPanel);
  BtnSettings.Align := alBottom;
  BtnSettings.Height := 48;
  BtnSettings.Margins.SetMargins(2, 2, 2, 2);
  BtnSettings.ClientMargins.SetMargins(0, 0, 0, 0);
  BtnSettings.LoadTextureFromFile('data/gui/ico_settings.png');
  BtnSettings.OnButtonClick:= @ShowSettings;

  NotesPanel := TNotesPanel.Create(GuiSubManager);
  NotesPanel.CloseButton.LoadTextureFromFile('data/gui/ico_close_32.png');
  NotesPanel.Width := 350;
  NotesPanel.Height := 350;
  NotesPanel.Margins.SetMargins(100,100,100,100);
  NotesPanel.Align := alClient;
  NotesPanel.Title:='Notes:';
  NotesPanel.LoadFont(fntPath + 'DejaVuSans.ttf', 22);
  NotesPanel.OnButtonClick:= @HideAllPanel;
  NotesPanel.SetNotes(FReader);

  ChaptersPanel := TChaptersPanel.Create(GuiSubManager);
  ChaptersPanel.Width := 350;
  ChaptersPanel.Height := 350;

  ChaptersPanel.Margins.SetMargins(100,100,100,100);
  ChaptersPanel.Align := alClient;

  ChaptersPanel.Title := 'Chapters';
  ChaptersPanel.BackgroundColor := NotesPanel.BackgroundColor;
  ChaptersPanel.TitleColor := NotesPanel.TitleColor;
  ChaptersPanel.OverlayColor := BLACK;
  ChaptersPanel.ShowOverlay := True;
  ChaptersPanel.SetChapters(FReader);
  ChaptersPanel.LoadFont(fntPath + 'DejaVuSans.ttf', 22);
  ChaptersPanel.CloseButton.LoadTextureFromFile('data/gui/ico_close_32.png');
  ChaptersPanel.OnButtonClick:= @HideAllPanel;
  ChaptersPanel.OnChapterSelected := @ChapterSelected;

  // Создание панели
  SettingsPanel := TSettingsPanel.Create(GuiSubManager);
  GuiSubManager.Align:=alClient;



  SettingsPanel.Margins.SetMargins(100, 100, 100, 100); // начальные отступы
  SettingsPanel.SetPosition(100,100);

  //SettingsPanel.Align := alClient;
  SettingsPanel.Title := 'Настройки';
  SettingsPanel.LoadFont('data/fonts/DejaVuSans.ttf', 18);
  SettingsPanel.SetReader(FReader);
  SettingsPanel.OnButtonClick := @HideAllPanel;
  SettingsPanel.CloseButton.LoadTextureFromFile('data/gui/ico_close_32.png');


end;

procedure TRayApplication.DoRun;
var
  TmpLine: Single;
  NewX, NewY: Integer;
begin

 //SettingsPanel.Margins.SetMargins(100, 100, 450, 100); // начальные отступы

  while (not WindowShouldClose) do // Detect window close button or ESC key
  begin
      NewX := (GetScreenWidth  - SettingsPanel.Width) div 2;
  NewY := (GetScreenHeight - SettingsPanel.Height) div 2;
  SettingsPanel.SetPosition(NewX,NewY);
    // Update your variables here
    if not GuiSubManager.Visible then
    FReader.UpdateScroll(GetMouseWheelMove() * 35.0,
                         IsKeyDown(KEY_UP), IsKeyDown(KEY_DOWN),
                         IsKeyDown(KEY_PAGE_UP), IsKeyDown(KEY_PAGE_DOWN));




    if IsKeyPressed(KEY_F11) then
    begin

    // TmpLine := FReader.ScrollY;
     ToggleFullscreen;
    // FReader.ScrollY := TmpLine;

    end;

 if GuiSubManager.Visible then
    begin

      ChaptersPanel.UpdateKeyboardScroll; // оглавление
    end;

    // Подсветка текущей главы
    ChaptersPanel.UpdateScrollY(FReader.ScrollY);


    // Draw
    BeginDrawing();
      ClearBackground(BGCOLOR);
      FReader.Draw(GetRenderWidth, GetRenderHeight);
      GuiManager.Draw;
      GuiSubManager.Draw;
    EndDrawing();
  end;

  // Stop program loop
  Terminate;
end;

destructor TRayApplication.Destroy;
begin
  // De-Initialization
  FReader.Free;
  CloseWindow(); // Close window and OpenGL context

  // Show trace log messages (LOG_DEBUG, LOG_INFO, LOG_WARNING, LOG_ERROR...)
  TraceLog(LOG_INFO, 'your first window is close and destroy');

  inherited Destroy;
end;

procedure TRayApplication.ShowHideBookBtn(Sender: TObject; Toggle: Boolean);
begin
  BtnBack.Visible := Toggle;
  BtnScrollUp.Visible := Toggle;
  BtnContents.Visible := Toggle;
  BtnFooNotes.Visible := Toggle;
  BtnSettings.Visible := Toggle;
  BtnHelp.Visible := Toggle;
  BtnTheme.Visible := Toggle;
end;

procedure TRayApplication.ChangeTheme(Sender: TObject; Toggle: Boolean);
begin
  FReader.InvertColors;
  BgColor := InvertColor(BgColor);
  BookPanel.AreaColor := BgColor;
  NotesPanel.InvertColors;
  ChaptersPanel.InvertColors;
  SettingsPanel.InvertColors;
end;

procedure TRayApplication.SlideUp(Sender: TObject);
begin
  Freader.ScrollY:=0;
end;

procedure TRayApplication.ShowNotes(Sender: TObject);
begin
  HideAllPanel(Sender);
  NotesPanel.Visible := True;
  GuiSubManager.Visible:=True;
end;


procedure TRayApplication.ShowChapters(Sender: TObject);
begin
  HideAllPanel(Self);
  ChaptersPanel.Visible := True;
  GuiSubManager.Visible:=True;
end;

procedure TRayApplication.HideAllPanel(Sender: TObject);
begin
  ChaptersPanel.Visible := False;
  NotesPanel.Visible := False;
  SettingsPanel.Visible:=False;
  GuiSubManager.Visible:=False;
end;

procedure TRayApplication.ChapterSelected(Idx: Integer; StartY: Single);
begin
    if FReader.IsLoaded then
  begin
   // FReader.ScrollY := StartY;
   // if FReader.ScrollY < 0 then FReader.ScrollY := 0;
  //  if FReader.ScrollY > FReader.MaxScroll then FReader.ScrollY := FReader.MaxScroll;
   FReader.GoToChapter(Idx);
  end;
    HideAllPanel(Self);
end;

procedure TRayApplication.ShowSettings(Sender: TObject);
begin
  HideAllPanel(Sender);
  SettingsPanel.Visible := True;
  GuiSubManager.Visible := True;
end;

var
  Application: TRayApplication;

{$R *.res}

begin
  Application:=TRayApplication.Create(nil);
  Application.Title:=AppTitle;
  Application.Run;
  Application.Free;
end.

