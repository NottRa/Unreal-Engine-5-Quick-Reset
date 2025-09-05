@echo on
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem  Unreal Quick Reset – no logs, no cfg
rem ============================================================

rem ---- MODES ----
set "FULL_CLEAN=1"    rem 0=fast (patch DLLs only), 1=also remove Intermediate/Binaries
set "DIAG_MODE=0"     rem 0=UE detached; 1=inline UE logs
set "OPEN_SOLUTION=1" rem 1=open the .sln after project-file generation

rem ---- Script dir (for convenience) ----
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

rem ---- Find or ask for .uproject ----
set "UPROJECT="
for %%F in ("%SCRIPT_DIR%\*.uproject") do set "UPROJECT=%%~fF"
if not defined UPROJECT (
  echo No .uproject found. Please select your **.uproject** file.
  for /f "usebackq delims=" %%P in (`
    powershell -NoProfile -STA -Command ^
      "Add-Type -AssemblyName System.Windows.Forms; $ofd=New-Object System.Windows.Forms.OpenFileDialog; " ^
      "$ofd.Filter='Unreal Project (*.uproject)|*.uproject'; $ofd.Multiselect=$false; " ^
      "if($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){Write-Output $ofd.FileName}"
  `) do set "UPROJECT=%%P"
  if not defined UPROJECT echo [ERROR] No .uproject selected. & goto :END
)

for %%F in ("%UPROJECT%") do (
  set "PROJECT_NAME=%%~nF"
  set "PROJECT_ROOT=%%~dpF"
)
set "PROJECT_ROOT=%PROJECT_ROOT:~0,-1%"
set "SLN_PATH=%PROJECT_ROOT%\%PROJECT_NAME%.sln"

rem ---- Resolve ENGINE_ROOT ----
if not defined ENGINE_ROOT (
  for /f "usebackq delims=" %%A in (`
    powershell -NoProfile -Command "(Get-Content '%UPROJECT%' | ConvertFrom-Json).EngineAssociation" 2^>nul
  `) do set "ENGINE_ASSOC=%%A"

  if defined ENGINE_ASSOC (
    echo %ENGINE_ASSOC% | findstr /r "^{[0-9A-Fa-f\-][0-9A-Fa-f\-]*}$" >nul
    if not errorlevel 1 (
      for /f "usebackq delims=" %%P in (`
        powershell -NoProfile -Command ^
          "$k='HKCU:\Software\Epic Games\Unreal Engine\Builds';" ^
          "try{(Get-Item $k).GetValue('%ENGINE_ASSOC%')}catch{''}"
      `) do set "ENGINE_PATH_FROM_REG=%%P"
      if defined ENGINE_PATH_FROM_REG set "ENGINE_ROOT=%ENGINE_PATH_FROM_REG%\Engine"
    )
    if not defined ENGINE_ROOT (
      for %%C in (
        "G:\UE_%ENGINE_ASSOC%\Engine"
        "C:\Program Files\Epic Games\UE_%ENGINE_ASSOC%\Engine"
        "D:\Program Files\Epic Games\UE_%ENGINE_ASSOC%\Engine"
      ) do if exist "%%~fC\Binaries\Win64\UnrealEditor.exe" set "ENGINE_ROOT=%%~fC"
    )
  )
  if not defined ENGINE_ROOT (
    for %%D in (G: F: E: D: C:) do (
      for /f "delims=" %%P in ('dir /b /ad "%%D\UE_5.*" 2^>nul') do (
        if exist "%%D\%%P\Engine\Binaries\Win64\UnrealEditor.exe" set "ENGINE_ROOT=%%D\%%P\Engine"
      )
    )
  )
)
if not defined ENGINE_ROOT (
  echo Could not auto-resolve Unreal Engine. Please select your **Engine** folder.
  for /f "usebackq delims=" %%E in (`
    powershell -NoProfile -STA -Command ^
      "Add-Type -AssemblyName System.Windows.Forms; " ^
      "$fb=New-Object System.Windows.Forms.FolderBrowserDialog; " ^
      "$fb.Description='Select Unreal Engine **Engine** folder (contains Binaries\\Win64)'; " ^
      "if($fb.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){Write-Output $fb.SelectedPath}"
  `) do set "ENGINE_ROOT=%%E"
  if not defined ENGINE_ROOT echo [ERROR] No Engine folder chosen. & goto :END
  if not exist "%ENGINE_ROOT%\Binaries\Win64\UnrealEditor.exe" (
    echo [ERROR] "%ENGINE_ROOT%" is not a valid Engine folder.
    goto :END
  )
)

