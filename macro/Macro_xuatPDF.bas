Option Explicit

Dim swApp As Object
Dim Part As Object

Private Const PRINTER_NAME As String = "Microsoft Print to PDF"
Private Const swDocDRAWING As Long = 3

Sub main()

    On Error GoTo MacroError

    Set swApp = Application.SldWorks
    Set Part = swApp.ActiveDoc

    If Part Is Nothing Then
        MsgBox "Khong co file SolidWorks nao dang mo."
        Exit Sub
    End If

    If Part.GetType <> swDocDRAWING Then
        MsgBox "Hay mo file Drawing (.SLDDRW) truoc khi in PDF."
        Exit Sub
    End If

    Dim fullPath As String
    Dim fileName As String
    Dim folderPath As String
    Dim pdfFileName As String
    Dim pdfPath As String
    Dim dotPos As Long
    Dim oldPrinter As String
    Dim swDraw As Object
    Dim swPrintSpec As Object
    Dim pageRange(1) As Long
    Dim currentPage As Long
    Dim errNo As Long
    Dim errDesc As String
    Dim ok As Boolean
    Dim waitStart As Single

    fullPath = Part.GetPathName

    If fullPath = "" Then
        MsgBox "File Drawing hien tai chua duoc Save." & vbCrLf & _
               "Hay luu file SolidWorks truoc."
        Exit Sub
    End If

    fileName = Mid(fullPath, InStrRev(fullPath, "\") + 1)
    folderPath = Left(fullPath, InStrRev(fullPath, "\"))

    dotPos = InStrRev(fileName, ".")
    If dotPos > 0 Then
        fileName = Left(fileName, dotPos - 1)
    End If

    pdfFileName = GetNextVersionFileName(folderPath, CleanFileName(fileName), "pdf")
    pdfPath = folderPath & pdfFileName

    Set swDraw = Part
    currentPage = GetCurrentSheetIndex(swDraw)
    pageRange(0) = currentPage
    pageRange(1) = currentPage

    Set swPrintSpec = Part.Extension.GetPrintSpecification
    If swPrintSpec Is Nothing Then
        MsgBox "Khong lay duoc cau hinh in cua SolidWorks."
        Exit Sub
    End If

    oldPrinter = Part.Printer
    Part.Printer = PRINTER_NAME

    swPrintSpec.PrintToFile = True
    swPrintSpec.PrintFile = pdfPath
    swPrintSpec.PrintRange = pageRange
    swPrintSpec.NumberOfCopies = 1
    swPrintSpec.Collate = True

    ok = Part.Extension.PrintOut4(PRINTER_NAME, pdfPath, swPrintSpec)

    If oldPrinter <> "" Then
        Part.Printer = oldPrinter
    End If

    waitStart = Timer
    Do While Not FileExists(pdfPath) And Timer - waitStart < 10
        DoEvents
    Loop

    If Not FileExists(pdfPath) Then
        MsgBox "Da gui lenh in PDF nhung chua thay file duoc tao:" & vbCrLf & _
               pdfPath & vbCrLf & vbCrLf & _
               "Neu Microsoft Print to PDF van hien hop thoai Save, hay chon dung duong dan nay."
        Exit Sub
    End If

    MsgBox "Da xuat PDF:" & vbCrLf & pdfPath

    Exit Sub

MacroError:
    errNo = Err.Number
    errDesc = Err.Description

    On Error Resume Next
    If oldPrinter <> "" Then
        Part.Printer = oldPrinter
    End If
    MsgBox "Loi macro xuat PDF: " & errNo & vbCrLf & errDesc

End Sub

Private Function GetCurrentSheetIndex(ByVal swDraw As Object) As Long
    Dim currentSheet As Object
    Dim currentSheetName As String
    Dim sheetNames As Variant
    Dim i As Long

    Set currentSheet = swDraw.GetCurrentSheet
    currentSheetName = currentSheet.GetName
    sheetNames = swDraw.GetSheetNames

    For i = LBound(sheetNames) To UBound(sheetNames)
        If CStr(sheetNames(i)) = currentSheetName Then
            GetCurrentSheetIndex = i + 1
            Exit Function
        End If
    Next i

    GetCurrentSheetIndex = 1
End Function

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

Private Function GetNextVersionFileName(ByVal folderPath As String, ByVal baseName As String, ByVal extension As String) As String
    Dim candidateName As String
    Dim candidatePath As String
    Dim verNo As Long

    candidateName = baseName & "." & extension
    candidatePath = folderPath & candidateName
    If Not FileExists(candidatePath) Then
        GetNextVersionFileName = candidateName
        Exit Function
    End If

    verNo = 2
    Do
        candidateName = baseName & "_V" & CStr(verNo) & "." & extension
        candidatePath = folderPath & candidateName
        If Not FileExists(candidatePath) Then
            GetNextVersionFileName = candidateName
            Exit Function
        End If
        verNo = verNo + 1
    Loop
End Function

Private Function FileExists(ByVal filePath As String) As Boolean
    Dim fso As Object

    Set fso = CreateObject("Scripting.FileSystemObject")
    FileExists = fso.FileExists(filePath)
End Function
