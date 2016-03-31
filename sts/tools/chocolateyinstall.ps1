$ErrorActionPreference = 'Stop'; # stop on all errors


$packageName= 'SpringToolSuite' # arbitrary name for the package, used in messages
$packageVersion = '3.7.3'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = "http://dist.springsource.com/release/STS/$packageVersion.RELEASE/dist/e4.6/spring-tool-suite-$packageVersion.RELEASE-e4.6-win32.zip"
$url64      = "http://dist.springsource.com/release/STS/$packageVersion.RELEASE/dist/e4.6/spring-tool-suite-$packageVersion.RELEASE-e4.6-win32-x86_64.zip"

$global:installLocation = "C:\tools\SpringToolSuite\v$packageVersion"

$checksum64     = "58866072800a185168b1827963660f7d8eb134b5"

Write-Host "$toolsDir"
Write-Host "$(Split-Path -Leaf $url64)"

if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$PSScriptRoot\UtilFunctions.ps1"

#Parse-Parameters
Install-ZipPackage $packageName $url $global:installLocation $url64 -specificFolder "sts-bundle\sts-$packageVersion.RELEASE\*" -checksum64 "$checksum64" -checksumType64 "sha1"
$finalLocation = $(Join-Path $global:installLocation "STS")
Move-Item $(Join-Path $global:installLocation "sts-bundle\sts-$packageVersion.RELEASE") $finalLocation -Force
Remove-Item $(Join-Path $global:installLocation "sts-bundle") -Force -Recurse
WriteInstalledFiles $global:installLocation


$stsExecutable = $(Join-Path $finalLocation "STS.exe")
Install-ChocolateyDesktopLink "$stsExecutable"
Install-ChocolateyPinnedTaskBarItem "$stsExecutable"
