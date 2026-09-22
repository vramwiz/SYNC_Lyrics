program SYNC_Lyrics_SkiaDeferredRendererTests;

// Exercises text rendering with the plugin's deferred System.Skia build.

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Skia in 'Win64\SkiaOverride\System.Skia.pas',
  TextRendererTypes in 'Source\Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Source\Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Source\Lib\TextRenderer\TextRendererSkia.pas';

var
  Image: TTextRenderImage;
  Metrics: TTextRenderMetrics;
  Renderer: TSkiaTextRenderer;
  Request: TTextRenderRequest;
begin
  TTextRendererSkiaRuntime.Acquire(
    ExtractFilePath(ParamStr(0)) + 'sk4d.dll');
  try
    Renderer := TSkiaTextRenderer.Create;
    try
      Request := TTextRenderRequest.Default;
      Request.Text := 'Skia';
      Request.FontFamilies := ['Arial'];
      Request.FontSize := 32;
      Request.CaptureTextUnits := True;
      Image := Renderer.Render(Request, Metrics);
      try
        if (Image = nil) or (Image.PixelCount = 0) or
          (Length(Image.TextUnitImages) <> Length(Request.Text)) then
          raise Exception.Create('Deferred Skia did not render text units');
      finally
        Image.Free;
      end;
    finally
      Renderer.Free;
    end;
  finally
    TTextRendererSkiaRuntime.Release;
  end;
  Writeln('SKIA_DEFERRED_RENDER_OK');
end.
