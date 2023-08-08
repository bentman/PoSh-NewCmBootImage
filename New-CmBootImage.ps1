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
param(
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
    $adkArch = "amd64" 

# Filter to get driver paths that match a specific pattern
    $cmDriversLogicalPath = "*\WinPE\A*" 

begin {
    # Ensure ConfigurationManager.psd1 is loaded
    if ($null -eq (Get-Module ConfigurationManager)) {
        Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')
    }

    # Determine if a CMSite PSDrive exists
    $cmDrive = Get-PSDrive | Where-Object {$_.Provider -is [Microsoft.ConfigurationManagement.PowerShell.Provider.CMSite]} | Select-Object -First 1
    
    # If no CMSite PSDrive is found, determine site code and server, then create the drive
    if ($null -eq $cmDrive) {
        $cmSite = Get-CMSite | Select-Object -First 1
        $cmSiteCode = $cmSite.SiteCode
        $cmSiteServer = $cmSite.ServerName
        New-PSDrive -Name $cmSiteCode -PSProvider CMSite -Root $cmSiteServer
        $cmDrive = Get-PSDrive -Name $cmSiteCode
    }
    
    # Change current location to the PSDrive
    Set-Location $cmDrive.Name:

    # If no sourceWim is specified, use the default ADK amd64 boot.wim on the site server
    if (-not $sourceWim) {
        $sourceWim = "\\$cmSiteServer\c$\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$adkArch\en-us\winpe.wim"
    }
    
    # Extract details like OS version and build number from the source WIM
    $sourceWimInfo = Get-WindowsImage -ImagePath $sourceWim
    $sourceWimOs = $sourceWimInfo.OSVersion
    $sourceWimBuild = ($sourceWimInfo.ImageName -split "\.")[-1]

    # Provide default values if parameters aren't provided
    if (-not $bootImageRoot) {$bootImageRoot = "\\$cmSiteServer\d$\OSD\$sourceWimOs"}
    if (-not $bootImageFolderName) {$bootImageFolderName = "$sourceWimOs"}
    if (-not $bootImageName) {$bootImageName = "$sourceWimOs.$sourceWimBuild"}
}

# Construct paths and descriptions for the new boot image
    $newBootWimDescription = "Boot Image for OS Version: $sourceWimOs Build: $sourceWimBuild"
    $newBootWimPath = Join-Path -Path $bootImageRoot -ChildPath $bootImageFolderName
    $newBootWimFullName = "$newBootWimPath\$bootImageName-boot.wim"

# Define optional components to be added to the boot image
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

# Boot image configuration options
    $OptionalComponents = Get-CMWinPEOptionalComponentInfo -Architecture 'x64' -LanguageId 1033 | Where-Object {$_.Name -in $OptionalComponentsList}
    $BootImageOptions = @{
        DeployFromPxeDistributionPoint = $True
        EnableCommandSupport = $True 
        EnableBinaryDeltaReplication = $True
        Priority = 'High'
        ScratchSpace = 512
        AddOptionalComponent = $OptionalComponents
        Description = $newBootWimDescription
    }

# Prepare for creating the new CM boot image
    if (Test-Path $newBootWimPath) {
        Write-Host "newBootWimPath already exists $($newBootWimPath)"
    } else {
        New-Item -Path $newBootWimPath -ItemType Directory
    }
    Copy-Item -Path $sourceWim -Destination $newBootWimFullName -Force

# Create the new CM boot image with drivers, optional components, and apply settings
    $cmDriverFolder = Get-CMObject -ClassName "SMS_Driver" | Where-Object { $_.ContentSourcePath -like "$cmDriversLogicalPath" } 
    $cmLatestDriverFolder = $cmDriverFolder | Sort-Object { [int]($_.ContentSourcePath -split 'A' | Select-Object -Last 1) } -Descending | Select-Object -First 1
    $winPeDrivers = Get-CMDriver | Where-Object { $_.ContentSourcePath -like "$($cmLatestDriverFolder.ContentSourcePath)*" }

# Add drivers to the boot image
    try {
        $newCmBootImage = New-CMBootImage -Name $bootImageName -Path "$newBootWimFullName" -Index 1
        foreach ($Driver in $winPeDrivers) {
            Set-CMDriverBootImage -SetDriveBootImageAction AddDriverToBootImage -BootImageName $newCmBootImage -Driver $Driver
            Write-Host "Drivers were added to CM Boot image properties successfully!" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error occurred while adding drivers to new CM boot image." -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Yellow
    }

# Apply settings to the boot image
    try {
        $newCmBootImage | Set-CMBootImage @BootImageOptions
        Write-Host "CM Boot image creation completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error occurred while setting parameters on the CM boot image." -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Yellow
    }
