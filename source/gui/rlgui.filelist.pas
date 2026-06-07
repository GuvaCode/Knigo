unit rlgui.filelist;

{$mode ObjFPC}{$H+}
{$WARN 5044 off : Symbol "$1" is not portable}

interface

uses
  raylib, raygui, Classes, SysUtils, rlgui.layout;

type
  TFileSelectedEvent = procedure(Sender: TObject; const FilePath: string) of object;
  TDirectoryChangedEvent = procedure(Sender: TObject; const Directory: string) of object;

  { TFileList }

  TFileList = class(TControl)
  private
    FCurrentDir: string;
    FFilter: string;
    FShowHidden: Boolean;
    FShowDirectories: Boolean;
    FShowFiles: Boolean;
    FSelectedFile: string;
    FSelectedPath: string;
    FScrollIndex: Integer;
    FActiveIndex: Integer;
    FPrevActiveIndex: Integer;
    FItemFocused: Integer;

    FDirectories: TStringList;
    FFiles: TStringList;
    FDirFiles: TFilePathList;
    FDirFilesIcon: array of PChar;

    FOnFileSelected: TFileSelectedEvent;
    FOnDirectoryChanged: TDirectoryChangedEvent;
    FOnFileDoubleClick: TFileSelectedEvent;

    procedure ReloadContents;
    procedure FreeIcons;
    procedure LoadDirectoryContents;
    procedure UpdateFileList;
    function GetPrevDirectoryPath(const DirPath: string): string;
    procedure HandleKeyboardNavigation;
    function GetVisibleItemsCount: Integer;
    procedure SelectCurrentItem;
    {$IFDEF WINDOWS}
    procedure LoadDrivesList;
    {$ENDIF}

  protected

  public
    constructor Create(AParent: TControl = nil);
    destructor Destroy; override;
    procedure Paint; override;
    procedure Update;
    procedure Refresh;
    procedure GoToParent;
    procedure GoToDirectory(const Directory: string);
    procedure SelectFile(const FileName: string);

    property CurrentDirectory: string read FCurrentDir write GoToDirectory;
    property SelectedFile: string read FSelectedFile;
    property SelectedPath: string read FSelectedPath;

  published
    property Filter: string read FFilter write FFilter;
    property ShowHidden: Boolean read FShowHidden write FShowHidden;
    property ShowDirectories: Boolean read FShowDirectories write FShowDirectories;
    property ShowFiles: Boolean read FShowFiles write FShowFiles;
    property ActiveIndex: Integer read FActiveIndex;
    property OnFileSelected: TFileSelectedEvent read FOnFileSelected write FOnFileSelected;
    property OnDirectoryChanged: TDirectoryChangedEvent read FOnDirectoryChanged write FOnDirectoryChanged;
    property OnFileDoubleClick: TFileSelectedEvent read FOnFileDoubleClick write FOnFileDoubleClick;
  end;

implementation

const
  PATH_SEPARATOR = {$IFDEF WINDOWS} '\' {$ELSE} '/' {$ENDIF};
  MAX_ICON_PATH_LENGTH = 512;

function IsRootDirectory(const Path: string): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := (Path <> '') and (ExtractFilePath(Path) = Path);
  {$ELSE}
  Result := (Path = '/');
  {$ENDIF}
end;

{ TFileList }

constructor TFileList.Create(AParent: TControl);
begin
  inherited Create(AParent);

  Width := 100;
  Height := 100;

  FCurrentDir := GetUserDir;
  FFilter := '';
  FShowHidden := False;
  FShowDirectories := True;
  FShowFiles := True;
  FSelectedFile := '';
  FSelectedPath := '';
  FScrollIndex := 0;
  FActiveIndex := -1;
  FPrevActiveIndex := -1;
  FItemFocused := 0;

  FDirectories := TStringList.Create;
  FFiles := TStringList.Create;

  FDirFiles.count := 0;
  FDirFiles.paths := nil;
  SetLength(FDirFilesIcon, 0);

  ReloadContents;
end;

destructor TFileList.Destroy;
var i: Integer;
begin
  FreeIcons;
  FDirectories.Free;
  FFiles.Free;

  if FDirFiles.paths <> nil then
  begin
    for i := 0 to FDirFiles.count - 1 do
      if FDirFiles.paths[i] <> nil then
        StrDispose(FDirFiles.paths[i]);
    FreeMem(FDirFiles.paths);
  end;

  inherited Destroy;
