# Smart MSI Patch Installation Script

```powershell
# -----------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------
$PatchSource = "\\fileserver\patches"
$LogFolder   = "C:\PatchLogs"

# Set to $true if you want the script to stop on first failure
$StopOnError = $true

# -----------------------------------------------------------------
# Preparation
# -----------------------------------------------------------------
if (!(Test-Path $PatchSource))
{
    throw "Patch source $PatchSource is not accessible."
}

if (!(Test-Path $LogFolder))
{
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

$SummaryLog = Join-Path $LogFolder "PatchSummary.log"

function Write-Log {
    param([string]$Message)

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Message"

    Write-Host $Entry
    Add-Content -Path $SummaryLog -Value $Entry
}

Write-Log "Starting patch installation process."

# -----------------------------------------------------------------
# Discover MSI files
# -----------------------------------------------------------------
$MSIFiles = Get-ChildItem `
    -Path $PatchSource `
    -Filter "*.msi" `
    -File |
    Sort-Object LastWriteTime, Name

if ($MSIFiles.Count -eq 0)
{
    Write-Log "No MSI files found."
    exit 0
}

Write-Log "Found $($MSIFiles.Count) MSI files."

# -----------------------------------------------------------------
# Installation Loop
# -----------------------------------------------------------------
$RebootRequired = $false
$SuccessCount = 0
$FailureCount = 0

foreach ($MSI in $MSIFiles)
{
    $PackageName = $MSI.BaseName
    $MSILog = Join-Path $LogFolder "$PackageName.log"

    Write-Log "Installing $($MSI.Name)"

    $Arguments = @(
        "/i"
        "`"$($MSI.FullName)`""
        "/qn"
        "/norestart"
        "/L*v"
        "`"$MSILog`""
    )

    $Process = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList ($Arguments -join ' ') `
        -Wait `
        -PassThru

    switch ($Process.ExitCode)
    {
        0 {
            Write-Log "SUCCESS : $($MSI.Name)"
            $SuccessCount++
        }

        3010 {
            Write-Log "SUCCESS (Reboot Required) : $($MSI.Name)"
            $SuccessCount++
            $RebootRequired = $true
        }

        default {
            Write-Log "FAILED : $($MSI.Name) Exit Code=$($Process.ExitCode)"
            $FailureCount++

            if ($StopOnError)
            {
                Write-Log "Stopping because StopOnError=True"
                break
            }
        }
    }
}

# -----------------------------------------------------------------
# Summary
# -----------------------------------------------------------------
Write-Log "-----------------------------------"
Write-Log "Installation Summary"
Write-Log "Successful : $SuccessCount"
Write-Log "Failed     : $FailureCount"

if ($RebootRequired)
{
    Write-Log "One or more patches require a reboot."
}
else
{
    Write-Log "No reboot required."
}

Write-Log "Patch installation completed."
```
