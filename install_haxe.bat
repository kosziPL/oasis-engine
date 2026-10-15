@echo off
echo ===================================================
echo    Haxe ^& Global Dependencies Installer (Lix)      
echo           For FNF Psych Engine (Windows)           
echo ===================================================

:: Check for Node.js, npm, git
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Node.js is not installed or not in PATH!
    pause
    exit /b 1
)
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Git is not installed or not in PATH!
    pause
    exit /b 1
)

echo Installing lix package manager locally...
call npm ci

echo Installing and selecting Haxe 4.2.5...
call npx lix install haxe 4.2.5
call npx lix use haxe 4.2.5

echo Configuring .haxerc...
(
echo {
echo   "version": "4.2.5",
echo   "resolveLibs": "haxelib"
echo }
) > .haxerc

echo Configuring global haxelib path...
if not exist "%USERPROFILE%\haxe\haxelib" mkdir "%USERPROFILE%\haxe\haxelib"
call npx haxelib setup "%USERPROFILE%\haxe\haxelib"

set HAXELIB_CMD=npx haxelib -R http://lib.haxe.org/

echo Installing base Haxe libraries globally...
call %HAXELIB_CMD% install flixel 4.11.0 --always
call %HAXELIB_CMD% install flixel-addons 2.11.0 --always
call %HAXELIB_CMD% install flixel-ui 2.4.0 --always
call %HAXELIB_CMD% install hscript 2.5.0 --always
call %HAXELIB_CMD% install tjson 1.4.0 --always
call %HAXELIB_CMD% install hxjsonast 1.1.0 --always
call %HAXELIB_CMD% install hxCodec 2.5.1 --always
call %HAXELIB_CMD% install lime 7.9.0 --always
call %HAXELIB_CMD% install openfl 9.2.1 --always
call %HAXELIB_CMD% install hxcpp 4.3.2 --always
call %HAXELIB_CMD% install bson 0.1.0 --always

echo Installing Git-based libraries globally...
call %HAXELIB_CMD% git linc_luajit https://github.com/superpowers04/linc_luajit --always
call %HAXELIB_CMD% git hscript-ex https://github.com/ianharrigan/hscript-ex --always
call %HAXELIB_CMD% git discord_rpc https://github.com/Aidan63/linc_discord-rpc --always

echo Initializing git submodules for global discord_rpc...
for /f "tokens=*" %%i in ('call npx haxelib path discord_rpc ^| findstr /v "\-"') do (
    set DISCORD_RPC_PATH=%%i
    goto :found_path
)
:found_path
if exist "%DISCORD_RPC_PATH%" (
    echo Found discord_rpc at: %DISCORD_RPC_PATH%
    pushd "%DISCORD_RPC_PATH%"
    git submodule update --init --recursive
    
    set DOCUMENT_H_PATH=lib\rapidjson\include\rapidjson\document.h
    if exist "%DOCUMENT_H_PATH%" (
        echo Patching rapidjson/document.h for modern compiler compatibility...
        powershell -Command "(Gc %DOCUMENT_H_PATH%) -replace 'GenericStringRef& operator=\(const GenericStringRef& rhs\) \{ s = rhs\.s; length = rhs\.length; \}', '// GenericStringRef& operator=(const GenericStringRef& rhs) { s = rhs.s; length = rhs.length; }' | Out-File -encoding ASCII %DOCUMENT_H_PATH%"
        echo Patched rapidjson successfully.
    )
    popd
) else (
    echo Warning: Could not find discord_rpc global path.
)

echo.
echo ===================================================
echo Global Haxe and dependencies installation complete!
echo ===================================================
pause
