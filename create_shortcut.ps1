$wscript = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "Jerseytude.lnk"

$shortcut = $wscript.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "C:\jerseytude_bill_generator\run_desktop_app.bat"
$shortcut.WorkingDirectory = "C:\jerseytude_bill_generator"
$shortcut.IconLocation = "C:\jerseytude_bill_generator\windows\runner\resources\app_icon.ico,0"
$shortcut.Description = "Jerseytude Bill Generator Desktop Application"
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host "Created Desktop shortcut at: $shortcutPath"
