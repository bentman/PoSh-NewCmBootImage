<#
.SYNOPSIS
    This script creates or modifies a boot image in Configuration Manager with specific drivers and optional components.

.DESCRIPTION
    The script extracts drivers from a specified logical folder in Configuration Manager and associates them with a new (or existing) boot image. 
    The boot image will also have associated optional components based on the list specified in the script.

.PARAMETERS
    The script doesn't accept parameters directly. Instead, variable values are hard-coded within the script body.

.NOTES
    File Name      : New-CmBootImage.ps1
    Prerequisite   : Configuration Manager module (`ConfigurationManager.psd1`) should be available and the script should be run with appropriate permissions.
    Author         : Copyright (c) 2023 https://github.com/bentman
    Site           : https://github.com/bentman/PoSh-CmBootImage.ps1

.CREDITS
    I used [OpenAI's ChatGPT](https://chat.openai.com/) to refactor the original script.
    - The original script can be found at [AdamGrossTX - ConfigMgr/BootImage/New-BootImage.ps1](https://github.com/AdamGrossTX/Toolbox/blob/bf59c0cf153c1b0f489f8e0135d86a05d221b66e/ConfigMgr/BootImage/New-BootImage.ps1)
        - Copyright (c) 2021 Adam Gross @ [AdamGrossTX](https://github.com/AdamGrossTX) - [asquaredozen](https://www.asquaredozen.com)
        - Implemented the core functionality of the script

.EXAMPLE
    .\New-CmBootImage.ps1
    Description: This example shows how to run the script to generate the boot image in Configuration Manager.

#>

# Variable Declarations
$SiteCode = Get-PSDrive | Where-Object { $_.Provider -like "CMSite" } | Select-Object -First 1 -ExpandProperty Name
$SiteServer = (Get-CMSite -SiteCode $SiteCode).ServerName
$ADKArch = "amd64" # x64
$SourceWIM = "\\$SiteServer\c$\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$ADKArch\en-us\winpe.wim"

# Extracting OS Version Number and Build Number from the WIM
$WimInfo = Get-WindowsImage -ImagePath $SourceWIM
$OSVersion = $WimInfo.OSVersion
$OSBuildNumber = ($WimInfo.ImageName -split "\.")[-1]

# Boot Image Variables
$BootImageRoot = "\\$SiteServer\d$\OSD\$OSVersion"
$BootImageFolderName = "$OSVersion"
$BootImageName = "$OSVersion.$OSBuildNumber"
$BootImageDescription = "Boot Image for OS Version: $OSVersion Build: $OSBuildNumber"
$NewWIMPath = Join-Path -Path $BootImageRoot -ChildPath $BootImageFolderName

# Optional Components
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

# Checking and Creating Directories and Copying Files
If(Test-Path $NewWIMPath) {
    Write-Host "NewWIMPath already exists $($NewWIMPath)"
}
Else {
    New-Item -Path $NewWIMPath -ItemType Directory
}

If(Test-Path $SourceWIM -ErrorAction Continue) {
    Copy-Item -Path $SourceWIM -Destination $NewWIMPath -Force
}

# Fetch the logical folder path for drivers based on your structure and then fetch the one with highest version
$DriverFolders = Get-CMObject -ClassName "SMS_Driver" | Where-Object { $_.ContentSourcePath -like "*\WinPE\A*" } 
$LatestDriverFolder = $DriverFolders | 
    Sort-Object { [int]($_.ContentSourcePath -split 'A' | Select-Object -Last 1) } -Descending | 
    Select-Object -First 1

# Retrieve drivers from the determined folder
$WinPEDrivers = Get-CMDriver | Where-Object { $_.ContentSourcePath -like "$($LatestDriverFolder.ContentSourcePath)*" }

# Configuration Manager Operations
$initParams = @{}
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SiteServer @initParams
}

Set-Location "$($SiteCode):\" @initParams

If(!(Get-CMBootImage -Name $BootImageName)) {
    $BootImage = New-CMBootImage -Name $BootImageName -Path "$($NewWIMPath)\winpe.wim" -Index 1
}
Else {
    $BootImage = Get-CMBootImage -Name $BootImageName
}

ForEach ($Driver in $WinPEDrivers) {
    Set-CMDriverBootImage -SetDriveBootImageAction AddDriverToBootImage -BootImage $BootImage -Driver $Driver
}

$OptionalComponents = Get-CMWinPEOptionalComponentInfo -Architecture 'x64' -LanguageId 1033 | Where-Object {$_.Name -in $OptionalComponentsList}

$BootImageOptions = @{
    DeployFromPxeDistributionPoint = $True
    EnableCommandSupport = $True 
    AddOptionalComponent = $OptionalComponents
    EnableBinaryDeltaReplication = $True
    Priority = 'High'
    ScratchSpace = 512
    Description = $BootImageDescription
}

$BootImage | Set-CMBootImage @BootImageOptions
