unit SYNC_Lyrics_DisplayDecorationControls;

// Shares safe drag ranges and sensitivity for display decoration handles.

interface

type
  TDisplayDecorationDragKind = (ddkOutlineWidth, ddkOutlineBlur,
    ddkShadowOffset, ddkShadowBlur, ddkShadowSpread);

// Maps movement in preview pixels to a bounded decoration value.
function DisplayDecorationDragValue(StartValue: Single;
  DeltaPixels: Integer; PreviewScale: Double;
  Kind: TDisplayDecorationDragKind): Single;

implementation

uses
  System.Math,
  SYNC_Lyrics_DisplaySettingsData;

function DisplayDecorationDragValue(StartValue: Single;
  DeltaPixels: Integer; PreviewScale: Double;
  Kind: TDisplayDecorationDragKind): Single;
var
  Direction: Double;
  Gain: Double;
  Maximum: Double;
  Minimum: Double;
begin
  Direction := 1;
  Minimum := 0;
  case Kind of
    ddkOutlineWidth:
      begin Gain := 0.10; Maximum := MAX_DISPLAY_OUTLINE_WIDTH; end;
    ddkOutlineBlur:
      begin Gain := 0.15; Maximum := MAX_DISPLAY_DECORATION_BLUR;
        Direction := -1; end;
    ddkShadowOffset:
      begin Gain := 0.35; Minimum := -MAX_DISPLAY_SHADOW_OFFSET;
        Maximum := MAX_DISPLAY_SHADOW_OFFSET; end;
    ddkShadowBlur:
      begin Gain := 0.15; Maximum := MAX_DISPLAY_DECORATION_BLUR;
        Direction := -1; end;
    ddkShadowSpread:
      begin Gain := 0.10; Maximum := MAX_DISPLAY_SHADOW_SPREAD; end;
  else
    Exit(StartValue);
  end;
  Result := EnsureRange(StartValue + Direction * DeltaPixels * Gain /
    Max(1.0, PreviewScale), Minimum, Maximum);
end;

end.
