unit SYNC_Lyrics_ListBoxEdit;

// List box with a single-line editor placed directly over the selected row.
// Adapted for this project from Syncroh2's ListBoxEdit without external units.

interface

uses
  System.Classes,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TSyncLyricsGetEditTextEvent = procedure(Sender: TObject; Index: Integer;
    var Text: string) of object;
  TSyncLyricsApplyListEditEvent = procedure(Sender: TObject; Index: Integer;
    const NewText: string; var Accept: Boolean) of object;
  TSyncLyricsCancelListEditEvent = procedure(Sender: TObject;
    Index: Integer) of object;

  TSyncLyricsListBoxEdit = class(TListBox)
  private
    FEdit: TEdit;
    FEndingEdit: Boolean;
    FEditingIndex: Integer;
    FIsEditing: Boolean;
    FOnApplyEdit: TSyncLyricsApplyListEditEvent;
    FOnCancelEdit: TSyncLyricsCancelListEditEvent;
    FOnGetEditText: TSyncLyricsGetEditTextEvent;
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginEdit(Index: Integer);
    procedure EndEdit(ApplyChanges: Boolean);
    function IsEditing: Boolean;
    property EditControl: TEdit read FEdit;
    property EditingIndex: Integer read FEditingIndex;
    property OnApplyEdit: TSyncLyricsApplyListEditEvent read FOnApplyEdit
      write FOnApplyEdit;
    property OnCancelEdit: TSyncLyricsCancelListEditEvent read FOnCancelEdit
      write FOnCancelEdit;
    property OnGetEditText: TSyncLyricsGetEditTextEvent read FOnGetEditText
      write FOnGetEditText;
  end;

implementation

constructor TSyncLyricsListBoxEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := lbOwnerDrawFixed;
  FEditingIndex := -1;
  FEndingEdit := False;
  FIsEditing := False;
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.AutoSize := False;
  FEdit.Visible := False;
  FEdit.OnExit := EditExit;
  FEdit.OnKeyDown := EditKeyDown;
end;

destructor TSyncLyricsListBoxEdit.Destroy;
begin
  FEdit.Free;
  inherited Destroy;
end;

procedure TSyncLyricsListBoxEdit.BeginEdit(Index: Integer);
var
  EditRect: TRect;
  EditText: string;
begin
  if (Index < 0) or (Index >= Items.Count) then
    Exit;
  if FIsEditing then
    EndEdit(True);
  ItemIndex := Index;
  EditText := Items[Index];
  if Assigned(FOnGetEditText) then
    FOnGetEditText(Self, Index, EditText);
  EditRect := ItemRect(Index);
  FEditingIndex := Index;
  FIsEditing := True;
  FEdit.Font.Assign(Font);
  FEdit.SetBounds(EditRect.Left, EditRect.Top,
    EditRect.Right - EditRect.Left, ItemHeight);
  FEdit.Text := EditText;
  FEdit.Visible := True;
  FEdit.SelectAll;
  FEdit.SetFocus;
end;

procedure TSyncLyricsListBoxEdit.EditExit(Sender: TObject);
begin
  EndEdit(True);
end;

procedure TSyncLyricsListBoxEdit.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    EndEdit(True);
  end
  else if Key = VK_ESCAPE then
  begin
    Key := 0;
    EndEdit(False);
  end;
end;

procedure TSyncLyricsListBoxEdit.EndEdit(ApplyChanges: Boolean);
var
  Accept: Boolean;
  EditIndex: Integer;
  NewText: string;
begin
  if not FIsEditing or FEndingEdit then
    Exit;
  FEndingEdit := True;
  EditIndex := FEditingIndex;
  NewText := FEdit.Text;
  try
    if ApplyChanges then
    begin
      Accept := True;
      if Assigned(FOnApplyEdit) then
        FOnApplyEdit(Self, EditIndex, NewText, Accept);
      if not Accept then
      begin
        FEdit.Visible := True;
        FEdit.SetFocus;
        Exit;
      end;
    end
    else if Assigned(FOnCancelEdit) then
      FOnCancelEdit(Self, EditIndex);
    FIsEditing := False;
    FEditingIndex := -1;
    FEdit.Visible := False;
  finally
    FEndingEdit := False;
  end;
  Invalidate;
end;

function TSyncLyricsListBoxEdit.IsEditing: Boolean;
begin
  Result := FIsEditing;
end;

end.