end;

procedure TFileList.FreeIcons;
var i: Integer;
begin
  for i := 0 to High(FDirFilesIcon) do
    if Assigned(FDirFilesIcon[i]) then
      FreeMem(FDirFilesIcon[i]);
  SetLength(FDirFilesIcon, 0);
end;

function TFileList.GetPrevDirectoryPath(const DirPath: string): string;
begin
  {$IFDEF WINDOWS}
  if DirPath = '' then
    Result := ''
  else if IsRootDirectory(DirPath) then
    Result := ''
  else
    Result := ExcludeTrailingPathDelimiter(ExtractFilePath(DirPath));
  {$ELSE}
  if DirPath = '/' then
    Result := '/'
  else
  begin
    Result := ExcludeTrailingPathDelimiter(ExtractFilePath(DirPath));
    if Result = '' then
      Result := '/';
  end;
  {$ENDIF}
end;

procedure TFileList.LoadDirectoryContents;
var
  searchRec: TSearchRec;
  searchResult: Integer;
  searchPath: string;
  itemName: string;
  fileExt: string;
  filterExts: TStringList;
  i: Integer;
  matchFilter: Boolean;
begin
  FDirectories.Clear;
  FFiles.Clear;

  {$IFDEF WINDOWS}
  if FCurrentDir = '' then
  begin
    LoadDrivesList;
    Exit;
  end;
  {$ENDIF}

  if FCurrentDir <> '' then
  begin
    FCurrentDir := ExpandFileName(FCurrentDir);
    FCurrentDir := ExcludeTrailingPathDelimiter(FCurrentDir);
  end;

  {$IFDEF WINDOWS}
  if FCurrentDir <> '' then
    FDirectories.Add('..');
  {$ELSE}
  if (FCurrentDir <> '') and (FCurrentDir <> '/') then
    FDirectories.Add('..');
  {$ENDIF}

  filterExts := TStringList.Create;
  try
    if FFilter <> '' then
    begin
      filterExts.Delimiter := ';';
      filterExts.DelimitedText := FFilter;
      for i := 0 to filterExts.Count - 1 do
      begin
        filterExts[i] := Trim(filterExts[i]);
        if (filterExts[i] <> '') and (filterExts[i][1] = '.') then
          filterExts[i] := Copy(filterExts[i], 2, Length(filterExts[i]) - 1);
        filterExts[i] := LowerCase(filterExts[i]);
      end;
    end;

    if FCurrentDir <> '' then
    begin
      {$IFDEF WINDOWS}
      searchPath := IncludeTrailingPathDelimiter(FCurrentDir) + '*';
      {$ELSE}
      if FCurrentDir = '/' then
        searchPath := '/*'
      else
        searchPath := IncludeTrailingPathDelimiter(FCurrentDir) + '*';
      {$ENDIF}

      searchResult := FindFirst(searchPath, faDirectory or faAnyFile, searchRec);

      try
        while searchResult = 0 do
        begin
          itemName := searchRec.Name;

          if (itemName = '.') or (itemName = '..') then
          begin
            searchResult := FindNext(searchRec);
            Continue;
          end;

          if ((searchRec.Attr and faDirectory) <> 0) then
          begin
            if FShowDirectories and ((searchRec.Attr and faHidden) = 0) then
              FDirectories.Add(itemName);
          end
          else if FShowFiles then
          begin
            matchFilter := True;
            if FFilter <> '' then
            begin
              matchFilter := False;
              fileExt := LowerCase(ExtractFileExt(itemName));
              if (fileExt <> '') and (fileExt[1] = '.') then
                fileExt := Copy(fileExt, 2, Length(fileExt) - 1);

              for i := 0 to filterExts.Count - 1 do
              begin
                if filterExts[i] = '' then Continue;
                if fileExt = filterExts[i] then
                begin
                  matchFilter := True;
                  Break;
                end;
              end;
            end;

            if matchFilter and ((searchRec.Attr and faHidden) = 0) then
              FFiles.Add(itemName);
          end;

          searchResult := FindNext(searchRec);
        end;
      finally
        FindClose(searchRec);
      end;
    end;
  finally
    filterExts.Free;
  end;

  FDirectories.Sort;
  FFiles.Sort;

  // Перемещаем ".." в начало, если он есть
  if FDirectories.Count > 0 then
  begin
    i := FDirectories.IndexOf('..');
    if i > 0 then
    begin
      FDirectories.Delete(i);
      FDirectories.Insert(0, '..');
    end;
  end;
