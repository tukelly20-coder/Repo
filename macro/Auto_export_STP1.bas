Attribute VB_Name = "Auto_export_STP1"
Option Explicit

Dim swApp As Object
Dim Part As Object

Sub main()

    On Error GoTo MacroError

    Set swApp = Application.SldWorks
    Set Part = swApp.ActiveDoc

    If Part Is Nothing Then
        MsgBox "Khong co file SolidWorks nao dang mo."
        Exit Sub
    End If

    Dim fullPath As String
    Dim fileName As String
    Dim folderPath As String
    Dim savePath As String
    Dim dotPos As Long
    Dim ok As Boolean
    Dim errors As Long
    Dim warnings As Long
    Dim fallbackFolder As String
    Dim fallbackPath As String

    ' Lay duong dan file hien tai
    fullPath = Part.GetPathName

    If fullPath = "" Then
        MsgBox "File hien tai chua duoc Save." & vbCrLf & _
               "Hay luu file SolidWorks truoc."
        Exit Sub
    End If

    ' Lay ten file, bo duong dan
    fileName = Mid(fullPath, InStrRev(fullPath, "\") + 1)

    ' Lay thu muc cua file SolidWorks hien tai
    folderPath = Left(fullPath, InStrRev(fullPath, "\"))

    ' Bo duoi .SLDPRT / .SLDASM
    dotPos = InStrRev(fileName, ".")
    If dotPos > 0 Then
        fileName = Left(fileName, dotPos - 1)
    End If

    ' Tao duong dan STP cung cap voi file hien tai
    savePath = folderPath & fileName & ".stp"

    ' Xuat STP bang ModelDocExtension.SaveAs de lay duoc ma loi/canh bao.
    ok = Part.Extension.SaveAs(savePath, 0, 1, Nothing, errors, warnings)

    If (Not ok) Or errors <> 0 Then
        fallbackFolder = Environ$("USERPROFILE") & "\Desktop\STP_Export\"
        If Len(Dir$(fallbackFolder, vbDirectory)) = 0 Then
            MkDir fallbackFolder
        End If

        errors = 0
        warnings = 0
        fallbackPath = fallbackFolder & CleanFileName(fileName) & ".stp"
        ok = Part.Extension.SaveAs(fallbackPath, 0, 1, Nothing, errors, warnings)

        If (Not ok) Or errors <> 0 Then
            MsgBox "Xuat STP that bai!" & vbCrLf & _
                   "Thu muc goc: " & savePath & vbCrLf & _
                   "Thu muc fallback: " & fallbackPath & vbCrLf & _
                   "Ma loi: " & errors & vbCrLf & _
                   "Canh bao: " & warnings
        Else
            MsgBox "Da xuat STP:" & vbCrLf & fallbackPath
        End If
    Else
        MsgBox "Da xuat STP:" & vbCrLf & savePath
    End If

    Exit Sub

MacroError:
    MsgBox "Loi macro: " & Err.Number & vbCrLf & Err.Description

End Sub

Private Function CleanFileName(ByVal value As String) As String
    value = Replace(value, "\", "_")
    value = Replace(value, "/", "_")
    value = Replace(value, ":", "_")
    value = Replace(value, "*", "_")
    value = Replace(value, "?", "_")
    value = Replace(value, """", "_")
    value = Replace(value, "<", "_")
    value = Replace(value, ">", "_")
    value = Replace(value, "|", "_")
    CleanFileName = value
End Function
