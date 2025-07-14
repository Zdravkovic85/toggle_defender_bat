@echo off
:: Require admin privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if %errorlevel% NEQ 0 (
    echo.
    echo This script requires administrator privileges.
    echo Right-click it and select "Run as administrator".
    pause
    exit /b
)

echo ========================================================
echo      TOGGLE WINDOWS DEFENDER (ON / OFF)
echo ========================================================
echo.

:: Check current Defender state
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware >nul 2>&1
if %errorlevel%==0 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware 2^>nul') do set DEFENDERSTATE=%%a
) else (
    set DEFENDERSTATE=0x0
)

:: Check if Defender is disabled
if /I "%DEFENDERSTATE%"=="0x1" (
    echo 🔁 Windows Defender appears to be DISABLED.
    echo Enabling Defender...

    :: Remove DisableAntiSpyware flag
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /f

    :: Restore services
    sc config WinDefend start= auto
    sc start WinDefend

    :: Re-enable real-time protection
    PowerShell -Command "Try { Set-MpPreference -DisableRealtimeMonitoring $false } Catch { Write-Host 'Could not re-enable realtime monitoring' }"

    :: Enable Defender scheduled tasks
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /ENABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /ENABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /ENABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Verification" /ENABLE

    echo.
    echo ✅ Defender has been re-enabled.
    echo 🔒 Please go to Windows Security and re-enable Tamper Protection manually.
) else (
    echo 🔁 Windows Defender appears to be ENABLED.
    echo Disabling Defender...

    echo.
    echo ⚠️ You must turn OFF "Tamper Protection" manually before continuing!
    echo Open:
    echo     Windows Security > Virus & threat protection > Manage Settings > Tamper Protection > OFF
    echo.
    set /p TP=Have you disabled Tamper Protection? (yes/no): 
    if /I not "%TP%"=="yes" (
        echo Please disable Tamper Protection and re-run this script.
        pause
        exit /b
    )

    :: Set registry key to disable Defender
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f

    :: Stop and disable Defender service
    sc stop WinDefend
    sc config WinDefend start= disabled

    :: Disable scheduled Defender tasks
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance" /DISABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Cleanup" /DISABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan" /DISABLE
    schtasks /Change /TN "Microsoft\Windows\Windows Defender\Windows Defender Verification" /DISABLE

    :: Disable real-time protection
    PowerShell -Command "Try { Set-MpPreference -DisableRealtimeMonitoring $true } Catch { Write-Host 'Could not disable realtime monitoring' }"

    echo.
    echo ✅ Defender has been disabled (if Tamper Protection was OFF).
)

echo.
set /p REBOOT=Do you want to reboot now? (yes/no): 
if /I "%REBOOT%"=="yes" (
    shutdown /r /t 5
) else (
    echo Please restart your PC manually to apply all changes.
    pause
)