end;

{$IFDEF WINDOWS}
procedure TFileList.LoadDrivesList;
var i: Integer;
  driveLetter: string;
begin
  FDirectories.Clear;
  FFiles.Clear;

  for i := 0 to 25 do
  begin
    driveLetter := Chr(Ord('A') + i) + ':';
    if DirectoryExists(PAnsiChar(driveLetter + '\')) then
      FDirectories.Add(driveLetter);
  end;

  FDirectories.Sort;
end;
{$ENDIF}

procedure TFileList.ReloadContents;
var
  i: Integer;
  totalItems: Integer;
  iconText: string;
  dirName: string;
  fileNameItem: string;
  fullPath: string;
begin
  if FDirFiles.paths <> nil then
  begin
    for i := 0 to FDirFiles.count - 1 do
      if FDirFiles.paths[i] <> nil then
        StrDispose(FDirFiles.paths[i]);
    FreeMem(FDirFiles.paths);
    FDirFiles.paths := nil;
  end;
  FreeIcons;

  LoadDirectoryContents;
  totalItems := FDirectories.Count + FFiles.Count;
  if totalItems = 0 then
  begin
    FDirFiles.count := 0;
    Exit;
  end;

  FDirFiles.count := totalItems;
  GetMem(FDirFiles.paths, SizeOf(PChar) * totalItems);
  SetLength(FDirFilesIcon, totalItems);

  for i := 0 to totalItems - 1 do
  begin
    GetMem(FDirFilesIcon[i], MAX_ICON_PATH_LENGTH);
    FillChar(FDirFilesIcon[i]^, MAX_ICON_PATH_LENGTH, 0);
  end;

  for i := 0 to FDirectories.Count - 1 do
  begin
    dirName := FDirectories[i];
    {$IFDEF WINDOWS}
    if FCurrentDir = '' then
      fullPath := dirName
    else if dirName = '..' then
    begin
      if IsRootDirectory(FCurrentDir) then
        fullPath := '..'
      else
        fullPath := GetPrevDirectoryPath(FCurrentDir);
    end
    else
      fullPath := IncludeTrailingPathDelimiter(FCurrentDir) + dirName;
    {$ELSE}
    if dirName = '..' then
      fullPath := GetPrevDirectoryPath(FCurrentDir)
    else
      fullPath := IncludeTrailingPathDelimiter(FCurrentDir) + dirName;
    {$ENDIF}

    FDirFiles.paths[i] := StrNew(PChar(fullPath));
    if dirName = '..' then
      iconText := '#1# ' + dirName
    else
      iconText := '#1# ' + dirName;
    StrLCopy(FDirFilesIcon[i], PChar(iconText), MAX_ICON_PATH_LENGTH - 1);
  end;

  for i := 0 to FFiles.Count - 1 do
  begin
    fileNameItem := FFiles[i];
    {$IFDEF WINDOWS}
    if FCurrentDir = '' then
      fullPath := fileNameItem
    else
      fullPath := IncludeTrailingPathDelimiter(FCurrentDir) + fileNameItem;
    {$ELSE}
    fullPath := IncludeTrailingPathDelimiter(FCurrentDir) + fileNameItem;
    {$ENDIF}
    FDirFiles.paths[FDirectories.Count + i] := StrNew(PChar(fullPath));
    iconText := '#218# ' + fileNameItem;
    StrLCopy(FDirFilesIcon[FDirectories.Count + i], PChar(iconText), MAX_ICON_PATH_LENGTH - 1);
  end;

  // Сохраняем активный элемент, если он еще существует
  if FActiveIndex >= FDirFiles.count then
    FActiveIndex := FDirFiles.count - 1;

  // Корректировка скролла
  if FActiveIndex >= 0 then
  begin
    if FActiveIndex < FScrollIndex then
      FScrollIndex := FActiveIndex
    else if FActiveIndex >= FScrollIndex + GetVisibleItemsCount then
      FScrollIndex := FActiveIndex - GetVisibleItemsCount + 1;
  end
  else
  begin
    FScrollIndex := 0;
  end;

  // Защита от выхода за границы
  if FScrollIndex < 0 then
    FScrollIndex := 0;
  if (FScrollIndex > FDirFiles.count - GetVisibleItemsCount) and (FDirFiles.count > GetVisibleItemsCount) then
    FScrollIndex := FDirFiles.count - GetVisibleItemsCount;
  if FScrollIndex < 0 then
    FScrollIndex := 0;

  FPrevActiveIndex := FActiveIndex;
end;

procedure TFileList.UpdateFileList;
begin
  ReloadContents;
end;

procedure TFileList.Refresh;
begin
  ReloadContents;
  if Assigned(FOnDirectoryChanged) then
    FOnDirectoryChanged(Self, FCurrentDir);
end;

procedure TFileList.GoToParent;
var savedFile: string;
begin
  savedFile := FSelectedFile;

  {$IFDEF WINDOWS}
  if FCurrentDir = '' then
    FCurrentDir := ''
  else if IsRootDirectory(FCurrentDir) then
    FCurrentDir := ''
  else
    FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
  {$ELSE}
  if FCurrentDir <> '/' then
    FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
  {$ENDIF}

  ReloadContents;
  FActiveIndex := -1;

  if savedFile <> '' then
    SelectFile(savedFile);

  if Assigned(FOnDirectoryChanged) then
    FOnDirectoryChanged(Self, FCurrentDir);
end;

procedure TFileList.GoToDirectory(const Directory: string);
begin
  if DirectoryExists(PChar(Directory)) then
  begin
    FCurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(Directory));
    ReloadContents;
    FActiveIndex := -1;

    if Assigned(FOnDirectoryChanged) then
      FOnDirectoryChanged(Self, FCurrentDir);
  end;
end;

procedure TFileList.SelectFile(const FileName: string);
var i: Integer;
begin
  for i := 0 to FDirFiles.count - 1 do
  begin
    if ExtractFileName(string(FDirFiles.paths[i])) = FileName then
    begin
      FActiveIndex := i;
      FSelectedFile := FileName;
      FSelectedPath := string(FDirFiles.paths[i]);
      // Корректировка скролла
      if FActiveIndex < FScrollIndex then
        FScrollIndex := FActiveIndex
      else if FActiveIndex >= FScrollIndex + GetVisibleItemsCount then
        FScrollIndex := FActiveIndex - GetVisibleItemsCount + 1;
      Break;
    end;
  end;
end;

function TFileList.GetVisibleItemsCount: Integer;
var
  itemHeight: Integer;
begin
  itemHeight := GuiGetStyle(LISTVIEW, LIST_ITEMS_HEIGHT);
  if itemHeight <= 0 then
    itemHeight := 24;
  Result := Trunc(Height) div itemHeight;
  if Result < 1 then
    Result := 1;
  if FDirFiles.count > 0 then
  begin
    if Result > FDirFiles.count then
      Result := FDirFiles.count;
  end;
end;

procedure TFileList.SelectCurrentItem;
var
  selectedPath_: string;
  savedFileName: string;
begin
  if (FActiveIndex >= 0) and (FActiveIndex < FDirFiles.count) then
  begin
    selectedPath_ := string(FDirFiles.paths[FActiveIndex]);
    FSelectedPath := selectedPath_;
    FSelectedFile := ExtractFileName(selectedPath_);

    if DirectoryExists(PChar(selectedPath_)) or (ExtractFileName(selectedPath_) = '..') then
    begin
      savedFileName := FSelectedFile;

      if ExtractFileName(selectedPath_) = '..' then
      begin
        {$IFDEF WINDOWS}
        if IsRootDirectory(FCurrentDir) then
          FCurrentDir := ''
        else
          FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
        {$ELSE}
        if FCurrentDir <> '/' then
          FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
        {$ENDIF}
      end
      else
      begin
        {$IFDEF WINDOWS}
        if FCurrentDir = '' then
          FCurrentDir := selectedPath_
        else
          FCurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(selectedPath_));
        {$ELSE}
        FCurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(selectedPath_));
        {$ENDIF}
      end;

      FActiveIndex := -1;
      FScrollIndex := 0;
      ReloadContents;

      if Assigned(FOnDirectoryChanged) then
        FOnDirectoryChanged(Self, FCurrentDir);

      if savedFileName <> '' then
        SelectFile(savedFileName);
    end
    else if Assigned(FOnFileDoubleClick) then
    begin
      FOnFileDoubleClick(Self, selectedPath_);
    end;
  end;
