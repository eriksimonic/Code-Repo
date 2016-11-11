unit PICCProg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  ACR122s, Dialogs, StdCtrls, ComCtrls;

type
  TMainPICCProg = class(TForm)
    mMsg: TRichEdit;
    bConnect: TButton;
    gbSendApdu: TGroupBox;
    Label7: TLabel;
    bSend: TButton;
    tData: TMemo;
    bClear: TButton;
    bReset: TButton;
    bQuit: TButton;
    Label1: TLabel;
    cbReader: TComboBox;
    procedure FormActivate(Sender: TObject);
    procedure bConnectClick(Sender: TObject);
    procedure bQuitClick(Sender: TObject);
    procedure bResetClick(Sender: TObject);
    procedure bSendClick(Sender: TObject);
    procedure bClearClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MainPICCProg: TMainPICCProg;
  connActive :BOOL;
  PrintText : String;
  hReader : SCARDHANDLE;
  SendBuff : array [0..256] of Byte;
  RecvBuff : array [0..256] of Byte;
  retCode  : DWORD;
  SendLen : smallint;
  RecvLen : DWORD;

procedure InitMenu();
procedure ClearBuffers();
procedure displayOut(errType: Integer; retVal: Integer; PrintText: String);
function TrimInput(TrimType: integer; StrIn: string): string;
function SendAPDUandDisplay(): Integer;
implementation

{$R *.dfm}

procedure TMainPICCProg.bClearClick(Sender: TObject);
begin
  mMsg.Clear;
end;

procedure TMainPICCProg.bConnectClick(Sender: TObject);
var
FWLEN : DWORD;
tempstr : array [0..256] of char;
begin

    PrintText := MainPICCProg.cbReader.Text;

    retCode := ACR122_OpenA( PrintText, @hReader);
    if retCode = 0  then
    begin
      ConnActive := True;
      MainPICCProg.bConnect.Enabled := False;
      MainPICCProg.bSend.Enabled := True;
      MainPICCProg.bReset.Enabled := True;
      PrintText := 'Connection to ' + PrintText + ' success';
      displayOut( 0, 0, PrintText);

      PrintText := '';
      
      retCode := ACR122_GetFirmwareVersionA(hReader, 0, tempstr, @FWLEN);
      if retCode = 0 then
      begin
        PrintText := 'Firmware Version: ' + tempstr;
        displayOut(5, 0, PrintText);
      end
      else
      begin
        displayOut( 1, 0, 'Get Firmware Version failed');
      end;

    end
    else
    begin
      PrintText := 'Connection to ' + PrintText + ' failed';
      displayOut( 1, 0, PrintText);
    end;
end;

procedure TMainPICCProg.bQuitClick(Sender: TObject);
begin
  if ConnActive = true then
     begin
        retCode := ACR122_Close(hReader);
     end;

  Application.Terminate;
end;

procedure TMainPICCProg.bResetClick(Sender: TObject);
begin
     if ConnActive = true then
     begin
        retCode := ACR122_Close(hReader);
        if retCode = 0 then
        begin
             InitMenu();
        end;

     end;
end;

procedure TMainPICCProg.bSendClick(Sender: TObject);
var tmpData: string;
    directCmd: Boolean;
    indx: integer;

begin

  tmpData := '';
  SendLen := 0;

  ClearBuffers();

  tmpData := TrimInput(0, tData.Text);
  tmpData := TrimInput(1, tmpData);
    
    if(Length(tmpData) > 0 ) then
    begin

          for indx :=0 to Length(tmpData) div 2 - 1 do
          begin
              SendBuff[indx] := StrToInt('$' + copy(tmpData,(indx*2+1),2)); // Format Data In
              SendLen := SendLen + 1;
          end;
    end
    else begin
        Exit;
    end;


  RecvLen := $FF;
  SendAPDUandDisplay();

end;

