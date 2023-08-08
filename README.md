# Description: New-CMBootImage.ps1 
Creates a new boot image or replaces an existing one. 
Sets drivers, optional components and advanced boot image property settings.
Allows for maintenance from boot image properties in the CM Console.

## Features:
- Extracts drivers from a specified logical folder in Configuration Manager.
- Associates extracted drivers with a new or existing boot image.
- Incorporates specified optional components into the boot image.

## Prerequisites:
- The script should be run with appropriate permissions.
- Configuration Manager module (`ConfigurationManager.psd1`) initiated from CM Console PowerShell or PowerShell_Ise.

## Parameters:
- `-sourceWim`: [path\file] Path to the source WIM (default is `$ADK\...\amd64\en-us\winpe.wim`)
- `-bootImageRoot`: [uncpath] Root directory for boot image (default is `\\$cmSiteServer\d$\OSD`)
- `-bootImageFolderName`: Content FolderName of boot image (default is `$osVersion` of the source WIM)
- `-bootImageName`: CM Name of new boot image (default is `$osVersion.$osBuild` of the source WIM)

## Usage:
- Without parameters, script will use defaults specified in body of script
```powershell
.\New-CmBootImage.ps1 
```
- Use the script with parameters example
```powershell
.\New-CmBootImage.ps1 -sourceWim "\\path\to\source.wim" -bootImageRoot "\\path\to\root" -bootImageFolderName "FolderName" -bootImageName "ImageName"
```

## Credits:
[OpenAI's ChatGPT](https://chat.openai.com/) was used to refactor the original script.
- The original script can be found at [AdamGrossTX - ConfigMgr/BootImage/New-BootImage.ps1](https://github.com/AdamGrossTX/Toolbox/blob/bf59c0cf153c1b0f489f8e0135d86a05d221b66e/ConfigMgr/BootImage/New-BootImage.ps1)
- Copyright (c) 2021 AdamGrossTX @ [AdamGrossTX](https://github.com/AdamGrossTX) - Website: [A Square Dozen](https://www.asquaredozen.com)

## Contributions
Contributions are welcome. Please open an issue or submit a pull request if you have any suggestions, questions, or would like to contribute to the project.

### GNU General Public License
This script is licensed under the GNU General Public License. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License or any later version. 

The script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this script. If not, see <https://www.gnu.org/licenses/>.