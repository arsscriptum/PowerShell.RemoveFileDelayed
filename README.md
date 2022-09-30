
# Pending File Delete in PowerShell

When you need to delete a file, but this is prevented because it is currently in use, or there is still an open handle on it.

In order to handle these cases, we use the native Win32 function [MoveFileExA ](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexa) with 
the flag MOVEFILE_DELAY_UNTIL_REBOOT with wich the system does not move the file until the operating system is restarted. The system moves the file immediately after AUTOCHK is executed, but before creating any paging files. Consequently, this parameter enables the function to delete paging files from previous startups.

To use this native function from PowerShell, I have created a small c# interface so I can call native code from managed code.


## IMPORTANT NOTES

The PowerShell's Remove-FileDelayed function uses the Win32 MoveFileEx with MOVEFILE_DELAY_UNTIL_REBOOT flag but it may not work
as expected, hence you need to know the details of it.


1. As was noted above to be able to use that flag one needs a process **running with elevated privileges** and that is impossible unless you have a service running with the system credentials handy at your disposal. I argued the reasons of such restrictions already and thus there's no need to rehash it here. To let you know the reasons why this APIs requires elevation, it is because it uses an older technique of removing files at boot time inherited from Windows NT by writing into an HKLM registry hive that is now a privileged resource.

2. The file may not be deleted on all OS's in some circumstances. Read the MSDN for more info. And that is the most annoying type of APIs in my book. You know the ones that have a big list of ifs and buts in the remarks section, something that is definitely prone to make your code fail.


# Workaround Operations

If needed, as a workaround, try the following technique:

1) Write your file into a temp folder with a call to GetTempPath. It will always be writable by your process. And write your file there. DO NOT write directly into the root folder like you showed.
2) On the next run of your program check if the file created in step A exists and if it does delete it. But even if you miss it, it won't be as much of a big deal as if you miss to remove it from C: (provided the file size is not too big).



## Using the Registry Editor to Debug - <span style="color:blue">**Requires Admin privileges**</span>

The delayed deletion uses the __HKLM__ registry hive which is a **privileged resource**, requiring admin privileges. If you have the required access rights, the following information may be useful.


### Enter the PendingFileRenameOperations Registry Value

**PendingFileRenameOperations** is a value that can be used to force move or delete a file on startup.

#### To delete a file on startup:

1) Open Registry Editor and navigate to HKLM\SYSTEM\CurrentControlSet\Control\Session Manager
2) Right-click in the right pane to add a new Multi-String Value and name it PendingFileRenameOperations
3) Double click the new PendingFileRenameOperations value to edit it and enter the full path of the file to be deleted starting with \??\ (e.g. \??\C:\Test.exe)
 <span style="color:red">**IMPORTANT NOTES**</span> _Do not use any quotations even if the path has spaces_
4) Click OK to close the value editor
5) Right-click the PendingFileRenameOperations value and select Modify Binary Data
6) At the very end of the binary value data, enter four zeroes 00 00 and click OK:

![pendingopbinarydata](https://raw.githubusercontent.com/arsscriptum/PowerShell.RemoveFileDelayed/main/img/pendingopbinarydata.png)

7) Restart the computer and the specified file as well as the PendingFileRenameOperations Registry value will be deleted

#### To move a file on startup:

1) Open Registry Editor and navigate to <span style="color:blue">*HKLM\SYSTEM\CurrentControlSet\Control\Session Manager*</span>
2) Right-click in the right pane to add a new Multi-String Value and name it PendingFileRenameOperations
3) Double click the new PendingFileRenameOperations value to edit it
4) On the first line enter the full source path of the file to be moved starting with \??\ (e.g. \??\C:\Source\Test.exe)
 <span style="color:red">**IMPORTANT NOTES**</span> Do not use any quotations even if the path has spaces
5) On the second line enter the full destination path of the file to be moved starting with \??\ (e.g. \??\C:\Destination\Test.exe)
  <span style="color:red">**IMPORTANT NOTES**</span> Do not use any quotations even if the path has spaces
6) Click OK to close the value editor
7) Restart the computer and the specified file will be moved and the PendingFileRenameOperations Registry value will be deleted
