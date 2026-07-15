param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $true)]
    [string]$RootName
)

$ErrorActionPreference = "Stop"
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("bflyvpn-portable-" + [guid]::NewGuid().ToString("N"))
$bundleRoot = Join-Path $tempRoot $RootName

try {
    New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $bundleRoot -Force
    Remove-Item -LiteralPath $archive -Force
    Compress-Archive -Path $bundleRoot -DestinationPath $archive -CompressionLevel Optimal
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
