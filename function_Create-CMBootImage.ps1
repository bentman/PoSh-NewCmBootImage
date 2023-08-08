[CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)] [string]$sourceWim,
        [Parameter(Mandatory=$false)] [string]$bootImageRoot,
        [Parameter(Mandatory=$false)] [string]$bootImageFolderName,
        [Parameter(Mandatory=$false)] [string]$bootImageName 
    )
    $adkArch = "amd64"
    $cmDriversLogicalPath = "*\WinPE\A*" 
    begin {
        if (-not (Get-Module -Name ConfigurationManager)) {
            Import-Module ($Env:SMS_ADMIN_UI_PATH -replace 'bin\\.*$', 'ConfigurationManager.psd1')
        }
        $cmDrive = Get-PSDrive | 
            Where-Object {$_.Provider -is [Microsoft.ConfigurationManagement.PowerShell.Provider.CMSite]} | 
            Select-Object -First 1
        if (-not $cmDrive) {
            $cmSite = Get-CMSite | Select-Object -First 1
            New-PSDrive -Name $cmSite.SiteCode -PSProvider CMSite -Root $cmSite.ServerName
            $cmDrive = Get-PSDrive -Name $cmSite.SiteCode
        }
        Set-Location $cmDrive.Name:
        if (-not $sourceWim) {
            $sourceWim = "\\$($cmSite.ServerName)\c$\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$adkArch\en-us\winpe.wim"
        }
        $sourceWimInfo = Get-WindowsImage -ImagePath $sourceWim -Index 1
        if ($null -eq $bootImageRoot) {$bootImageRoot = "\\$($cmSite.ServerName)\d$\OSD\$sourceWimInfo.Build"}
        if ($null -eq $bootImageFolderName) {$bootImageFolderName = $sourceWimInfo.Build}
        if ($null -eq $bootImageName) {$bootImageName = "$($sourceWimInfo.Build).$($sourceWimInfo.Version.Split('.')[-1])"}
    }
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
    if (-not (Test-Path $newBootWimPath)) {
        New-Item -Path $newBootWimPath -ItemType Directory
    }
    Copy-Item -Path $sourceWim -Destination $newBootWimFullName -Force
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
