@echo off
echo ===================================================
echo        Local Libraries Setup for FNF Project       
echo ===================================================

:: Check for Node.js and npm
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Node.js is not installed or not in PATH!
    echo Please run install_haxe.bat first.
    pause
    exit /b 1
)

echo [1/2] Configuring .haxerc...
(
echo {
echo   "version": "4.2.5",
echo   "resolveLibs": "haxelib"
echo }
) > .haxerc
echo Configured .haxerc to use Haxe 4.2.5 with Haxelib resolution.

echo [2/2] Setting up local libraries...
set OAZA_ZIP=.haxelib.zip
if exist "%OAZA_ZIP%" (
    echo Detected pre-configured libraries archive at Oaza: %OAZA_ZIP%
    echo Extracting cached libraries...
    if exist ".haxelib" (
        echo Warning: .haxelib folder already exists. Backing it up...
        for /f %%a in ('powershell -Command "[int][double](Get-Date -UFormat %%s)"') do set TIMESTAMP=%%a
        rename .haxelib .haxelib.bak_%TIMESTAMP%
    )
    powershell -Command "Expand-Archive -Path '%OAZA_ZIP%' -DestinationPath '%CD%'"
    echo Extracted pre-configured libraries from Oaza!
    
    :: Patch GenericStringRef in local .haxelib if exists
    for /f "delims=" %%f in ('dir /b /s .haxelib\document.h 2^>nul') do (
        set LOCAL_DOC_H=%%f
    )
    if defined LOCAL_DOC_H (
        if exist "%LOCAL_DOC_H%" (
            echo Patching local rapidjson/document.h in .haxelib for compiler compatibility...
            powershell -Command "(Gc '%LOCAL_DOC_H%') -replace 'GenericStringRef& operator=\(const GenericStringRef& rhs\) \{ s = rhs\.s; length = rhs\.length; \}', '// GenericStringRef& operator=(const GenericStringRef& rhs) { s = rhs.s; length = rhs.length; }' | Out-File -encoding ASCII '%LOCAL_DOC_H%'"
            echo Local rapidjson patched successfully.
        )
    )
) else (
    if exist ".haxelib" (
        echo Local .haxelib directory already exists. Using it.
        for /f "delims=" %%f in ('dir /b /s .haxelib\document.h 2^>nul') do (
            set LOCAL_DOC_H=%%f
        )
        if defined LOCAL_DOC_H (
            if exist "%LOCAL_DOC_H%" (
                echo Patching local rapidjson/document.h in .haxelib for compiler compatibility...
                powershell -Command "(Gc '%LOCAL_DOC_H%') -replace 'GenericStringRef& operator=\(const GenericStringRef& rhs\) \{ s = rhs\.s; length = rhs\.length; \}', '// GenericStringRef& operator=(const GenericStringRef& rhs) { s = rhs.s; length = rhs.length; }' | Out-File -encoding ASCII '%LOCAL_DOC_H%'"
                echo Local rapidjson patched successfully.
            )
        )
    ) else (
        echo No local .haxelib directory or pre-configured zip found at %OAZA_ZIP%.
        echo Fallback: The project will use the global libraries installed in the system.
    )
)

echo.
echo ===================================================
echo Project libraries successfully configured!
echo ===================================================
pause
