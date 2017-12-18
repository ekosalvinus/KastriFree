unit DW.NFC.iOS;

{*******************************************************}
{                                                       }
{                    Kastri Free                        }
{                                                       }
{          DelphiWorlds Cross-Platform Library          }
{                                                       }
{*******************************************************}

{$I DW.GlobalDefines.inc}

// ****** NOTE: This is a work in progress, so don't expect miracles :-) *****

interface

uses
  // Mac
  Macapi.ObjectiveC,
  // iOS
  iOSapi.Foundation,
  // DW
  DW.iOSapi.CoreNFC, DW.NFC;

type
  TPlatformNFCReader = class;

  TNFCNDEFReaderSessionDelegate = class(TOCLocal, NFCNDEFReaderSessionDelegate)
  private
    FPlatformNFCReader: TPlatformNFCReader;
  public
    constructor Create(const APlatformNFCReader: TPlatformNFCReader);
    [MethodName('readerSession:didInvalidateWithError:')]
    procedure readerSessionDidInvalidateWithError(session: NFCNDEFReaderSession; didInvalidateWithError: NSError); cdecl;
    [MethodName('readerSession:didDetectNDEFs:')]
    procedure readerSessionDidDetectNDEFs(session: NFCNDEFReaderSession; didDetectNDEFs: NSArray); cdecl;
  end;

  TPlatformNFCReader = class(TCustomPlatformNFCReader)
  private
    FDelegate: TNFCNDEFReaderSessionDelegate;
    FReaderSession: NFCNDEFReaderSession;
  protected
    procedure BeginSession; override;
    procedure EndSession; override;
    procedure readerSessionDidInvalidateWithError(session: NFCNDEFReaderSession; didInvalidateWithError: NSError);
    procedure readerSessionDidDetectNDEFs(session: NFCNDEFReaderSession; didDetectNDEFs: NSArray);
  public
    class function IsSupported: Boolean; override;
  public
    constructor Create(const ANFCReader: TNFCReader); override;
  end;

implementation

uses
  // RTL
  System.Classes, System.SysUtils,
  // Mac
  Macapi.Helpers;

function NSDataToString(const AData: NSData): string;
begin
  Result := NSStrToStr(TNSString.Wrap(TNSString.Alloc.initWithData(AData, NSUTF8StringEncoding)));
end;

{ TNFCNDEFReaderSessionDelegate }

constructor TNFCNDEFReaderSessionDelegate.Create(const APlatformNFCReader: TPlatformNFCReader);
begin
  inherited Create;
  FPlatformNFCReader := APlatformNFCReader;
end;

procedure TNFCNDEFReaderSessionDelegate.readerSessionDidDetectNDEFs(session: NFCNDEFReaderSession; didDetectNDEFs: NSArray);
begin
  FPlatformNFCReader.readerSessionDidDetectNDEFs(session, didDetectNDEFs);
end;

procedure TNFCNDEFReaderSessionDelegate.readerSessionDidInvalidateWithError(session: NFCNDEFReaderSession; didInvalidateWithError: NSError);
begin
  FPlatformNFCReader.readerSessionDidInvalidateWithError(session, didInvalidateWithError);
end;

{ TPlatformNFCReader }

constructor TPlatformNFCReader.Create(const ANFCReader: TNFCReader);
begin
  inherited;
  FDelegate := TNFCNDEFReaderSessionDelegate.Create(Self);
end;

procedure TPlatformNFCReader.BeginSession;
begin
  FReaderSession := TNFCNDEFReaderSession.Wrap(TNFCNDEFReaderSession.Alloc.initWithDelegate(FDelegate.GetObjectID, 0, False));
  FReaderSession.setAlertMessage(StrToNSStr(NFCReader.AlertMessage));
  FReaderSession.beginSession;
  IsActive := True;
end;

procedure TPlatformNFCReader.EndSession;
begin
  FReaderSession.invalidateSession;
  FReaderSession := nil;
  IsActive := False;
end;

class function TPlatformNFCReader.IsSupported: Boolean;
begin
  Result := TOSVersion.Check(11);
end;

procedure TPlatformNFCReader.readerSessionDidDetectNDEFs(session: NFCNDEFReaderSession; didDetectNDEFs: NSArray);
var
  LMessage: NFCNDEFMessage;
  LPayload: NFCNDEFPayload;
  LNFCMessages: TNFCMessages;
  LNFCPayload: TNFCPayload;
  I, J: Integer;
begin
  SetLength(LNFCMessages, didDetectNDEFs.count);
  for I := 0 to didDetectNDEFs.count - 1 do
  begin
    LMessage := TNFCNDEFMessage.Wrap(didDetectNDEFs.objectAtIndex(I));
    SetLength(LNFCMessages[I].Payloads, LMessage.records.count);
    for J := 0 to LMessage.records.count - 1 do
    begin
      LPayload := TNFCNDEFPayload.Wrap(LMessage.records.objectAtIndex(J));
      LNFCPayload := LNFCMessages[I].Payloads[J];
      LNFCPayload.Identifier := NSDataToString(LPayload.identifier);
      LNFCPayload.Payload := NSDataToString(LPayload.payload);
      LNFCPayload.PayloadType := NSDataToString(LPayload.&type);
      LNFCPayload.TypeNameFormat := TNFCPayloadTypeNameFormat(LPayload.typeNameFormat);
      LNFCMessages[I].Payloads[J] := LNFCPayload;
    end;
  end;
  if Length(LNFCMessages) > 0 then
  begin
    //!!!! TODO - check if Synchronize is needed
    TThread.Synchronize(nil,
      procedure
      begin
        DoDetectedNDEFs(LNFCMessages);
      end
    );
  end;
end;

procedure TPlatformNFCReader.readerSessionDidInvalidateWithError(session: NFCNDEFReaderSession; didInvalidateWithError: NSError);
begin
  IsActive := False;
  //!!!! TODO - check if Synchronize is needed
  TThread.Synchronize(nil,
    procedure
    begin
      DoError(NSStrToStr(didInvalidateWithError.localizedDescription));
    end
  );
  EndSession;
end;

end.
