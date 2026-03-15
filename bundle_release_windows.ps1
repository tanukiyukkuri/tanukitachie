param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

function From-CodePoints {
    param(
        [int[]]$CodePoints
    )

    return (-join ($CodePoints | ForEach-Object { [char]$_ }))
}

$nameBuild = From-CodePoints @(12383, 12396, 12365, 24335, 12422, 12387, 12367, 12426)
$nameReimu = From-CodePoints @(12383, 12396, 12365, 38666, 22818)
$nameMarisa = From-CodePoints @(12383, 12396, 12365, 39764, 29702, 27801)
$nameSampleNfc = From-CodePoints @(12383, 12396, 12365, 12469, 12531, 12503, 12523)
$nameSampleNfd = "たぬきサンフ" + [char]0x309A + "ル"
$nameReadme = "README.txt"
$nameTerms = "TERMS.txt"
$archivePrefix = $nameBuild + "_ver"
$latestZipName = "tanuki-yukkuri.zip"

$rootDir = $PSScriptRoot
$buildDir = Join-Path $rootDir $nameBuild
$downloadsDir = Join-Path $rootDir "downloads"
$errorLog = Join-Path $rootDir "bundle_release_error.log"

if (Test-Path -LiteralPath $errorLog) {
    Remove-Item -LiteralPath $errorLog -Force
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-Date -Format "yyyyMMdd"
}

$archiveBaseName = $archivePrefix + $Version
$versionedZip = Join-Path $downloadsDir ($archiveBaseName + ".zip")
$latestZip = Join-Path $downloadsDir $latestZipName

function Resolve-SourceDir {
    param(
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $path = Join-Path $rootDir $candidate
        if (Test-Path -LiteralPath $path -PathType Container) {
            return $path
        }
    }

    throw "Source directory not found: $($Candidates -join ', ')"
}

function Show-Step {
    param(
        [string]$Message
    )

    Write-Host ("[bundle_release] " + $Message)
}

function Reset-Directory {
    param(
        [string]$Path
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $items = Get-ChildItem -LiteralPath $Path -Force

    $items |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (Test-Path -LiteralPath $_.FullName) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
            }
        }
}

function Copy-DirectoryContent {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
}

function Remove-JunkFiles {
    param(
        [string]$TargetDir
    )

    $junkItems = @()
    $junkItems += Get-ChildItem -LiteralPath $TargetDir -Force | Where-Object {
        $_.Name -eq ".DS_Store" -or
        $_.Name -like "._*" -or
        $_.Name -eq "__MACOSX"
    }
    $junkItems += Get-ChildItem -LiteralPath $TargetDir -Recurse -Force | Where-Object {
        $_.Name -eq ".DS_Store" -or
        $_.Name -like "._*" -or
        $_.Name -eq "__MACOSX"
    }

    $junkItems |
        Sort-Object -Property FullName -Unique |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (Test-Path -LiteralPath $_.FullName) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
            }
        }
}

function Test-IsJunkPath {
    param(
        [string]$PathValue
    )

    $parts = $PathValue -split '[\\/]'
    foreach ($part in $parts) {
        if ($part -eq ".DS_Store" -or $part -like "._*" -or $part -eq "__MACOSX") {
            return $true
        }
    }

    return $false
}

function Create-ZipFromDirectory {
    param(
        [string]$SourceDir,
        [string]$ZipPath
    )

    Add-Type -AssemblyName "System.IO.Compression"
    Add-Type -AssemblyName "System.IO.Compression.FileSystem"

    $sourceItem = Get-Item -LiteralPath $SourceDir
    $rootName = $sourceItem.Name
    $zipFileStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)

    try {
        $archive = New-Object System.IO.Compression.ZipArchive($zipFileStream, [System.IO.Compression.ZipArchiveMode]::Create)

        try {
            $archive.CreateEntry(($rootName + "/")) | Out-Null

            foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Recurse -Force) {
                $relativePath = $item.FullName.Substring($SourceDir.Length).TrimStart('\')
                if ([string]::IsNullOrWhiteSpace($relativePath)) {
                    continue
                }

                if (Test-IsJunkPath -PathValue $relativePath) {
                    continue
                }

                $entryPath = ($rootName + "/" + ($relativePath -replace '\\', '/'))

                if ($item.PSIsContainer) {
                    $archive.CreateEntry(($entryPath.TrimEnd('/') + "/")) | Out-Null
                }
                else {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $archive,
                        $item.FullName,
                        $entryPath,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    ) | Out-Null
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $zipFileStream.Dispose()
    }
}

try {
    Show-Step "source folders detected"
    $reimuSource = Resolve-SourceDir -Candidates @($nameReimu)
    $marisaSource = Resolve-SourceDir -Candidates @($nameMarisa)
    $sampleSource = Resolve-SourceDir -Candidates @($nameSampleNfc, $nameSampleNfd)

    Show-Step "preparing build directory"
    New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
    Reset-Directory -Path $buildDir

    Show-Step "copying reimu"
    Copy-DirectoryContent -Source $reimuSource -Destination (Join-Path $buildDir $nameReimu)
    Show-Step "copying marisa"
    Copy-DirectoryContent -Source $marisaSource -Destination (Join-Path $buildDir $nameMarisa)
    Show-Step "copying sample"
    Copy-DirectoryContent -Source $sampleSource -Destination (Join-Path $buildDir $nameSampleNfc)
    Show-Step "copying text files"
    Copy-Item -LiteralPath (Join-Path $rootDir $nameTerms) -Destination (Join-Path $buildDir $nameTerms) -Force
    Copy-Item -LiteralPath (Join-Path $rootDir $nameReadme) -Destination (Join-Path $buildDir $nameReadme) -Force

    Show-Step "removing macOS junk files"
    Remove-JunkFiles -TargetDir $buildDir

    if (Test-Path -LiteralPath $versionedZip) {
        Show-Step "removing old versioned zip"
        Remove-Item -LiteralPath $versionedZip -Force
    }

    if (Test-Path -LiteralPath $latestZip) {
        Show-Step "removing old latest zip"
        Remove-Item -LiteralPath $latestZip -Force
    }

    Show-Step "creating zip archive"
    Create-ZipFromDirectory -SourceDir $buildDir -ZipPath $versionedZip

    Show-Step "updating latest zip"
    Copy-Item -LiteralPath $versionedZip -Destination $latestZip -Force

    Write-Host ("Built: " + $versionedZip)
    Write-Host ("Updated: " + $latestZip)
}
catch {
    $_ | Out-File -LiteralPath $errorLog -Encoding utf8
    $_.ScriptStackTrace | Out-File -LiteralPath $errorLog -Encoding utf8 -Append
    Write-Error ("bundle_release_windows.ps1 failed. See " + $errorLog)
    exit 1
}
