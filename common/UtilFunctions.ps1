function Parse-Parameters {
	$arguments = @{};
	$packageParameters = $env:chocolateyPackageParameters;

	if($packageParameters) {
		Write-Host "PackageParameters: $packageParameters"
		$MATCH_PATTERN = "/([a-zA-Z]+)=(.*)"
		$PARAMATER_NAME_INDEX = 1
		$VALUE_INDEX = 2
		
		if($packageParameters -match $MATCH_PATTERN){
			$results = $packageParameters | Select-String $MATCH_PATTERN -AllMatches 
			
			$results.matches | % { 
			$arguments.Add(
				$_.Groups[$PARAMATER_NAME_INDEX].Value.Trim(),
				$_.Groups[$VALUE_INDEX].Value.Trim())
			}
		} else {
			Write-Host "Default packageParameters will be used"
		}
		
		if($arguments.ContainsKey("InstallLocation")) {
			$global:installLocation = $arguments["InstallLocation"];
			
			Write-Host "Value variable installLocation changed to $global:installLocation"
		} else {
			Write-Host "Default InstallLocation will be used"
		}
	} else {
		Write-Host "Package parameters will not be overwritten"
	}
}

function Uninstall-ZipPackage {
param(
  [string] $packageName
)
	if(!$packageName) {
		Write-ChocolateyFailure "Uninstall-ZipPackage" "Missing PackageName input parameter."
		return
	}
	
	ChildItem "$env:ChocolateyInstall\lib\${packageName}" -Recurse -Filter "${packageName}Install.zip.txt" | 
	ForEach-Object{ $installLocation = (Get-Content $_.FullName | Select-Object -First 1);
		if (("$installLocation" -match "${packageName}|apache-tomcat") -and (Test-Path -Path "$installLocation")) {
			Write-Host "Uninstalling by removing directory $installLocation";
			Remove-Item -Recurse -Force "$installLocation"
		} else {
			Write-ChocolateyFailure "Uninstall-ZipPackage" "Unable to delete directory: $installLocation"
		}
	}
}

function Uninstall-DesktopLinkAndPinnedTaskBarItem {
	param(
	[string] $packageName
	)

	$desktopLink="${env:USERPROFILE}\Desktop\${packageName}.exe.lnk"
	$pinnedLink="${env:USERPROFILE}\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\${packageName}.lnk"

	if(!$packageName) {
		throw "Missing PackageName input parameter."
		return
	}

	If (Test-Path "$desktopLink") {
		Remove-Item $desktopLink
		'desktoplink removed'
		return 
	}
	
	If (Test-Path "$pinnedLink") {
		Remove-Item $pinnedLink
		'pinnedlink removed'
		return
	}
}

# Issue https://github.com/chocolatey/chocolatey/issues/406
function Get-Unzip {
<#
.SYNOPSIS
Unzips an archive and returns the location for further processing.

.DESCRIPTION
Unzips an archive using the 7za command line tool.

.PARAMETER FileFullPath
The full path to your archive.

.PARAMETER Destination
A directory where you would like the unzipped files to end up.

.PARAMETER SpecificFolder
OPTIONAL - A specific directory or glob pattern within the archive to extract.

.PARAMETER PackageName
OPTIONAL - This will faciliate logging unzip activity for subsequent uninstall.

.EXAMPLE
$scriptPath = (Split-Path -parent $MyInvocation.MyCommand.Definition)
Get-ChocolateyUnzip "c:\someFile.zip" $scriptPath somedirinzip\somedirinzip

.OUTPUTS
Returns the passed in $destination.

.NOTES
This helper reduces the number of lines one would have to write to unzip a file to 1 line.
There is no error handling built into this method.
#>
param(
  [string] $fileFullPath,
  [string] $destination,
  [string] $specificFolder,
  [string] $packageName
)
  Write-Debug "Running 'Get-ChocolateyUnzip' with fileFullPath:'$fileFullPath', destination:'$destination'";

  if ($packageName) {
    $packagelibPath=$env:chocolateyPackageFolder
    if (!(Test-Path -path $packagelibPath)) {
      New-Item $packagelibPath -type directory
    }

    $zipFilename=split-path $fileFullPath -Leaf
    $zipExtractLogFullPath=join-path $packagelibPath $zipFilename`.txt
  }

  Write-Host "Extracting $fileFullPath to $destination..."
  if (![System.IO.Directory]::Exists($destination)) {[System.IO.Directory]::CreateDirectory($destination)}

  # On first install, env:ChocolateyInstall might be null still - join-path has issues
  $7zip = Join-Path "$env:SystemDrive" 'chocolatey\tools\7za.exe'
  if ($env:ChocolateyInstall){
    $7zip = Join-Path "$env:ChocolateyInstall" 'tools\7za.exe'
  }

  if ($zipExtractLogFullPath) {
    $unzipOps = "Start-Process `"$7zip`" -ArgumentList `"x `"`"$fileFullPath`"`" -o`"`"$destination`"`" `"`"$specificFolder`"`" -y`" -Wait -Windowstyle Hidden"
    $scriptBlock = [scriptblock]::create($unzipOps)

    Write-FileUpdateLog $zipExtractLogFullPath $destination $scriptBlock
  } else {
    Start-Process "$7zip" -ArgumentList "x `"$fileFullPath`" -o`"$destination`" `"$specificFolder`" -y" -Wait -WindowStyle Hidden
  }

  return $destination
}

