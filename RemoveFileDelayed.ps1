<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜
#̷𝓍   🇵​​​​​🇴​​​​​🇼​​​​​🇪​​​​​🇷​​​​​🇸​​​​​🇭​​​​​🇪​​​​​🇱​​​​​🇱​​​​​ 🇸​​​​​🇨​​​​​🇷​​​​​🇮​​​​​🇵​​​​​🇹​​​​​ 🇧​​​​​🇾​​​​​ 🇬​​​​​🇺​​​​​🇮​​​​​🇱​​​​​🇱​​​​​🇦​​​​​🇺​​​​​🇲​​​​​🇪​​​​​🇵​​​​​🇱​​​​​🇦​​​​​🇳​​​​​🇹​​​​​🇪​​​​​.🇶​​​​​🇨​​​​​@🇬​​​​​🇲​​​​​🇦​​​​​🇮​​​​​🇱​​​​​.🇨​​​​​🇴​​​​​🇲​​​​​
#>


function Remove-FileDelayed {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                throw "File or folder does not exist"
            }
            if(-Not ($_ | Test-Path -PathType Leaf) ){
                throw "The Path argument must be a file. Directory paths are not allowed."
            }
            return $true 
        })]
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('p')]
        [String]$Path,
        [Parameter(Mandatory=$false, HelpMessage="When enabled, the function will try to delete the file immediately. Other operations will be executed.")]
        [switch]$TryImmediate,
        [Parameter(Mandatory=$false, HelpMessage="The delete mode, when enabled the files will be permanently deleted. The alternative, is using the recycling bin")]
        [Alias('p','force')]
        [switch]$Permanent
    )


    # ================================================
    # the c# implementation of the MoveFileEx function
    
    $ManagedCode = @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
           
        public class DelayedMoveFile
        {
            public enum MoveFileFlags
            {
                MOVEFILE_DELAY_UNTIL_REBOOT         = 0x00000004
            }
     
            [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
            static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, MoveFileFlags dwFlags);
            
            public static bool MarkFileDelete (string sourcefile)
            {
                return MoveFileEx(sourcefile, null, MoveFileFlags.MOVEFILE_DELAY_UNTIL_REBOOT);         
            }
            public static bool DelayMoveFile (string sourcefile,string dest)
            {
                return MoveFileEx(sourcefile, dest, MoveFileFlags.MOVEFILE_DELAY_UNTIL_REBOOT);         
            }
        }

"@


    # ========================================
    # the data compilation and intanciation..
    try{
        $TypeData = Add-Type $ManagedCode -Verbose -PassThru
        $TypeData | % { 
            $fname = $_.Name
            Write-Verbose "DelayedMoveFile => New function $fname"
        }
    }catch{
        Write-Verbose "Class DelayedMoveFile already added"
    }


    # =========================================
    # the center piece
    try{

        # Set the delete mode
        $DeleteMode = "SendToRecycleBin"
        if($Permanent){
            $DeleteMode = "DeletePermanently" 
            Write-Verbose "Permanent => DeleteMode set to `"$DeleteMode`" "
        }

        $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            throw "Error when accessing `"$Path`""
        }
        else {
            $fullpath = $item.FullName
            if($TryImmediate){
                Write-Verbose "TryImmediate => try to delete the file now"
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($fullpath, 'OnlyErrorDialogs', $DeleteMode)    
            }
            Write-Verbose "DelayedMoveFile => Mark the file for deletion"
            $deleteResult = [DelayedMoveFile]::MarkFileDelete($fullpath)
            if ($deleteResult -eq $false) {
                Write-Verbose "DelayedMoveFile failure for `"$fullpath`""  # calls GetLastError
            } else {
                Write-Verbose "DelayedMoveFile success for `"$fullpath`". Will be deleted on reboot."
            }
        }

    }catch{
        Write-Error $_
    }

}