procedure TMainPICCProg.FormActivate(Sender: TObject);
begin
   InitMenu();
end;

procedure TMainPICCProg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if ConnActive = true then
     begin
        retCode := ACR122_Close(hReader);
     end;

  Application.Terminate;
end;

procedure InitMenu();
var
indx : Integer;
begin

  connActive := False;

  MainPICCProg.mMsg.Clear;

  DisplayOut(0, 0, 'Program ready');

  MainPICCProg.cbReader.Clear;

  for indx := 1 to 10 do
  begin
    PrintText := 'COM' + IntToStr(indx);
    MainPICCProg.cbReader.AddItem( PrintText, TObject.NewInstance);
  end;
    
  MainPICCProg.cbReader.ItemIndex := 0;
  MainPICCProg.tData.Text := '';

  MainPICCProg.bConnect.Enabled := True;
  MainPICCProg.bSend.Enabled := False;
  MainPICCProg.bReset.Enabled := False;


end;

procedure displayOut(errType: Integer; retVal: Integer; PrintText: String);
begin

  case errType of
    0: MainPICCProg.mMsg.SelAttributes.Color := clTeal;      // Notifications
    1: begin                                                // Error Messages
         MainPICCProg.mMsg.SelAttributes.Color := clRed;
         //PrintText := GetScardErrMsg(retVal);
       end;
    2: begin
         MainPICCProg.mMsg.SelAttributes.Color := clBlack;
         PrintText := '< ' + PrintText;                      // Input data
       end;
    3: begin
         MainPICCProg.mMsg.SelAttributes.Color := clBlack;
         PrintText := '> ' + PrintText;                      // Output data
       end;
    4: MainPICCProg.mMsg.SelAttributes.Color := clRed;        // For ACOS1 error
    5: MainPICCProg.mMsg.SelAttributes.Color := clBlack;      // Normal Notification
  end;
  MainPICCProg.mMsg.Lines.Add(PrintText);
  MainPICCProg.mMsg.SelAttributes.Color := clBlack;
  MainPICCProg.mMsg.SetFocus;

end;

function TrimInput(TrimType: integer; StrIn: string): string;
var indx: integer;
    tmpStr: String;
begin
  tmpStr := '';
  StrIn := Trim(StrIn);
  case TrimType of
    0: begin
       for indx := 1 to length(StrIn) do
         if ((StrIn[indx] <> chr(13)) and (StrIn[indx] <> chr(10))) then
           tmpStr := tmpStr + StrIn[indx];
       end;
    1: begin
       for indx := 1 to length(StrIn) do
         if StrIn[indx] <> ' ' then
           tmpStr := tmpStr + StrIn[indx];
       end;
  end;
  TrimInput := tmpStr;
end;

procedure ClearBuffers();
var indx: integer;
begin

  for indx := 0 to 262 do
    begin
      SendBuff[indx] := $00;
      RecvBuff[indx] := $00;
    end;

end;

function SendAPDUandDisplay(): integer;
var tmpStr: string;
    indx: integer;
begin

    PrintText := '';

    displayOut(0,0,'Command:');
    for indx := 0 to SendLen - 1 do
          begin
            PrintText := PrintText + Format('%.02X ', [SendBuff[indx]]);
          end;
    displayOut(3,0, PrintText);


    PrintText := '';
    RecvLen := 255;
    //displayOut(0,0, IntToStr(hReader));
    retCode := ACR122_DirectTransmit(hReader, @SendBuff, SendLen, @RecvBuff, @RecvLen);

    if retCode = 0 then
    begin
       displayOut(0,0,'Response:');
       for indx := 0 to RecvLen - 1 do
          begin
            PrintText := PrintText + Format('%.02X ', [RecvBuff[indx]]);
          end;
       displayOut(2,0, PrintText);
    end
    else
    begin
      displayOut( 1, 0, 'Send Command Failed');
    end;

  SendAPDUandDisplay := retCode;

end;

end.
