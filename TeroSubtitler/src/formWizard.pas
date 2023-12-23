{*
 *  URUWorks
 *
 *  The contents of this file are used with permission, subject to
 *  the Mozilla Public License Version 2.0 (the "License"); you may
 *  not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.mozilla.org/MPL/2.0.html
 *
 *  Software distributed under the License is distributed on an
 *  "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 *  implied. See the License for the specific language governing
 *  rights and limitations under the License.
 *
 *  Copyright (C) 2023 URUWorks, uruworks@gmail.com.
 *}

unit formWizard;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  UWLayout, LCLTranslator, procLocalize, UWSystem.Globalization;

type

  { TfrmWizard }

  TfrmWizard = class(TForm)
    btnDownloadFFMPEG: TButton;
    btnDownloadWhisper: TButton;
    btnDownloadFasterWhisper: TButton;
    btnDownloadYTDLP: TButton;
    btnNext: TButton;
    btnDownload: TButton;
    cboLanguage: TComboBox;
    imgLogo: TImage;
    lblFasterWhisper: TLabel;
    lblFasterWhisper_Hint: TLabel;
    lblFFMPEG_Hint: TLabel;
    lblLanguage: TLabel;
    lbllibMPV_Hint: TLabel;
    lblWhisper_Hint: TLabel;
    lblWhisperStatus: TLabel;
    lblWhisper: TLabel;
    lblFasterWhisperStatus: TLabel;
    lblYTDLP_Hint: TLabel;
    lblYTDLPStatus: TLabel;
    lblYTDLP: TLabel;
    lblLibMPVStatus: TLabel;
    lblFFMPEGStatus: TLabel;
    lblFFMPEG: TLabel;
    lblRequiredFiles: TLabel;
    lbllibMPV: TLabel;
    lblExperience: TLabel;
    lblWelcome: TLabel;
    lyoPage0: TUWLayout;
    lyoPage1: TUWLayout;
    procedure btnDownloadClick(Sender: TObject);
    procedure btnDownloadFFMPEGClick(Sender: TObject);
    procedure btnDownloadYTDLPClick(Sender: TObject);
    procedure btnDownloadWhisperClick(Sender: TObject);
    procedure btnDownloadFasterWhisperClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure cboLanguageChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FIndex: Integer;
    FLngList: TStrings;
    procedure SetPageStep(const AIndex: Integer);
  public
  end;

// -----------------------------------------------------------------------------

var
  frmWizard: TfrmWizard;

implementation

uses
  procTypes, procWorkspace, procConfig, procColorTheme, formDownload
  {$IFDEF DARWIN}, UWSystem.SysUtils{$ENDIF};

{$R *.lfm}

// -----------------------------------------------------------------------------

{ TfrmWizard }

// -----------------------------------------------------------------------------

procedure TfrmWizard.FormCreate(Sender: TObject);
begin
  FLngList := TStringList.Create;
  FIndex   := 0;

  btnDownloadYTDLP.Caption   := btnDownload.Caption;
  btnDownloadFFMPEG.Caption  := btnDownload.Caption;
  btnDownloadWhisper.Caption := btnDownload.Caption;

  {$IFDEF LINUX}
  btnDownload.Visible              := False;
  btnDownloadYTDLP.Visible         := False;
  btnDownloadFFMPEG.Visible        := False;
  btnDownloadWhisper.Visible       := False;
  btnDownloadFasterWhisper.Visible := False;
  {$ENDIF};

  // libMPV
  if FileExists(libMPVFileName) then
  begin
    btnDownload.Enabled := False;
    lblLibMPVStatus.Caption := lngSuccess;
  end
  else
  begin
    btnDownload.Enabled := True;
    lblLibMPVStatus.Caption := lngFailed;
  end;

  // yt-dlp
  if FileExists(YTDLPFileName) then
  begin
    btnDownloadYTDLP.Enabled := False;
    lblYTDLPStatus.Caption := lngSuccess;
  end
  else
  begin
    btnDownloadYTDLP.Enabled := True;
    lblYTDLPStatus.Caption := lngFailed;
  end;

  // ffmpeg
  if FileExists(ffmpegFileName) then
  begin
    btnDownloadFFMPEG.Enabled := False;
    lblFFMPEGStatus.Caption := lngSuccess;
  end
  else
  begin
    btnDownloadFFMPEG.Enabled := True;
    lblFFMPEGStatus.Caption := lngFailed;
  end;

  // whisper.cpp
  if FileExists(WhisperFileName) then
  begin
    btnDownloadWhisper.Enabled := False;
    lblWhisperStatus.Caption := lngSuccess;
  end
  else
  begin
    btnDownloadWhisper.Enabled := True;
    lblWhisperStatus.Caption := lngFailed;
  end;

  // faster-whisper
  if FileExists(Tools.FasterWhisper) then
  begin
    btnDownloadFasterWhisper.Enabled := False;
    lblFasterWhisperStatus.Caption := lngSuccess;
  end
  else
  begin
    btnDownloadFasterWhisper.Enabled := True;
    lblFasterWhisperStatus.Caption := lngFailed;
  end;

  lblLanguage.Visible := False;
  cboLanguage.Visible := False;

  AppOptions.GUILanguage := LanguageIDFromFileName(LanguageFileName(True));
  FillComboWithLanguages(cboLanguage, FLngList);
  cboLanguageChange(NIL);
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
  FLngList.Free;
  frmWizard := NIL;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.FormShow(Sender: TObject);