end;

procedure TFileList.HandleKeyboardNavigation;
var
  totalItems: Integer;
  visibleCount: Integer;
  oldIndex: Integer;
begin
  if FDirFiles.count = 0 then Exit;

  totalItems := FDirFiles.count;
  visibleCount := GetVisibleItemsCount;
  oldIndex := FActiveIndex;

  // Вверх
  if IsKeyPressed(KEY_UP) or IsKeyPressedRepeat(KEY_UP) then
  begin
    if FActiveIndex > 0 then
      FActiveIndex := FActiveIndex - 1
    else if FActiveIndex = -1 then
      FActiveIndex := 0;
  end
  // Вниз
  else if IsKeyPressed(KEY_DOWN) or IsKeyPressedRepeat(KEY_DOWN) then
  begin
    if FActiveIndex = -1 then
      FActiveIndex := 0
    else if FActiveIndex < totalItems -1 then
      FActiveIndex := FActiveIndex + 1;
  end
  // Page Up
  else if IsKeyPressed(KEY_PAGE_UP) or IsKeyPressedRepeat(KEY_PAGE_UP) then
  begin
    if FActiveIndex > visibleCount then
      FActiveIndex := FActiveIndex - visibleCount
    else
      FActiveIndex := 0;
  end
  // Page Down
  else if IsKeyPressed(KEY_PAGE_DOWN) or IsKeyPressedRepeat(KEY_PAGE_DOWN) then
  begin
    if FActiveIndex < totalItems - visibleCount then
      FActiveIndex := FActiveIndex + visibleCount
    else
      FActiveIndex := totalItems - 1;
  end
  // Home
  else if IsKeyPressed(KEY_HOME) then
  begin
    FActiveIndex := 0;
  end
  // End
  else if IsKeyPressed(KEY_END) then
  begin
    FActiveIndex := totalItems - 1;
  end
  // Enter
  else if IsKeyPressed(KEY_ENTER) then
  begin
    SelectCurrentItem;
  end
  // Backspace
  else if IsKeyPressed(KEY_BACKSPACE) then
  begin
    GoToParent;
  end;

  // Если индекс изменился - корректируем скролл и вызываем событие
 { if oldIndex <> FActiveIndex then
  begin
    if FActiveIndex >= 0 then
    begin
      // Корректировка скролла
      if FActiveIndex < FScrollIndex then
        FScrollIndex := FActiveIndex

      else if FActiveIndex >= FScrollIndex + visibleCount then
        FScrollIndex := FActiveIndex - visibleCount + 1;

      // Защита границ скролла
      if FScrollIndex < 0 then FScrollIndex := 0;
      if FScrollIndex > totalItems - visibleCount then
        FScrollIndex := totalItems - visibleCount;
      if FScrollIndex < 0 then FScrollIndex := 0;

      // Вызываем событие выбора
      if Assigned(FOnFileSelected) and (FActiveIndex < FDirFiles.count) then
        FOnFileSelected(Self, string(FDirFiles.paths[FActiveIndex]));
    end;
  end;}
