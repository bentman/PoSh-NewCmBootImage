<#
.SYNOPSIS
    This script assists the creation or modification of a boot image in Configuration Manager, enriching it with specified drivers and optional components.

.DESCRIPTION
    Initiating from a source WIM, the script first identifies necessary drivers from a designated folder in Configuration Manager. 
    Subsequently, it either creates a new boot image or modifies an existing one by associating it with these drivers. 
    Additionally, the boot image gets enhanced with a set of predetermined optional components.

.PARAMETERS
    -sourceWim
        Specifies the path to the source WIM (Defaults to the ADK amd64 boot.wim). 
    -bootImageRoot 
        Specifies the content root directory for the boot image (Defaults to UNC path \\$cmSiteServer\d$\OSD).
    -bootImageFolderName
        Designates the name of the boot image content folder (Defaults to OS version of the source WIM).
    -bootImageName 
        Determines the name of the boot image file (defaults to OS version and build of the source WIM).

.NOTES
    File Name      : New-CmBootImage.ps1
    Prerequisite   : Configuration Manager module (`ConfigurationManager.psd1`) initiated from CM Console PowerShell or PowerShell_Ise.
    Author         : Copyright (c) 2023 https://github.com/bentman
    Site           : https://github.com/bentman/PoSh-CmBootImage.ps1

.CREDITS
    [OpenAI's ChatGPT](https://chat.openai.com/) was employed to enhance the original script.
    - The prototype of the script is sourced from [AdamGrossTX - ConfigMgr/BootImage/New-BootImage.ps1](https://github.com/AdamGrossTX/Toolbox/blob/bf59c0cf153c1b0f489f8e0135d86a05d221b66e/ConfigMgr/BootImage/New-BootImage.ps1)
        - Copyright (c) 2021 Adam Gross @ [AdamGrossTX](https://github.com/AdamGrossTX) - [ASquareDozen](https://www.asquaredozen.com)
        - Developed the fundamental capabilities of the script.

.EXAMPLE
    .\New-CmBootImage.ps1 -sourceWim "\\path\to\source.wim" -bootImageRoot "\\path\to\root" -bootImageFolderName "FolderName" -bootImageName "ImageName"
    Description: Illustrates how to utilize the script to fabricate or revise the boot image in Configuration Manager using specific parameters.
#>

[CmdletBinding()]
param (
    # [path\file] Path to the source WIM (default is '%ADK%\...\amd64\en-us\winpe.wim')
    [Parameter(Mandatory=$false)] [string]$sourceWim, 
    # [unc path] Root directory for the boot image (default is '\\$cmSiteServer\d$\OSD')
    [Parameter(Mandatory=$false)] [string]$bootImageRoot, 
    # [folder name] Name of the boot image folder (default is the OS version of the source WIM)
    [Parameter(Mandatory=$false)] [string]$bootImageFolderName, 
    # [name] Name of the new boot image in CM (default is the OS version and build of the source WIM)
    [Parameter(Mandatory=$false)] [string]$bootImageName 
)

# Architecture for the ADK version
$adkArch = "amd64" # x86 has been removed from ADK, arm64 is not utilized at this time
# Filter to get driver paths that match a specific pattern
$cmDriversLogicalPath = "*\WinPE\A*" 

# Initialize CM Environment and Script Variables
begin {
    # Import ConfigurationManager module if not loaded
    if (-not (Get-Module -Name ConfigurationManager)) {
        Import-Module ($Env:SMS_ADMIN_UI_PATH -replace 'bin\\.*$', 'ConfigurationManager.psd1')
    }
    # Setup CMSite PSDrive
    $cmDrive = Get-PSDrive | 
        Where-Object {$_.Provider -is [Microsoft.ConfigurationManagement.PowerShell.Provider.CMSite]} | 
        Select-Object -First 1
    if (-not $cmDrive) {
        $cmSite = Get-CMSite | Select-Object -First 1
        New-PSDrive -Name $cmSite.SiteCode -PSProvider CMSite -Root $cmSite.ServerName
        $cmDrive = Get-PSDrive -Name $cmSite.SiteCode
    }
    Set-Location $cmDrive.Name:
    # Set default values
    if (-not $sourceWim) {
        $sourceWim = "\\$($cmSite.ServerName)\c$\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$adkArch\en-us\winpe.wim"
    }
    $sourceWimInfo = Get-WindowsImage -ImagePath $sourceWim -Index 1
    if ($null -eq $bootImageRoot) {$bootImageRoot = "\\$($cmSite.ServerName)\d$\OSD\$sourceWimInfo.Build"}
    if ($null -eq $bootImageFolderName) {$bootImageFolderName = $sourceWimInfo.Build}
    if ($null -eq $bootImageName) {$bootImageName = "$($sourceWimInfo.Build).$($sourceWimInfo.Version.Split('.')[-1])"}
}

# Configure variables for boot.wim properties 
    $newBootWimDescription = "Boot Image for OS-Build: $($sourceWimInfo.Build) CU-Level: $($sourceWimInfo.Version.Split('.')[-1])"
    $newBootWimPath = Join-Path $bootImageRoot $bootImageFolderName
    $newBootWimFullName = "$newBootWimPath\$bootImageName-boot.wim"
    $OptionalComponentsList = @(
        "WinPE-HTA",
        "WinPE-MDAC",
        "WinPE-Scripting",
        "WinPE-WMI",
        "WinPE-NetFX",
        "WinPE-PowerShell",
        "WinPE-DismCmdlets",
        "WinPE-SecureBootCmdlets",
        "WinPE-StorageWMI",
        "WinPE-EnhancedStorage",
        "WinPE-WinReCfg",
        "WinPE-PlatformId"
    )
    $OptionalComponents = Get-CMWinPEOptionalComponentInfo -Architecture 'x64' | Where-Object {$_.Name -in $OptionalComponentsList}
    $BootImageOptions = @{
        DeployFromPxeDistributionPoint = $True
        EnableCommandSupport = $True 
        Priority = 'High'
        ScratchSpace = 512
        AddOptionalComponent = $OptionalComponents
        Description = $newBootWimDescription
    }

# Execution
if (-not (Test-Path $newBootWimPath)) {
    New-Item -Path $newBootWimPath -ItemType Directory
}
Copy-Item -Path $sourceWim -Destination $newBootWimFullName -Force
# Add drivers and setup boot image
$winPeDrivers = Get-CMDriver | Where-Object { $_.ContentSourcePath -like $cmDriversLogicalPath }
try {
    $newCmBootImage = New-CMBootImage -Name $bootImageName -Path "$newBootWimFullName" -Index 1
    foreach ($Driver in $winPeDrivers) {
        Set-CMDriverBootImage -SetDriveBootImageAction AddDriverToBootImage -BootImageName $newCmBootImage -Driver $Driver
    }

    $newCmBootImage | Set-CMBootImage @BootImageOptions
    Write-Host "Boot image creation successful!" -ForegroundColor Green
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
