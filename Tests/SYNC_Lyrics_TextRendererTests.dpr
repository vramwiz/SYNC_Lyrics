program SYNC_Lyrics_TextRendererTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  TextRendererSkiaBootstrap in 'Source\Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererTypes in 'Source\Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Source\Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Source\Lib\TextRenderer\TextRendererSkia.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function RenderText(Renderer: TSkiaTextRenderer;
  const Style: TTextRenderFontStyle; LetterSpacing: Single;
  out Metrics: TTextRenderMetrics): TTextRenderImage;
var
  Request: TTextRenderRequest;
begin
  Request := TTextRenderRequest.Default;
  Request.Text := 'AB';
  Request.FontFamilies := ['Yu Gothic UI'];
  Request.FontSize := 72;
  Request.FontStyle := Style;
  Request.LetterSpacing := LetterSpacing;
  Request.CaptureTextUnits := True;
  Request.FillColor := TAlphaColorRec.White;
  Result := Renderer.Render(Request, Metrics);
end;

procedure RunTests;
var
  DecoratedImage: TTextRenderImage;
  DecoratedMetrics: TTextRenderMetrics;
  NegativeSpacingImage: TTextRenderImage;
  NegativeSpacingMetrics: TTextRenderMetrics;
  PlainImage: TTextRenderImage;
  PlainMetrics: TTextRenderMetrics;
  PositiveSpacingImage: TTextRenderImage;
  PositiveSpacingMetrics: TTextRenderMetrics;
  Renderer: TSkiaTextRenderer;
begin
  Renderer := TSkiaTextRenderer.Create;
  try
    PlainImage := RenderText(Renderer, [], 0, PlainMetrics);
    try
      Check(not PlainImage.IsEmpty, 'Plain image is empty');
      Check(PlainMetrics.NonTransparentPixelCount > 0,
        'Plain image has no visible pixels');
      Check(Length(PlainImage.TextUnitBounds) = 2,
        'Unexpected plain text-unit count');
      Check(Length(PlainImage.TextUnitOrigins) = 2,
        'Text-unit origins were not captured');
      Check(Length(PlainImage.TextUnitAdvances) = 2,
        'Text-unit advances were not captured');
      Check(Length(PlainImage.TextUnitImages) = 2,
        'Text-unit images were not captured');
      Check(PlainImage.TextUnitOrigins[1].X >
        PlainImage.TextUnitOrigins[0].X,
        'Text-unit origins are not ordered');
      Check((PlainImage.TextUnitAdvances[0] > 0) and
        (PlainImage.TextUnitAdvances[1] > 0),
        'Text-unit advances must be positive');
      Check((PlainImage.TextUnitImages[0] <> nil) and
        (PlainImage.TextUnitImages[1] <> nil),
        'Text-unit image is missing');

      DecoratedImage := RenderText(Renderer,
        [TTextRenderFontStyleItem.Underline,
         TTextRenderFontStyleItem.StrikeOut], 0, DecoratedMetrics);
      try
        Check(DecoratedMetrics.NonTransparentPixelCount >
          PlainMetrics.NonTransparentPixelCount,
          'Decorations did not add visible pixels');
        Check((DecoratedImage.LayoutBounds.Height >=
          PlainImage.LayoutBounds.Height) and
          (Length(DecoratedImage.TextUnitBounds) = 2),
          'Decorated layout or text-unit capture is invalid');
      finally
        DecoratedImage.Free;
      end;

      PositiveSpacingImage := RenderText(Renderer, [], 12,
        PositiveSpacingMetrics);
      try
        NegativeSpacingImage := RenderText(Renderer, [], -4,
          NegativeSpacingMetrics);
        try
          Check((PositiveSpacingImage.TextUnitOrigins[1].X -
            PositiveSpacingImage.TextUnitOrigins[0].X) >
            (NegativeSpacingImage.TextUnitOrigins[1].X -
            NegativeSpacingImage.TextUnitOrigins[0].X),
            'Positive and negative letter spacing were not reflected');
        finally
          NegativeSpacingImage.Free;
        end;
      finally
        PositiveSpacingImage.Free;
      end;
    finally
      PlainImage.Free;
    end;
  finally
    Renderer.Free;
  end;
end;

var
  RuntimeFileName: string;

begin
  RuntimeFileName := ExtractFilePath(ParamStr(0)) + 'sk4d.dll';
  TTextRendererSkiaRuntime.Acquire(RuntimeFileName);
  try
    RunTests;
    Writeln('PASS');
  finally
    TTextRendererSkiaRuntime.Release;
  end;
end.
