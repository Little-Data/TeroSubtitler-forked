{*
 *  URUWorks Subtitle API
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
 *  Copyright (C) 2001-2023 URUWorks, uruworks@gmail.com.
 *}

unit UWSubtitleAPI.Formats.MicroDVD;

// -----------------------------------------------------------------------------

interface

uses
  SysUtils, UWSubtitleAPI, UWSystem.TimeUtils, UWSystem.StrUtils,
  UWSystem.SysUtils, UWSubtitleAPI.Formats;

type

  { TUWMicroDVD }

  TUWMicroDVD = class(TUWSubtitleCustomFormat)
  public
    function Name: String; override;
    function Format: TUWSubtitleFormats; override;
    function Extension: String; override;
    function IsTimeBased: Boolean; override;
    function HasStyleSupport: Boolean; override;
    function IsMine(const SubtitleFile: TUWStringList; const Row: Integer): Boolean; override;
    function LoadSubtitle(const SubtitleFile: TUWStringList; const FPS: Double; var Subtitles: TUWSubtitles): Boolean; override;
    function SaveSubtitle(const FileName: String; const FPS: Double; const Encoding: TEncoding; const Subtitles: TUWSubtitles; const SubtitleMode: TSubtitleMode; const FromItem: Integer = -1; const ToItem: Integer = -1): Boolean; override;
  end;

// -----------------------------------------------------------------------------

implementation

uses UWSubtitleAPI.ExtraInfo, UWSubtitleAPI.Tags;

// -----------------------------------------------------------------------------

function TUWMicroDVD.Name: String;
begin
  Result := IndexToName(Integer(Format));
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.Format: TUWSubtitleFormats;
begin
  Result := TUWSubtitleFormats.sfMicroDVD;
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.Extension: String;
begin
  Result := '*.sub';
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.IsTimeBased: Boolean;
begin
  Result := False;
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.HasStyleSupport: Boolean;
begin
  Result := True;
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.IsMine(const SubtitleFile: TUWStringList; const Row: Integer): Boolean;
begin
  if (StringCount('{', SubtitleFile[Row]) >= 2) and
     (StringCount('}', SubtitleFile[Row]) >= 2) and
     (Pos('{', SubtitleFile[Row]) = 1) and
     ((IsInteger(Copy(SubtitleFile[Row], 2, Pos('}', SubtitleFile[Row]) - 2)) or ((Copy(SubtitleFile[Row], 2, Pos('}', SubtitleFile[Row]) - 2) = '') and (Row > 0) and (IsInteger(Copy(SubtitleFile[Row-1], Pos('{', SubtitleFile[Row-1], 2) + 1, Pos('}', SubtitleFile[Row-1], Pos('}', SubtitleFile[Row-1]) + 1) - (Pos('{', SubtitleFile[Row-1], 2) + 1)))))) and
     (IsInteger(Copy(SubtitleFile[Row], Pos('{', SubtitleFile[Row], 2) + 1, Pos('}', SubtitleFile[Row], Pos('}', SubtitleFile[Row]) + 1) - (Pos('{', SubtitleFile[Row], 2) + 1))) or ((Copy(SubtitleFile[Row], Pos('{', SubtitleFile[Row], 2) + 1, Pos('}', SubtitleFile[Row], Pos('}', SubtitleFile[Row]) + 1) - (Pos('{', SubtitleFile[Row], 2) + 1)) = '') and (Row < SubtitleFile.Count) and (IsInteger(Copy(SubtitleFile[Row+1], 2, Pos('}', SubtitleFile[Row+1]) - 2)))))) then
    Result := True
  else
    Result := False;
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.LoadSubtitle(const SubtitleFile: TUWStringList; const FPS: Double; var Subtitles: TUWSubtitles): Boolean;
var
  i, x        : Integer;
  InitialTime : Integer;
  FinalTime   : Integer;
  Text        : String;
  AFPS        : Single;
  DecimalSep  : Char;
  ExtraInfo   : PMicroDVD_ExtraInfo;
