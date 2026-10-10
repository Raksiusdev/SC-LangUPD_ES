Set WshShell = CreateObject("WScript.Shell")
Set Fso = CreateObject("Scripting.FileSystemObject")
' El .bat vive junto a este launcher (el instalador deja ambos en C:\Scripts)
WshShell.Run chr(34) & Fso.BuildPath(Fso.GetParentFolderName(WScript.ScriptFullName), "UpdateStarCitizenES.bat") & Chr(34), 0
Set Fso = Nothing
Set WshShell = Nothing