Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get the folder containing this script
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

requestPath = scriptDir & "\request.json"
responsePath = scriptDir & "\response.json"

' Connect to WMI once
On Error Resume Next
Set wmi = GetObject("winmgmts:")
On Error GoTo 0

Sub CreateFolderTree(Path)
    If Path = "" Then Exit Sub
    If Not fso.FolderExists(Path) Then
        Dim Parent
        Parent = fso.GetParentFolderName(Path)
        If Parent <> "" And Parent <> Path Then
            CreateFolderTree Parent
        End If
        On Error Resume Next
        fso.CreateFolder Path
        On Error GoTo 0
    End If
End Sub

loopCount = 0

Do
    ' Only check if Palworld is running once every 40 iterations (approx. 10 seconds)
    loopCount = loopCount + 1
    If loopCount >= 40 Then
        loopCount = 0
        If Not wmi Is Nothing Then
            On Error Resume Next
            Set procs = wmi.ExecQuery("select * from Win32_Process where Name='PalWorld-Win64-Shipping.exe'")
            If Err.Number <> 0 Or procs.Count = 0 Then
                WScript.Quit
            End If
            On Error GoTo 0
        End If
    End If
    
    ' Check if request file exists
    If fso.FileExists(requestPath) Then
        On Error Resume Next
        Set reqFile = fso.OpenTextFile(requestPath, 1)
        verb = reqFile.ReadLine
        urlOrPath = reqFile.ReadLine
        reqFile.Close
        
        payloadPath = scriptDir & "\payload.json"
        
        If Err.Number = 0 And urlOrPath <> "" Then
            If UCase(verb) = "MKDIR" Then
                ' Create folder tree silently
                CreateFolderTree urlOrPath
            ElseIf UCase(verb) = "POST" Then
                ' Run curl hidden (0) with POST payload and wait for completion (True)
                cmd = "curl -s -X POST -H ""Content-Type: application/json"" -d @""" & payloadPath & """ """ & urlOrPath & """ -o """ & responsePath & """"
                shell.Run cmd, 0, True
            Else
                ' Run curl hidden (0) for GET and wait for completion (True)
                cmd = "curl -s """ & urlOrPath & """ -o """ & responsePath & """"
                shell.Run cmd, 0, True
            End If
            
            ' Delete request file to notify Lua that daemon finished
            fso.DeleteFile requestPath, True
        End If
        On Error GoTo 0
    End If
    
    WScript.Sleep 250
Loop
