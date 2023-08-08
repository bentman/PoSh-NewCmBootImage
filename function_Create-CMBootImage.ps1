function Create-CMBootImage {
    [CmdletBinding()]
    param(
        [string]$sourceWim, 
        [string]$bootImageRoot, 
        [string]$bootImageFolderName, 
        [string]$bootImageName
    )

    $adkArch = "amd64"
    $cmDriversLogicalPath = "*\WinPE\A*"
    Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1') -ErrorAction SilentlyContinue
    $cmDrive = (Get-PSDrive | Where-Object {$_.Provider -is [Microsoft.ConfigurationManagement.PowerShell.Provider.CMSite]} | Select-Object -First 1) ?? {
        $cmSite = Get-CMSite | Select-Object -First 1
        New-PSDrive -Name $cmSite.SiteCode -PSProvider CMSite -Root $cmSite.ServerName -ErrorAction Stop
        Get-PSDrive -Name $cmSite.SiteCode
    }
    Set-Location $cmDrive.Name:
    $sourceWim = $sourceWim ?? "\\$cmSite.ServerName\c$\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\$adkArch\en-us\winpe.wim"
    $sourceWimInfo = Get-WindowsImage -ImagePath $sourceWim
    $bootImageRoot = $bootImageRoot ?? "\\$cmSite.ServerName\d$\OSD\$sourceWimInfo.OSVersion"
    $bootImageFolderName = $bootImageFolderName ?? "$sourceWimInfo.OSVersion"
    $bootImageName = $bootImageName ?? "$sourceWimInfo.OSVersion.$(($sourceWimInfo.ImageName -split "\.")[-1])"
    $newBootWimPath = Join-Path -Path $bootImageRoot -ChildPath $bootImageFolderName
    $newBootWimFullName = "$newBootWimPath\$bootImageName-boot.wim"
    $OptionalComponentsList = "WinPE-HTA","WinPE-MDAC","WinPE-Scripting","WinPE-WMI","WinPE-NetFX","WinPE-PowerShell","WinPE-DismCmdlets","WinPE-SecureBootCmdlets","WinPE-StorageWMI","WinPE-EnhancedStorage","WinPE-WinReCfg","WinPE-PlatformId"
    $OptionalComponents = Get-CMWinPEOptionalComponentInfo -Architecture 'x64' -LanguageId 1033 | Where-Object {$_.Name -in $OptionalComponentsList}
    $BootImageOptions = @{
        DeployFromPxeDistributionPoint = $True
        EnableCommandSupport = $True 
        EnableBinaryDeltaReplication = $True
        Priority = 'High'
        ScratchSpace = 512
        AddOptionalComponent = $OptionalComponents
        Description = "Boot Image for OS Version: $($sourceWimInfo.OSVersion) Build: $(($sourceWimInfo.ImageName -split "\.")[-1])"
    }
    if (-not (Test-Path $newBootWimPath)) {
        New-Item -Path $newBootWimPath -ItemType Directory
    }
    Copy-Item -Path $sourceWim -Destination $newBootWimFullName -Force
    $cmLatestDriverFolder = (Get-CMObject -ClassName "SMS_Driver" | Where-Object { $_.ContentSourcePath -like "$cmDriversLogicalPath" } | Sort-Object { [int]($_.ContentSourcePath -split 'A' | Select-Object -Last 1) } -Descending) | Select-Object -First 1
    $winPeDrivers = Get-CMDriver | Where-Object { $_.ContentSourcePath -like "$($cmLatestDriverFolder.ContentSourcePath)*" }
    try {
        $newCmBootImage = New-CMBootImage -Name $bootImageName -Path "$newBootWimFullName" -Index 1
        foreach ($Driver in $winPeDrivers) {
            Set-CMDriverBootImage -SetDriveBootImageAction AddDriverToBootImage -BootImageName $newCmBootImage -Driver $Driver
        }
        $newCmBootImage | Set-CMBootImage @BootImageOptions
        Write-Host "CM Boot image creation completed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    }
}
