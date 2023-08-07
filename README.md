# New-CMBootImage PowerShell Script

This repository contains the `New-CmBootImage.ps1` script which automates the creation or modification of a boot image in Configuration Manager. The script facilitates the extraction of drivers from a specified logical folder in Configuration Manager and associates them with the boot image. Additionally, specified optional components are added to the boot image.

## Features:

- Extracts drivers from a specified logical folder in Configuration Manager.
- Associates extracted drivers with a new or existing boot image.
- Incorporates specified optional components into the boot image.

## Prerequisites:

- The script should be run with appropriate permissions.
- Configuration Manager module (`ConfigurationManager.psd1`) should be available.

## Usage:

```powershell
.\New-CmBootImage.ps1
```

## Credits:
I used [OpenAI's ChatGPT](https://chat.openai.com/) to refactor the original script.
The original script can be found at [AdamGrossTX - ConfigMgr/BootImage/New-BootImage.ps1](https://github.com/AdamGrossTX/Toolbox/blob/bf59c0cf153c1b0f489f8e0135d86a05d221b66e/ConfigMgr/BootImage/New-BootImage.ps1)
        - Copyright (c) 2021 Matt Schwartz @ [AdamGrossTX](https://github.com/AdamGrossTX) - [asquaredozen](https://www.asquaredozen.com)

## Contributions

Contributions are welcome. Please open an issue or submit a pull request if you have any suggestions, questions, or would like to contribute to the project.

### GNU General Public License
This script is licensed under the GNU General Public License. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License or any later version. 

The script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this script. If not, see <https://www.gnu.org/licenses/>.