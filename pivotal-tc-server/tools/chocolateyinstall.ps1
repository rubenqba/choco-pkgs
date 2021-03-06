﻿$ErrorActionPreference = 'Stop'; # stop on all errors


$packageName= 'PivotalTCServer' # arbitrary name for the package, used in messages
$packageVersion = '3.1.2'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'http://dist.springsource.com/release/STS/3.7.2.RELEASE/dist/e4.5/spring-tool-suite-3.7.2.RELEASE-e4.5.1-win32.zip'
#$url64      = 'http://dist.springsource.com/release/STS/3.7.2.RELEASE/dist/e4.5/spring-tool-suite-3.7.2.RELEASE-e4.5.1-win32-x86_64.zip'
$url64      = 'http://172.24.9.167/resources/sts/v3.7.2/spring-tool-suite-3.7.2.RELEASE-e4.5.1-win32-x86_64.zip'
$global:installLocation = "C:\tools\$packageName\v$packageVersion"

$checksum64     = "27e597792ff04392d2f255814716e8a7d4150b26"

if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
. "$PSScriptRoot\UtilFunctions.ps1"

#Parse-Parameters
Install-ZipPackage $packageName $url $global:installLocation $url64 -specificFolder "sts-bundle\pivotal-tc-server-developer-$packageVersion.RELEASE\*" -checksum64 "$checksum64" -checksumType64 "sha1"
$finalLocation = $(Join-Path $global:installLocation "tc-server-developer")
Move-Item $(Join-Path $global:installLocation "sts-bundle\pivotal-tc-server-developer-$packageVersion.RELEASE") $finalLocation -Force
Remove-Item $(Join-Path $global:installLocation "sts-bundle") -Force -Recurse
WriteInstalledFiles $global:installLocation

