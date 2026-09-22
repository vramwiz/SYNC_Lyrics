program SYNC_Lyrics_SkiaInitializationTests;

// Verifies that loading the plugin does not load Skia under the loader lock.

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows;

type
  TInitializePlugin = function(Version: Cardinal): Byte; cdecl;
  TUninitializePlugin = procedure; cdecl;

var
  ExpectFailure: Boolean;
  InitializePlugin: TInitializePlugin;
  PluginHandle: HMODULE;
  UninitializePlugin: TUninitializePlugin;
begin
  if (ParamCount < 1) or (ParamCount > 2) then
    raise Exception.Create('Expected plugin path and optional expect-failure');
  ExpectFailure := (ParamCount = 2) and
    SameText(ParamStr(2), 'expect-failure');
  if GetModuleHandle('sk4d.dll') <> 0 then
    raise Exception.Create('Skia was loaded before the test');
  Writeln('Loading plugin');
  Flush(Output);
  PluginHandle := LoadLibrary(PChar(ParamStr(1)));
  if PluginHandle = 0 then
    RaiseLastOSError;
  try
    Writeln('Plugin loaded');
    Flush(Output);
    if GetModuleHandle('sk4d.dll') <> 0 then
      raise Exception.Create('Skia loaded during plugin LoadLibrary');
    InitializePlugin := TInitializePlugin(GetProcAddress(
      PluginHandle, 'InitializePlugin'));
    UninitializePlugin := TUninitializePlugin(GetProcAddress(
      PluginHandle, 'UninitializePlugin'));
    if not Assigned(InitializePlugin) or not Assigned(UninitializePlugin) then
      raise Exception.Create('Plugin lifecycle exports are missing');
    Writeln('Initializing plugin');
    Flush(Output);
    if ExpectFailure then
    begin
      if InitializePlugin(0) <> 0 then
        raise Exception.Create('Missing Skia runtime did not fail cleanly');
    end
    else
    begin
      if InitializePlugin(0) <> 1 then
        raise Exception.Create('Plugin initialization failed');
      try
        Writeln('Plugin initialized');
        Flush(Output);
        if GetModuleHandle('sk4d.dll') = 0 then
          raise Exception.Create('Skia was not loaded by InitializePlugin');
      finally
        Writeln('Uninitializing plugin');
        Flush(Output);
        UninitializePlugin;
      end;
    end;
  finally
    Writeln('Unloading plugin');
    Flush(Output);
    FreeLibrary(PluginHandle);
  end;
  Writeln('SKIA_INITIALIZATION_OK');
end.