set "EDITOR_EXE=%ENGINE_ROOT%\Binaries\Win64\UnrealEditor.exe"
set "BUILD_BAT=%ENGINE_ROOT%\Build\BatchFiles\Build.bat"
if not exist "%EDITOR_EXE%"  echo [ERROR] UnrealEditor.exe not found & goto :END
if not exist "%BUILD_BAT%"   echo [ERROR] Build.bat not found       & goto :END

set "BIN_WIN64=%PROJECT_ROOT%\Binaries\Win64"
set "INTERMEDIATE=%PROJECT_ROOT%\Intermediate"
set "EDITOR_DLL=%BIN_WIN64%\UnrealEditor-%PROJECT_NAME%.dll"

echo ENGINE_ROOT: "%ENGINE_ROOT%"
echo PROJECT    : "%PROJECT_NAME%"

rem ---- Kill lockers ----
echo.
echo == Killing UE/UBT/VS/dotnet processes ==
for %%P in (UnrealEditor UnrealBuildTool MSBuild devenv dotnet EpicGamesLauncher) do taskkill /F /IM "%%P.exe" >nul 2>&1

rem ---- Fast clean ----
echo.
echo == Fast clean: removing Live Coding patch DLLs ==
if exist "%BIN_WIN64%" del /Q "%BIN_WIN64%\UnrealEditor-*.patch_*.dll" >nul 2>&1

rem ---- Full clean if requested ----
if "%FULL_CLEAN%"=="1" (
  echo.
  echo == FULL clean: removing Intermediate and Binaries ==
  if exist "%INTERMEDIATE%" rmdir /S /Q "%INTERMEDIATE%"
  if exist "%PROJECT_ROOT%\Binaries" rmdir /S /Q "%PROJECT_ROOT%\Binaries"
)

rem ---- Regenerate project files ----
echo.
echo == Generating Visual Studio project files ==
call "%BUILD_BAT%" -projectfiles -project="%UPROJECT%" -game -rocket -progress
if errorlevel 1 echo [ERROR] -projectfiles failed & goto :END

rem ---- Open .sln ----
if "%OPEN_SOLUTION%"=="1" (
  if exist "%SLN_PATH%" (
    echo.
    echo == Opening solution (.sln association) ==
    start "" "%SLN_PATH%"
    timeout /t 2 >nul
    tasklist /FI "IMAGENAME eq devenv.exe" | find /I "devenv.exe" >nul
    if errorlevel 1 (
      if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
        for /f "usebackq delims=" %%V in (`
          "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -property productPath
        `) do set "DEVENV=%%V"
        if defined DEVENV start "" "%DEVENV%" "%SLN_PATH%"
      )
    )
  ) else (
    echo [WARN] Solution not found at "%SLN_PATH%".
  )
)

rem ---- Build only if needed ----
set "NEED_BUILD=0"
if not exist "%EDITOR_DLL%" set "NEED_BUILD=1"
if "%FULL_CLEAN%"=="1" set "NEED_BUILD=1"

if "%NEED_BUILD%"=="1" (
  echo.
  echo == Building %PROJECT_NAME%Editor (Win64 Development) ==
  call "%BUILD_BAT%" -Target="%PROJECT_NAME%Editor Win64 Development -Project=""%UPROJECT%""" -WaitMutex -LiveCodingLimit=0
  if errorlevel 1 (
    echo [ERROR] Build failed. Scroll up for errors.
    goto :TAILLOG
  )
) else (
  echo.
  echo == Editor DLL present; skipping build for speed ==
)

rem ---- Launch UE ----
echo.
echo == Launching Unreal Editor ==
if "%DIAG_MODE%"=="1" (
  "%EDITOR_EXE%" "%UPROJECT%" -log -NoSplash -stdout
  echo UE exited with code %ERRORLEVEL%.
) else (
  start "" "%EDITOR_EXE%" "%UPROJECT%"
  echo (UE launched detached; closing this window won't close UE)
)

goto :END

:TAILLOG
echo.
echo Tail of Saved\Logs (if exists):
for %%L in ("%PROJECT_ROOT%\Saved\Logs\%PROJECT_NAME%.log") do (
  echo --- %%~nxL ---
  powershell -NoProfile -Command "Get-Content '%%~fL' -Tail 80"
)

:END
echo.
echo Press any key to close...
pause >nul
endlocal