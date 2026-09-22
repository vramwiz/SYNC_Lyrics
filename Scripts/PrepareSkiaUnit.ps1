param(
    [Parameter(Mandatory = $true)][string]$BdsRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot
)

# Delphi initializes Skia class constructors while attaching the plugin DLL.
# Convert them into explicit calls made by InitializePlugin after LoadLibrary.
$sourcePath = Join-Path $BdsRoot 'source\rtl\common\System.Skia.pas'
$targetDir = Join-Path $ProjectRoot 'Win64\SkiaOverride'
$targetPath = Join-Path $targetDir 'System.Skia.pas'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Skia source not found: $sourcePath"
}

$source = [System.IO.File]::ReadAllText($sourcePath)
$constructorCount = ([regex]::Matches($source, 'class constructor T\w+\.Create;')).Count
$declarationCount = ([regex]::Matches($source, '    class constructor Create;')).Count
if ($constructorCount -ne 8 -or $declarationCount -ne 8 -or
    -not $source.Contains('class destructor TSkObject.Destroy;')) {
    throw 'Skia initialization layout changed; review System.Skia.pas before building.'
}

$patched = $source.Replace('    class constructor Create;',
    "  public`r`n    class procedure DeferredInitialize;")
$patched = [regex]::Replace($patched, 'class constructor (T\w+)\.Create;',
    'class procedure $1.DeferredInitialize;')
$patched = $patched.Replace('    class destructor Destroy;',
    '    class procedure DeferredFinalize;')
$patched = $patched.Replace('class destructor TSkObject.Destroy;',
    'class procedure TSkObject.DeferredFinalize;')
if (-not $patched.Contains("`r`nimplementation`r`n")) {
    throw 'Skia implementation section not found.'
}
$patched = $patched.Replace("`r`nimplementation`r`n",
    "`r`nprocedure InitializeDeferredSkia;`r`nprocedure FinalizeDeferredSkia;`r`n`r`nimplementation`r`n")

$deferredMethods = @'
procedure InitializeDeferredSkia;
begin
  TSkObject.DeferredInitialize;
  TGrPersistentCacheBaseClass.DeferredInitialize;
  TGrShaderErrorHandlerBaseClass.DeferredInitialize;
  TSkTraceMemoryDumpBaseClass.DeferredInitialize;
  TSkParticleEffect.DeferredInitialize;
  TSkResourceProviderBaseClass.DeferredInitialize;
  TSkStreamAdapter.DeferredInitialize;
  TSkWStreamAdapter.DeferredInitialize;
end;

procedure FinalizeDeferredSkia;
begin
  TSkObject.DeferredFinalize;
end;

'@
$initialization = "`r`ninitialization`r`n"
if (-not $patched.Contains($initialization)) {
    throw 'Skia initialization section not found.'
}
$patched = $patched.Replace($initialization,
    "`r`n$deferredMethods$initialization")

[System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
[System.IO.File]::WriteAllText($targetPath, $patched,
    [System.Text.UTF8Encoding]::new($false))