# Copyright 2011 - Present RealDimensions Software, LLC & original authors/contributors from https://github.com/chocolatey/chocolatey
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Install-ZipPackage {
<#
.SYNOPSIS
Downloads and unzips a package

.DESCRIPTION
This will download a file from a url and unzip it on your machine.

.PARAMETER PackageName
The name of the package we want to download - this is arbitrary, call it whatever you want.
It's recommended you call it the same as your nuget package id.

.PARAMETER Url
This is the url to download the file from.

.PARAMETER Url64bit
OPTIONAL - If there is an x64 installer to download, please include it here. If not, delete this parameter

.PARAMETER UnzipLocation
This is a location to unzip the contents to, most likely your script folder.

.PARAMETER Checksum
OPTIONAL (Right now) - This allows a checksum to be validated for files that are not local

.PARAMETER Checksum64
OPTIONAL (Right now) - This allows a checksum to be validated for files that are not local

.PARAMETER ChecksumType
OPTIONAL (Right now) - 'md5', 'sha1', 'sha256' or 'sha512' - defaults to 'md5'

.PARAMETER ChecksumType64
OPTIONAL (Right now) - 'md5', 'sha1', 'sha256' or 'sha512' - defaults to ChecksumType

.PARAMETER options
OPTIONAL - Specify custom headers

Example:
-------- 
  $options =
  @{
    Headers = @{
      Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
      'Accept-Charset' = 'ISO-8859-1,utf-8;q=0.7,*;q=0.3';
      'Accept-Language' = 'en-GB,en-US;q=0.8,en;q=0.6';
      Cookie = 'products.download.email=ewilde@gmail.com';
      Referer = 'http://submain.com/download/ghostdoc/';
    }
  }

  Get-ChocolateyWebFile 'ghostdoc' 'http://submain.com/download/GhostDoc_v4.0.zip' -options $options

.EXAMPLE
Install-ChocolateyZipPackage '__NAME__' 'URL' "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

.OUTPUTS
None

.NOTES
This helper reduces the number of lines one would have to write to download and unzip a file to 1 line.
This method has error handling built into it.

.LINK
  Get-ChocolateyWebFile
  Get-ChocolateyUnzip
#>
param(
  [string] $packageName,
  [string] $url,
  [string] $unzipLocation,
  [alias("url64")][string] $url64bit = '',
  [string] $specificFolder ="",
  [string] $checksum = '',
  [string] $checksumType = '',
  [string] $checksum64 = '',
  [string] $checksumType64 = '',
  [hashtable] $options = @{Headers=@{}}
)
  Write-Debug "Running 'Install-ChocolateyZipPackage' for $packageName with url:`'$url`', unzipLocation: `'$unzipLocation`', url64bit: `'$url64bit`', specificFolder: `'$specificFolder`', checksum: `'$checksum`', checksumType: `'$checksumType`', checksum64: `'$checksum64`', checksumType64: `'$checksumType64`' ";

  $fileType = 'zip'

  $chocTempDir = Join-Path $env:TEMP "chocolatey"
  $tempDir = Join-Path $chocTempDir "$packageName"
  if ($env:packageVersion -ne $null) {$tempDir = Join-Path $tempDir "$env:packageVersion"; }

  if (![System.IO.Directory]::Exists($tempDir)) {[System.IO.Directory]::CreateDirectory($tempDir) | Out-Null}
  $file = Join-Path $tempDir "$($packageName)Install.$fileType"
  
  Get-ChocolateyWebFile $packageName $file $url $url64bit -checkSum $checkSum -checksumType $checksumType -checkSum64 $checkSum64 -checksumType64 $checksumType64 -options $options
  Get-Unzip "$file" $unzipLocation $specificFolder $packageName
}


function GetFiles($path = $pwd, [string[]]$exclude) 
{ 
    foreach ($item in Get-ChildItem $path)
    {
        if ($exclude | Where {$item -like $_}) { continue }

		$item.FullName
        if (Test-Path $item.FullName -PathType Container) 
        {
            GetFiles $item.FullName $exclude
        }
    } 
}

function WriteInstalledFiles($path) {

	$fileType = 'zip'

	$chocTempDir = Join-Path $env:TEMP "chocolatey"
	$tempDir = Join-Path $chocTempDir "$packageName"

	if ($env:packageVersion -ne $null) {$tempDir = Join-Path $tempDir "$env:packageVersion"; }

	$file = Join-Path $tempDir "$($packageName)Install.$fileType"

	$packagelibPath=$env:chocolateyPackageFolder
    if (!(Test-Path -path $packagelibPath)) {
      New-Item $packagelibPath -type directory
    }

    $zipFilename=split-path $file -Leaf
    $zipExtractLogFullPath=join-path $packagelibPath $zipFilename`.txt

    #$scriptBlock = [scriptblock]::create("GetFiles $finalLocation")
    #Write-FileUpdateLog $zipExtractLogFullPath $path $scriptBlock

    if (Test-Path -path $zipExtractLogFullPath) {
      Remove-Item $zipExtractLogFullPath -Force
    }
    GetFiles $Path | Add-Content $zipExtractLogFullPath
}

