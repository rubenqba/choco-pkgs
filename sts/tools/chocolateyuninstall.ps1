$packageName = 'STS'

if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$PSScriptRoot\UtilFunctions.ps1"

Uninstall-ZipPackage "$packageName"

Uninstall-DesktopLinkAndPinnedTaskBarItem "$packageName"
Uninstall-DesktopLinkAndPinnedTaskBarItem "$packageName"