//   FScrollIndex := FActiveIndex;
end;

procedure TFileList.Update;
begin
  // Устанавливаем фокус при клике мышью на список
  if IsMouseButtonPressed(MOUSE_LEFT_BUTTON) then
  begin
    if CheckCollisionPointRec(GetMousePosition, RectangleCreate(Left, Top, Width, Height)) then
      FItemFocused := 0;
  end;

  HandleKeyboardNavigation;
end;

procedure TFileList.Paint;
var
  R: TRectangle;
  dirFilesIconArray: PPChar;
  i: Integer;
  savedFileName: string;
  selectedPath_: string;
  prevAlignment, prevHeight: Integer;
  listViewResult: Integer;
  oldScrollIndex: Integer;
  visibleCount: Integer;
begin
  if not Visible then Exit;
  Update;
  R := RectangleCreate(Left, Top, Width, Height);

  if FDirFiles.paths = nil then
    ReloadContents;

  GuiSetStyle(DEFAULT, TEXT_ALIGNMENT, TEXT_ALIGN_CENTER);

  prevAlignment := GuiGetStyle(LISTVIEW, TEXT_ALIGNMENT);
  prevHeight := GuiGetStyle(LISTVIEW, LIST_ITEMS_HEIGHT);
  GuiSetStyle(LISTVIEW, TEXT_ALIGNMENT, TEXT_ALIGN_LEFT);
  GuiSetStyle(LISTVIEW, LIST_ITEMS_HEIGHT, 24);

  if (Length(FDirFilesIcon) > 0) and (FDirFiles.count > 0) then
  begin
    GetMem(dirFilesIconArray, SizeOf(PChar) * FDirFiles.count);
    try
      for i := 0 to FDirFiles.count - 1 do
        dirFilesIconArray[i] := FDirFilesIcon[i];

      // Сохраняем текущий скролл перед вызовом
      oldScrollIndex := FScrollIndex;
      visibleCount := GetVisibleItemsCount;

      listViewResult := GuiListViewEx(R, dirFilesIconArray, FDirFiles.count,
          @FScrollIndex, @FActiveIndex, @FItemFocused);

      // ЗАЩИТА 1: если скролл необоснованно сбросился и активный элемент внизу списка
      if (FScrollIndex = 0) and (oldScrollIndex > 0) and
         (FActiveIndex >= visibleCount) then
      begin
        FScrollIndex := oldScrollIndex;
      end;

      // ЗАЩИТА 2: если активный элемент последний и скролл сбросился
      if (FActiveIndex = FDirFiles.count - 1) and (FActiveIndex >= 0) and
         (FScrollIndex = 0) and (FDirFiles.count > visibleCount) then
      begin
        FScrollIndex := FActiveIndex - visibleCount + 1;
        if FScrollIndex < 0 then FScrollIndex := 0;
      end;

      // ЗАЩИТА 3: проверка валидности скролла
      if FScrollIndex < 0 then
        FScrollIndex := 0;
      if (FScrollIndex > FDirFiles.count - visibleCount) and (FDirFiles.count > visibleCount) then
        FScrollIndex := FDirFiles.count - visibleCount;
      if FScrollIndex < 0 then
        FScrollIndex := 0;

      // Обработка двойного клика мыши
      if (listViewResult >= 0) and IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      begin
        if FActiveIndex <> FPrevActiveIndex then
        begin
          if FActiveIndex < FDirFiles.count then
          begin
            selectedPath_ := string(FDirFiles.paths[FActiveIndex]);

            if DirectoryExists(PChar(selectedPath_)) or (ExtractFileName(selectedPath_) = '..') then
            begin
              savedFileName := ExtractFileName(selectedPath_);

              if ExtractFileName(selectedPath_) = '..' then
              begin
                {$IFDEF WINDOWS}
                if IsRootDirectory(FCurrentDir) then
                  FCurrentDir := ''
                else
                  FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
                {$ELSE}
                if FCurrentDir <> '/' then
                  FCurrentDir := GetPrevDirectoryPath(FCurrentDir);
                {$ENDIF}
              end
              else
              begin
                {$IFDEF WINDOWS}
                if FCurrentDir = '' then
                  FCurrentDir := selectedPath_
                else
                  FCurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(selectedPath_));
                {$ELSE}
                FCurrentDir := ExcludeTrailingPathDelimiter(ExpandFileName(selectedPath_));
                {$ENDIF}
              end;

              ReloadContents;
              FActiveIndex := -1;

              if Assigned(FOnDirectoryChanged) then
                FOnDirectoryChanged(Self, FCurrentDir);

              if savedFileName <> '' then
                SelectFile(savedFileName);
            end
            else if Assigned(FOnFileDoubleClick) then
            begin
              FOnFileDoubleClick(Self, selectedPath_);
            end;
          end;
          FPrevActiveIndex := FActiveIndex;
        end;
      end;

      // Вызываем событие при одиночном клике/навигации
      if (FActiveIndex >= 0) and (FActiveIndex < FDirFiles.count) and
         (FActiveIndex <> FPrevActiveIndex) then
      begin
        if Assigned(FOnFileSelected) then
          FOnFileSelected(Self, string(FDirFiles.paths[FActiveIndex]));
        FPrevActiveIndex := FActiveIndex;
      end;

    finally
      FreeMem(dirFilesIconArray);
    end;
  end;

  GuiSetStyle(LISTVIEW, TEXT_ALIGNMENT, prevAlignment);
  GuiSetStyle(LISTVIEW, LIST_ITEMS_HEIGHT, prevHeight);
end;

end.
