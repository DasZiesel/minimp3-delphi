@echo off
SET LIB_GCCVERSION=0.0.0
where gcc >nul

if %ERRORLEVEL% == 1 goto nogcc

FOR /F "tokens=1,*" %%i IN ('gcc -dumpversion') DO (
  SET LIB_GCCVERSION=%%i
)

if NOT %LIB_GCCVERSION% == 4.8.1 goto wronggccversion

echo Compile...
gcc -c minimp3lib.cpp -o minimp3lib.obj
echo Finish...

goto end

:wronggccversion
echo.
echo Wrong GCC Version %LIB_GCCVERSION%. At the moment only GCC 4.8.1 32-bit are supported. Sorry!
goto end

:nogcc
echo.
echo No gcc compiler found

:end