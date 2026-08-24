Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
strUrl = "file:///" & Replace(strPath & "\desk_clock.html", "\", "/")
WshShell.Run "msedge.exe --app=""" & strUrl & """ --window-size=350,350", 0, False