begin
  Result := False;
  try
    AFPS := FPS;
    for i := 0 to SubtitleFile.Count-1 do
    begin
      // DivXG400 FPS Info tag
      if Copy(SubtitleFile[i], 1, 6) = '{1}{1}' then
      begin
        with FormatSettings do
        begin
          DecimalSep       := DecimalSeparator;
          DecimalSeparator := '.';

          if IsInteger(Copy(SubtitleFile[i], 7, Length(SubtitleFile[i]))) then
            AFPS := StrToFloat(Copy(SubtitleFile[i], 7, Length(SubtitleFile[i])));

          DecimalSeparator := DecimalSep;
        end;
      end
      else if (Pos('{', SubtitleFile[i]) = 1) and (Pos('}', SubtitleFile[i]) > 1) and
        (StringCount('{',SubtitleFile[i]) >= 2) and (StringCount('}',SubtitleFile[i]) >= 2) then
      begin
        InitialTime := FramesToTime(StrToIntDef(Copy(SubtitleFile[i], 2, Pos('}', SubtitleFile[i]) - 2), 0), AFPS);
        Text := Copy(SubtitleFile[i], Pos('{', SubtitleFile[i], 2) + 1, Pos('}', SubtitleFile[i], Pos('}', SubtitleFile[i]) + 1) - (Pos('{', SubtitleFile[i], 2) + 1));
        if IsInteger(Text) then
          FinalTime := FramesToTime(StrToIntDef(Text, 0), AFPS)
        else
          FinalTime := InitialTime + 2000;

        Text := ReplaceString(Copy(SubtitleFile[i], Pos('}', SubtitleFile[i], Pos('}', SubtitleFile[i]) + 1) + 1, Length(SubtitleFile[i])), '|', LineEnding);

        if (InitialTime = 0) and (i > 0) then
        begin
          InitialTime := FramesToTime(StrToIntDef(Copy(SubtitleFile[i-1], Pos('{', SubtitleFile[i-1], 2) + 1, Pos('}', SubtitleFile[i-1], Pos('}', SubtitleFile[i-1]) + 1) - (Pos('{', SubtitleFile[i-1], 2) + 1)), 0), AFPS);
          if InitialTime < 0 then InitialTime := 0;
        end;
        if (FinalTime = 0) and (i < SubtitleFile.Count-1) then
        begin
          FinalTime := FramesToTime(StrToIntDef(Copy(SubtitleFile[i+1], 2, Pos('}', SubtitleFile[i+1]) - 2), 0), AFPS);
          if FinalTime < 0 then FinalTime := 0;
        end;

        // control codes
        if Text.Contains('{P:') then
        begin
          New(ExtraInfo);
          x := Pos('{P:', Text);
          ExtraInfo^.X := StrToIntDef(Copy(Text, x+3, Pos(',', Text)-x-3), 0);
          ExtraInfo^.Y := StrToIntDef(Copy(Text, Pos(',', Text, x)+1, Pos('}', Text, x)-Pos(',', Text, x)-1), 0);
        end
        else
          ExtraInfo := NIL;

        // tags
        Text := MicroDVDTagsToTS(Text);

        if (InitialTime >= 0) and (FinalTime > 0) then
          Subtitles.Add(InitialTime, FinalTime, Text, '', ExtraInfo);
      end;
    end;
  finally
    if Subtitles.Count > 0 then
    begin
      Subtitles.ExtraInfoType := eiMicroDVD;
      Result := True;
    end;
  end;
end;

// -----------------------------------------------------------------------------

function TUWMicroDVD.SaveSubtitle(const FileName: String; const FPS: Double; const Encoding: TEncoding; const Subtitles: TUWSubtitles; const SubtitleMode: TSubtitleMode; const FromItem: Integer = -1; const ToItem: Integer = -1): Boolean;
var
  i          : Integer;
  DecimalSep : Char;
  XY         : String;
begin
  Result  := False;

  // DivXG400 FPS Info tag
  with FormatSettings do
  begin
    DecimalSep       := DecimalSeparator;
    DecimalSeparator := '.';
    StringList.Add(SysUtils.Format('{1}{1}%.3f', [FPS]));
    DecimalSeparator := DecimalSep;
  end;

  for i := FromItem to ToItem do
  begin
    XY := '';
    if Subtitles.ExtraInfo[i] <> NIL then
      with PMicroDVD_ExtraInfo(Subtitles.ExtraInfo[i])^ do
        if (X > 0) or (Y > 0) then
          XY := SysUtils.Format('{P:%d,%d}', [X, Y]);

    Subtitles.Text[i] := TSTagsToMicroDVD(iff(SubtitleMode = smText, Subtitles.Text[i], Subtitles.Translation[i]));
    StringList.Add('{' + IntToStr(TimeToFrames(Subtitles.InitialTime[i], FPS)) + '}{' + IntToStr(TimeToFrames(Subtitles.FinalTime[i], FPS)) + '}' +
    XY + ReplaceEnters(Subtitles[i].Text));
  end;

  try
    StringList.SaveToFile(FileName, Encoding);
    Result := True;
  except
  end;
end;

// -----------------------------------------------------------------------------

end.
