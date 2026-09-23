$ErrorActionPreference = 'Stop'

$packageName = 'SYNC_Lyrics'
$projectDir = Split-Path -Parent $PSScriptRoot
$pluginDir = 'C:\ProgramData\aviutl2\Plugin\SYNC_Lyrics'
$ffmpegDir = Join-Path $projectDir 'ThirdParty\FFmpeg'
$stagingRoot = Join-Path $PSScriptRoot ('.release-' + [guid]::NewGuid().ToString('N'))
$workDir = Join-Path $stagingRoot $packageName
$zipFile = Join-Path $PSScriptRoot "$packageName.zip"
$pendingZip = Join-Path $PSScriptRoot ('.release-' + [guid]::NewGuid().ToString('N') + '.zip')

$packageFiles = @(
  @{ Source = Join-Path $pluginDir 'SYNC_Lyrics_Filter.auf2'; Destination = 'SYNC_Lyrics_Filter.auf2' },
  @{ Source = Join-Path $pluginDir 'sk4d.dll'; Destination = 'sk4d.dll' },
  @{ Source = Join-Path $projectDir 'LICENSE'; Destination = 'LICENSE' },
  @{ Source = Join-Path $projectDir 'THIRD_PARTY_NOTICES.md'; Destination = 'THIRD_PARTY_NOTICES.md' },
  @{ Source = Join-Path $ffmpegDir 'LICENSE'; Destination = 'ThirdParty\FFmpeg\LICENSE' },
  @{ Source = Join-Path $ffmpegDir 'README.txt'; Destination = 'ThirdParty\FFmpeg\README.txt' },
  @{ Source = Join-Path $projectDir 'Samples\README.md'; Destination = 'Samples\README.md' },
  @{ Source = Join-Path $projectDir 'Samples\SYNC_Lyrics_sample.mid'; Destination = 'Samples\SYNC_Lyrics_sample.mid' },
  @{ Source = Join-Path $projectDir 'Samples\SYNC_Lyrics_sample_lyrics.txt'; Destination = 'Samples\SYNC_Lyrics_sample_lyrics.txt' }
)

foreach ($name in @('avutil-60.dll', 'swresample-6.dll', 'swscale-9.dll',
    'avcodec-62.dll', 'avformat-62.dll', 'avfilter-11.dll')) {
  $packageFiles += @{
    Source = Join-Path (Join-Path $ffmpegDir 'bin') $name
    Destination = $name
  }
}

foreach ($item in $packageFiles) {
  if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) {
    throw "Required release file not found: $($item.Source)"
  }
}

$filterPlugin = Join-Path $pluginDir 'SYNC_Lyrics_Filter.auf2'
$unfinishedBuild = Join-Path $pluginDir 'SYNC_Lyrics_Filter.dll'
if ((Test-Path -LiteralPath $unfinishedBuild -PathType Leaf) -and
    ((Get-Item -LiteralPath $unfinishedBuild).LastWriteTimeUtc -gt
     (Get-Item -LiteralPath $filterPlugin).LastWriteTimeUtc)) {
  throw 'The Release DLL is newer than the deployed .auf2. Close AviUtl2 and finish the Release build before packaging.'
}

try {
  New-Item -ItemType Directory -Path $workDir | Out-Null
  foreach ($item in $packageFiles) {
    $destination = Join-Path $workDir $item.Destination
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $item.Source -Destination $destination
  }

  Compress-Archive -LiteralPath $workDir -DestinationPath $pendingZip -CompressionLevel Optimal
  if (Test-Path -LiteralPath $zipFile) {
    Remove-Item -LiteralPath $zipFile -Force
  }
  Move-Item -LiteralPath $pendingZip -Destination $zipFile
}
finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
  }
  if (Test-Path -LiteralPath $pendingZip) {
    Remove-Item -LiteralPath $pendingZip -Force
  }
}

Write-Host "Created: $zipFile"