var
  png: TPortableNetworkGraphic;
begin
  CheckColorTheme(Self);
  png := TPortableNetworkGraphic.Create;
  try
    if ColorThemeInstance.GetRealColorMode = cmDark then
      png.LoadFromLazarusResource('terosubtitler_dark')
    else
      png.LoadFromLazarusResource('terosubtitler');

    imgLogo.Picture.Graphic := png;
  finally
    png.Free;
  end;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.SetPageStep(const AIndex: Integer);
var
  i: Integer;
begin
  FIndex := AIndex;
  if AIndex = 2 then Close;

  for i := 0 to ControlCount-1 do
    if Controls[i] is TUWLayout then
      with TUWLayout(Controls[i]) do
      begin
        if Tag = AIndex then
          Visible := True
        else
          Visible := False
      end;

  lblLanguage.Visible := AIndex = 1;
  cboLanguage.Visible := AIndex = 1;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnNextClick(Sender: TObject);
begin
  SetPageStep(FIndex+1);
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.cboLanguageChange(Sender: TObject);
var
  langs: TStringArray;
begin
  langs := FLngList.Strings[cboLanguage.ItemIndex].Split([';']);
  if Length(langs) > 0 then
    AppOptions.GUILanguage := langs[0]
  else
    AppOptions.GUILanguage := 'en_US';

  SetGUILanguage;

  if lngwizLanguage <> 'Language' then
    lblLanguage.Caption := 'Language / ' + lngwizLanguage
  else
    lblLanguage.Caption := lngwizLanguage;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnDownloadClick(Sender: TObject);
begin
  ShowDownloadDialog(URL_LIBMPV, ConcatPaths([libmpvFolder, 'libmpv.zip']));
  if FileExists(libMPVFileName) then
  begin
    btnDownload.Enabled := False;
    lblLibMPVStatus.Caption := lngSuccess;
  end;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnDownloadYTDLPClick(Sender: TObject);
begin
  {$IFDEF DARWIN}
  ShowDownloadDialog(URL_YTDLP, ConcatPaths([YTDLPFolder, 'ytdlp.zip']));
  {$ELSE}
  ShowDownloadDialog(URL_YTDLP, YTDLPFileName);
  {$ENDIF}
  if FileExists(ConcatPaths([YTDLPFolder, YTDLP_EXE])) then
  begin
    btnDownloadYTDLP.Enabled := False;
    Tools.YTDLP              := ConcatPaths([YTDLPFolder, YTDLP_EXE]);
    lblYTDLPStatus.Caption   := lngSuccess;
  end;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnDownloadFFMPEGClick(Sender: TObject);
begin
//  {$IFDEF DARWIN}
//  ShowDownloadDialog(StringReplace(URL_FFMPEG, '%cpu', GetCPUArchitectureString, []), ConcatPaths([ffmpegFolder, 'ffmpeg.zip']));
//  {$ELSE}
//  ShowDownloadDialog(URL_FFMPEG, ConcatPaths([ffmpegFolder, 'ffmpeg.zip']));
//  {$ENDIF}
  ShowDownloadDialog(URL_FFMPEG, ConcatPaths([ffmpegFolder, 'ffmpeg.zip']));
  if FileExists(ConcatPaths([ffmpegFolder, FFMPEG_EXE])) then
  begin
    btnDownloadFFMPEG.Enabled := False;
    Tools.FFmpeg              := ConcatPaths([ffmpegFolder, FFMPEG_EXE]);
    lblFFMPEGStatus.Caption   := lngSuccess;
  end;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnDownloadWhisperClick(Sender: TObject);
begin
  {$IFDEF DARWIN}
  ShowDownloadDialog(StringReplace(URL_WHISPER, '%cpu', GetCPUArchitectureString, []), ConcatPaths([WhisperFolder, 'whisper.zip']));
  {$ELSE}
  ShowDownloadDialog(URL_WHISPER, ConcatPaths([WhisperFolder, 'whisper.zip']));
  {$ENDIF}
  if FileExists(ConcatPaths([WhisperFolder, WHISPER_EXE])) then
  begin
    btnDownloadWhisper.Enabled := False;
    Tools.WhisperCPP           := ConcatPaths([WhisperFolder, WHISPER_EXE]);
    lblWhisperStatus.Caption   := lngSuccess;
  end;
end;

// -----------------------------------------------------------------------------

procedure TfrmWizard.btnDownloadFasterWhisperClick(Sender: TObject);
begin
  {$IFDEF DARWIN}
  ShowDownloadDialog(StringReplace(URL_FASTERWHISPER, '%cpu', GetCPUArchitectureString, []), ConcatPaths([WhisperFolder, 'whisper.zip']));
  {$ELSE}
  ShowDownloadDialog(URL_FASTERWHISPER, ConcatPaths([WhisperFolder, 'whisper.zip']));
  ShowDownloadDialog(URL_FASTERWHISPERCUDA, ConcatPaths([WhisperFolder, 'cuda.zip']));
  {$ENDIF}
  if FileExists(ConcatPaths([WhisperFolder, FASTERWHISPER_EXE])) then
  begin
    btnDownloadFasterWhisper.Enabled := False;
    Tools.FasterWhisper              := ConcatPaths([WhisperFolder, FASTERWHISPER_EXE]);
    lblFasterWhisperStatus.Caption   := lngSuccess;
  end;
end;

// -----------------------------------------------------------------------------

end.

