Option Explicit

Dim shell, fso, scriptDir, command, args, i

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
command = """" & scriptDir & "\Start_Pro_Scanner.bat" & """"

For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & """" & Replace(WScript.Arguments(i), """", """""") & """"
Next

shell.CurrentDirectory = scriptDir
shell.Run command & args, 0, False
