{*
 *  URUWorks Subtitles Utils
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

unit UWSubtitles.Utils;

// -----------------------------------------------------------------------------

interface

uses SysUtils, StrUtils, Classes, Graphics, Math, uregexpr;

type

  TAutomaticDurationMode = (dmAlwaysNew, dmIfGreater, dmIfSmaller);

  TRegExReplaceSpaces = class
    function ReplaceSpaces(ARegExpr: TRegExpr): RegExprString;
  end;

{ Timings }

function SetDurationLimits(const Duration, Min, Max: Cardinal; const UseMax: Boolean = True; const UseMin: Boolean = True): Cardinal; // maximum duration and minimum duration
function SetDelay(const Time, Delay: Integer): Cardinal;                        // positive or negative, time or frames
function TimeExpander(const Text: String; const Duration, MSecsValue, CharsValue, MinMSecsDuration: Cardinal; const Expand: Boolean): Cardinal; // expand/reduce the final time of certain subtitles under certain conditions
function ExtendLength(const NextInitialTime: Cardinal; const AGapMs: Cardinal): Cardinal;
function AutomaticDurations(const Text: String; const Duration, msPerChar, msPerWord, msPerLine: Cardinal; const Mode: TAutomaticDurationMode): Cardinal; // calculate the duration of subtitles using a simple formula
procedure ShiftTime(const InitialTime, FinalTime, Value: Integer; out NewInitialTime, NewFinalTime: Integer); // Time to shift subtitle forwards/backwards
procedure RoundFramesValue(const InitialTime, FinalTime: Integer; const AFPS: Single; out NewInitialTime, NewFinalTime: Integer; const SMPTE: Boolean = False);
function RoundTimeValue(const ATimeValue, AFactor: Integer; const ARoundUp: Boolean = False): Cardinal;

{ Texts }

function FixTags(const Text: String; const StartTag, EndTag: Char): String;
function FixIncompleteTags(const Text: String; const StartTag: Char = '{'; const EndTag: Char = '}'): String;
function CleanupTags(const Text: String; const Tags: Array of String; const StartTag: Char = '{'; const EndTag: Char = '}'): String;
function RemoveUnnecessaryDots(Text: String): String;
function RemoveUnnecessarySpaces(const Text: String; const BreakChar: String = sLineBreak): String;
function HasProhibitedChars(Text, Chars: String): Boolean;
function HasTooLongLine(Text: String; const MaxChars: Integer = 42): Boolean;
function SmartLineAdjust(Text: String; const ChrsPerLine: Integer; const BreakChar: String = sLineBreak): String; // constrain subtitles bigger than three lines into two and adjust length of lines
function AutoBreakSubtitle(Text: String; const ChrsPerLine: Integer; const BreakChar: String = sLineBreak; const UnbreakBefore: Boolean = True): String;
function UnbreakSubtitles(const Text: String; const BreakChar: String = sLineBreak; const UnbreakDialog: Boolean = False): String;
function UnbreakSubtitlesIfLessThanChars(const Text: String; const MaxChars: Integer; const BreakChar: String = sLineBreak): String;
function DivideLines(Text: String; const InitialTime, FinalTime: Cardinal; const AddDots: Boolean = False; const ChrsPerLine: Integer = 43; const Gap: Integer = 833; const BreakChar: String = sLineBreak; const Ellipsis: String = '...'): String;
function DivideLinesAtPosition(Text: String; const InitialTime, FinalTime, Position: Cardinal; const Gap: Integer = 833): String;
function ReverseText(Text: String): String;
function FixRTLPunctuation(const Text: String; const Delimiter: String = sLineBreak): String;
function IsHearingImpaired(const Text: String): Boolean;
function FixHearingImpaired(const Text: String; const Enter: String = sLineBreak): String;
function HasRepeatedChar(const Text, RepeatableChars: String): Boolean;
function FixRepeatedChar(Text: String; const RepeatableChars: String): String;
function FixIncompleteOpenedHyphen(const Text: String): String;
function SpacingOfOpeningHyphen(const Text: String; const AddSpace: Boolean): String;
function FixInterrobang(Text: String): String;
function RemoveSpacesWithinBrackets(const Text: String): String;
function StraightToCurlyQuotes(const Text: String): String;
function CurlyToStraightQuotes(const Text: String): String;
function FixBrackets(const Text: String): String;
function RemoveLeadingChar(const Text: String; const LeadCharsPrimary: array of String; const LeadCharsSecondary: array of String): String;

{ Draw }

procedure DrawASSText(const ACanvas: TCanvas; const ARect: TRect; Text: String);

// -----------------------------------------------------------------------------

implementation

uses UWSystem.SysUtils, UWSystem.StrUtils, UWSystem.TimeUtils, UWSystem.Encoding,
  LazUTF8, LCLIntf;

const
  startTag: String = '{';
  endTag: String = '}';
  boldTag: String = 'b';
  italicTag: String = 'i';
  underlineTag: String = 'u';
  strikeoutTag: String = 's';
  colorTag: String = 'c';

// -----------------------------------------------------------------------------

{ Timings }

// -----------------------------------------------------------------------------

function SetDurationLimits(const Duration, Min, Max: Cardinal; const UseMax: Boolean = True; const UseMin: Boolean = True): Cardinal;
begin
  if not UseMax and not UseMin then
    Result := Duration
  else if UseMax and UseMin then
    Result := Range(Duration, Min, Max)
  else if UseMax then
    Result := Math.Max(Duration, Max)
  else if UseMin then
    Result := Math.Max(Duration, Min);
end;

// -----------------------------------------------------------------------------

function SetDelay(const Time, Delay: Integer): Cardinal;
begin
  if (Time + Delay) > 0 then
    Result := Time + Delay
  else
    Result := 0;
end;

// -----------------------------------------------------------------------------

function TimeExpander(const Text: String; const Duration, MSecsValue, CharsValue,
  MinMSecsDuration: Cardinal; const Expand: Boolean): Cardinal;
var
  Apply : Boolean;
  pc    : Cardinal;
begin
  Result := Duration;
  Apply  := True;
  pc     := UTF8Length(Text);

  if (CharsValue > 0) and (pc <= CharsValue) then Apply := False;

  if Apply then
  begin
    if (MinMSecsDuration > 0) then
    begin
      if (Expand and (Duration > MinMSecsDuration)) or (not Expand and (Duration < MinMSecsDuration)) then
        Apply := False;
    end;

    if Apply then
    begin
      //TODO: Prevent overlapping

      if Expand then
        Result := Duration + MSecsValue
      else
        Result := Duration - MSecsValue;
    end;
  end;
end;

// -----------------------------------------------------------------------------

function ExtendLength(const NextInitialTime: Cardinal; const AGapMs: Cardinal): Cardinal;
begin
  Result := NextInitialTime - AGapMs;
end;

// -----------------------------------------------------------------------------

function AutomaticDurations(const Text: String; const Duration, msPerChar,
  msPerWord, msPerLine: Cardinal; const Mode: TAutomaticDurationMode): Cardinal;
var
  pc, pw,
  pl, nd: Cardinal;
begin
  Result := Duration;

  pc := UTF8Length(Text);
  pw := WordCount(Text);
  pl := LineCount(Text);
  nd := (pc * msPerChar) + (pw * msPerWord) + (pl * msPerLine);

  case Mode of
    dmAlwaysNew: Result := nd;
    dmIfGreater: if nd > Duration then Result := nd;
    dmIfSmaller: if nd < Duration then Result := nd;
  end;
end;

// -----------------------------------------------------------------------------

procedure ShiftTime(const InitialTime, FinalTime, Value: Integer;
  out NewInitialTime, NewFinalTime: Integer);
begin
  NewInitialTime := InitialTime + Value;
  NewFinalTime   := FinalTime   + Value;
end;

// -----------------------------------------------------------------------------

procedure RoundFramesValue(const InitialTime, FinalTime: Integer; const AFPS: Single; out NewInitialTime, NewFinalTime: Integer; const SMPTE: Boolean = False);
begin
  if SMPTE then
  begin
    NewInitialTime := RoundTimeWithFrames(Round(InitialTime * 1.001), AFPS);
    NewFinalTime   := RoundTimeWithFrames(Round(FinalTime * 1.001), AFPS);
    NewInitialTime := Round(NewInitialTime / 1.001);
    NewFinalTime   := Round(NewFinalTime / 1.001);
  end
  else
  begin
    NewInitialTime := RoundTimeWithFrames(InitialTime, AFPS);
    NewFinalTime   := RoundTimeWithFrames(FinalTime, AFPS);
  end;
end;

// -----------------------------------------------------------------------------

function RoundTimeValue(const ATimeValue, AFactor: Integer; const ARoundUp: Boolean = False): Cardinal;
var
  ModValue : Integer;
begin
  ModValue := ATimeValue mod AFactor;

  if (ModValue > 0) and (ARoundUp or (ModValue >= AFactor div 2)) then
    ModValue := ModValue - AFactor;

  Result := ATimeValue - ModValue;
end;

// -----------------------------------------------------------------------------

{ Texts }

// -----------------------------------------------------------------------------

function TRegExReplaceSpaces.ReplaceSpaces(ARegExpr: TRegExpr): RegExprString;
begin
  Result := ReplaceString(ARegExpr.Match[0], ' ', '');
end;

// -----------------------------------------------------------------------------

function FixTags(const Text: String; const StartTag, EndTag: Char): String;

  function RemoveSpaces(const S: String): String;
  var
    rs : TRegExReplaceSpaces;
  begin
    with TRegExpr.Create('({.+})') do
    try
      ModifierG := False;
      Result := Replace(S, @rs.ReplaceSpaces);
    finally
      Free;
    end;
  end;

begin
  Result := RemoveSpaces(Text); //Result := ReplaceRegExpr(Format('\s+(?=[^%s%s]*\%s)', [StartTag, EndTag, EndTag]), Text, '', [rroModifierG]);
  Result := FixIncompleteTags(Result, StartTag, EndTag);
end;

// -----------------------------------------------------------------------------

function FixIncompleteTags(const Text: String; const StartTag: Char = '{'; const EndTag: Char = '}'): String;
var
  L : TStrings;
  s : String;
  x, i : Integer;
begin
  if Text.IsEmpty then Exit;
  Result := Text;

  L := TStringList.Create;
  try
    RE_ExtractTags(Text, L);
    if L.Count > 0 then
    begin
      for i := 0 to L.Count-1 do
      begin
        x := Pos(L.NameValueSeparator, L[i]);
        s := Copy(L[i], 1, x-1);
        x := Copy(L[i], x+1).ToInteger;

        if s.EndsWith('1') then
        begin
          if x < Result.Length then
            Result := Format('%s%s\%s0%s', [Result, StartTag, Copy(s, 1, s.Length-1), EndTag])
          else
            Delete(Result, x, s.Length+3);
        end
        else if s.EndsWith('0') then
        begin
          if x >= (Result.Length - (s.Length+3)) then
            Result := Format('%s\%s1%s%s', [StartTag, Copy(s, 1, s.Length-1), EndTag, Result])
          else
            Delete(Result, x, s.Length+3);
        end;
      end;
    end;
  finally
    L.Free;
  end;
end;

// -----------------------------------------------------------------------------

function CleanupTags(const Text: String; const Tags: Array of String; const StartTag: Char = '{'; const EndTag: Char = '}'): String;
var
  i : Integer;
  sTag, eTag: String;
begin
  Result := Text;
  if Result.IsEmpty or (Length(Tags) = 0) then Exit;

  for i := 0 to Length(Tags)-1 do
  begin
    Result := ReplaceRegExpr(
      Format('(%s\\%s1%s)([\s\S]*?)(%s\\%s0%s)(\s*)\1([\s\S]*?)\3', [StartTag, Tags[i], EndTag, StartTag, Tags[i], EndTag]),
      Result,
      '$1$2$4$5$3',
      [rroModifierI, rroModifierG, rroModifierM, rroUseSubstitution]);
  end;

  //
  for i := 0 to Length(Tags)-1 do
  begin
    sTag := Format('%s\%s1%s', [StartTag, Tags[i], EndTag]);
    eTag := Format('%s\%s0%s', [StartTag, Tags[i], EndTag]);

    while Result.Contains(sTag+sTag) and Result.Contains(eTag+eTag) do
      Result := StringsReplace(Result, [sTag+sTag, eTag+eTag], [sTag, eTag], [rfReplaceAll]);
  end;
end;

// -----------------------------------------------------------------------------

function RemoveUnnecessaryDots(Text: String): String;
begin
  while UTF8Pos('....', Text) > 0 do UTF8Delete(Text, UTF8Pos('....', Text), 1);
  Result := Text;
end;

// -----------------------------------------------------------------------------

function RemoveUnnecessarySpaces(const Text: String; const BreakChar: String = sLineBreak): String;
var
  v1, v2: String;
begin
  Result := Trim(Text);
  v1 := ' ' + BreakChar;
  v2 := BreakChar + ' ';

  while AnsiContainsText(Result, '  ') do Result := ReplaceString(Result, '  ', ' ');
  while AnsiContainsText(Result, v1) do Result := ReplaceString(Result, v1, BreakChar);
  while AnsiContainsText(Result, v2) do Result := ReplaceString(Result, v2, BreakChar);
  if AnsiEndsText(BreakChar, Result) then Result := Copy(Result, 1, UTF8Length(Result) - BreakChar.Length);
  if AnsiStartsText(BreakChar, Result) then Delete(Result, 1, BreakChar.Length);
end;

// -----------------------------------------------------------------------------

function HasProhibitedChars(Text, Chars: String): Boolean;
var
  split: TStringList;
  i: Integer;
begin
  Result := False;
  if (Text <> '') and (Chars <> '') then
  begin
    Text  := LowerCase(Text);
    Chars := LowerCase(Chars);
    split := TStringList.Create;
    try
      SplitRegExpr('\,', Chars, split);
      for i := 0 to split.Count-1 do
      begin
        if AnsiContainsText(Text, split[i]) then
        begin
          Result := True;
          Break;
        end;
      end;
    finally
      split.Free;
    end;
  end;
end;

// -----------------------------------------------------------------------------

function HasTooLongLine(Text: String; const MaxChars: Integer = 42): Boolean;
var
  PosEnter : Integer;
  EnterLen : Integer;
begin
  Result   := False;
  EnterLen := UTF8Length(sLineBreak);
  PosEnter := UTF8Pos(sLineBreak, Text);
  while PosEnter > 0 do
  begin
    if PosEnter-1 > MaxChars then
    begin
      Result := True;
      Exit;
    end;
    Text     := UTF8Copy(Text, PosEnter + EnterLen, UTF8Length(Text)-PosEnter);
    PosEnter := UTF8Pos(sLineBreak, Text);
  end;
  Result := UTF8Length(Text) > MaxChars;
end;

// -----------------------------------------------------------------------------

function SmartLineAdjust(Text: String; const ChrsPerLine: Integer; const BreakChar: String = sLineBreak): String;
var
  i : Integer;
  s : TStringList;
begin
  Result := Text;
  if Text.IsEmpty or (UTF8Length(Text) <= ChrsPerLine) then Exit;

  Text := RemoveUnnecessarySpaces(Text, BreakChar);

  // try to break dialogs
  if AnsiContainsText(Text, '-') then
  begin
    s := TStringList.Create;
    try
      s.SkipLastLineBreak := True;
      s.AddDelimitedText(Text, '-', True);
      if s.Count > 0 then
      begin
        Result := '';
        for i := 0 to s.Count-1 do
          if not s[i].IsEmpty then
          begin
            if i < s.Count-1 then
              Result := Format('%s-%s%s', [Result, s[i], BreakChar])
            else
              Result := Format('%s-%s', [Result, s[i]]);
          end;

        Result := RemoveUnnecessarySpaces(Result, BreakChar);
      end;
    finally
      s.Free;
    end;
  end
  else
    Result := UWSystem.StrUtils.WrapText(Text, ChrsPerLine);
end;

// -----------------------------------------------------------------------------

function AutoBreakSubtitle(Text: String; const ChrsPerLine: Integer; const BreakChar: String = sLineBreak; const UnbreakBefore: Boolean = True): String;
begin
  if UnbreakBefore then Text := UnbreakSubtitles(Text, BreakChar, True);
  Result := SmartLineAdjust(Text, ChrsPerLine, BreakChar);
end;

// -----------------------------------------------------------------------------

function UnbreakSubtitles(const Text: String; const BreakChar: String = sLineBreak; const UnbreakDialog: Boolean = False): String;
var
  AllLines : Array of String;
  Line : Integer = 0;
begin
  if Pos(BreakChar, Text) = 0 then
    Exit(Text);

  if (Pos('-', Text) = 0) or UnbreakDialog then
    Exit(ReplaceString(Text, BreakChar, ' '));

  AllLines := Text.Split([BreakChar]);
  Result := AllLines[0];

 for Line := 1 to High(AllLines) do
   if UTF8LeftStr(AllLines[Line], 1)= '-' then
     Result := Result + BreakChar + AllLines[Line]
   else
     Result := Result + ' ' + AllLines[Line];
end;

// -----------------------------------------------------------------------------

function UnbreakSubtitlesIfLessThanChars(const Text: String; const MaxChars: Integer; const BreakChar: String = sLineBreak): String;
var
  x: Integer;
begin
  x := UTF8Pos(BreakChar, Text);
  if (x > 0) and (not Text.StartsWith('-')) and (UTF8Length(ReplaceRegExpr('{(.*?)}', UnbreakSubtitles(Text, BreakChar), '', True)) <= MaxChars) and (not Copy(Text, x+BreakChar.Length).StartsWith('-')) then
    Result := UnbreakSubtitles(Text, BreakChar)
  else
    Result := Text;
end;

// -----------------------------------------------------------------------------

//LeadCharsPrimary - the main characters that needs to me removed. Only its FIRST occurence is removed
//LeadCharsSecondary - some other characters that shall be removed, like leading sapces. All leading occurences are removed
function RemoveLeadingChar(const Text: String; const LeadCharsPrimary: array of String; const LeadCharsSecondary: array of String): String;
var
  IsLeadChar : Boolean = False;
  CharIndex : integer = 1;
  LeadIndex : integer = 0;
  LastLead : integer = 0;
  LeadChar : String = '';
  IsPrimary : Boolean = False;
  PrimaryFound : Boolean = False;
begin
  Result := Text;
  if Length(LeadCharsPrimary) = 0 then exit;
  if (Text = '') then exit;
  for CharIndex:= 1 to UTF8Length(Result) do
  begin
    IsLeadChar := False;
    for LeadIndex := 0 to (high (LeadCharsPrimary) + Length(LeadCharsSecondary)) do
    begin
      IsPrimary := (LeadIndex < Length(LeadCharsPrimary));
      LeadChar := SysUtils.BoolToStr(IsPrimary,LeadCharsPrimary[LeadIndex],LeadCharsSecondary[LeadIndex - Length(LeadCharsPrimary)]);
      if (LeadChar = UTF8Copy(Result,CharIndex,1)) then
      begin
        IsLeadChar := True;
        if (IsPrimary = True) and (PrimaryFound = True) then begin IsLeadChar := False; break; end;
        inc(LastLead);
        if (IsPrimary = True) then PrimaryFound := True;
      end; //LeadChar
    end; //for LeadIndex
    if (IsLeadChar = False) then break;
  end; //for CharIndex
  if (LastLead < 1) then exit;
  Result := UTF8Copy(Result,LastLead + 1,MaxInt);
end;

// -----------------------------------------------------------------------------

function DivideLines(Text: String; const InitialTime, FinalTime: Cardinal; const AddDots: Boolean = False; const ChrsPerLine: Integer = 43; const Gap: Integer = 833; const BreakChar: String = sLineBreak; const Ellipsis: String = '...'): String;
var
  s: TStringList;
  i, startt, endt, duration, N: Cardinal;
  dots: Boolean;
  str: String;
  TotalTime: Integer;
  GapReal: Integer;
begin
  Result := '';
  dots   := False;
  s := TStringList.Create;
  try
    s.SkipLastLineBreak := True;
    SplitRegExpr('\'+BreakChar, Text, s);
    if s.Count <= 1 then
    begin
      Text := AutoBreakSubtitle(Text, ChrsPerLine, BreakChar, False);
      SplitRegExpr('\'+BreakChar, Text, s);
      if s.Count <= 1 then Exit;
    end;

    N := s.Count;
    if N = 0 then Exit;

    TotalTime := FinalTime - InitialTime;

    if N = 1 then
    begin
      duration := TotalTime;
      GapReal := 0;
    end
    else
    begin
      duration := (TotalTime - (N - 1) * Gap) div N;
      if duration < 1 then duration := 1;
      GapReal := (TotalTime - N * duration) div (N - 1);
    end;

    startt := InitialTime;

    for i := 0 to N - 1 do
    begin
      if i = N - 1 then
        endt := FinalTime
      else
        endt := startt + duration;

      str := s[i];
      if AddDots and (i = 0) and not AnsiEndsText(',', str) and not AnsiEndsText('.', str) then
        str := str + Ellipsis
      else if AddDots and (i > 0) then
        str := Ellipsis + str;

      Result := Result + Format('%d||%d||%s||', [startt, endt, str]);

      if i < N - 1 then
        startt := endt + GapReal;
    end;
  finally
    s.Free;
  end;
end;

// -----------------------------------------------------------------------------

function DivideLinesAtPosition(Text: String; const InitialTime, FinalTime, Position: Cardinal; const Gap: Integer = 833): String;
var
  sl : TStringList;
  i, ft, duration : Cardinal;
begin
  Result := '';
  sl := TStringList.Create;
  try
    if (Position = 0) or (Position >= UTF8Length(Text)) then Exit;

    sl.Add(UTF8Copy(Text, 1, Position).Trim);
    sl.Add(UTF8Copy(Text, Position+1, UTF8Length(Text)-Position).Trim);

    duration := (FinalTime - InitialTime) div sl.Count;
    ft       := InitialTime + duration;

    Result := Format('%d||%d||%s||', [InitialTime, ft, sl[0]]);

    for i := 1 to sl.Count - 1 do
    begin
      ft := ft + Gap;
      Result := Format('%s%d||%d||%s||', [Result, ft + 1, ft + duration, sl[i]]);
      ft := ft + duration;
    end;
  finally
    sl.Free;
  end;
end;

// -----------------------------------------------------------------------------

function ReverseText(Text: String): String;
begin
  // TODO: Fix tags, etc
  Result := UTF8ReverseString(Text);
end;

// -----------------------------------------------------------------------------

function FixRTLPunctuation(const Text: String; const Delimiter: String = sLineBreak): String;
const
  SpecialChars = '.,:;''()-?!+=*&$^%#@~`" /';

var
  Posit : Integer;
  A,B   : String;

  function FixSubString(const Sub: String): String;
  var
    Prefix : String;
    Suffix : String;
    Temp   : String;
    P,I    : Integer;
  begin
    Temp   := Sub;
    Prefix := '';
    Suffix := '';
    I      := 1;
    if Temp = '' then
    begin
      Result := '';
      exit;
    end;

    P := UTF8Pos(Temp[i], SpecialChars);
    while P <> 0 do
    begin
      Prefix := Prefix + Temp[i];
      Temp   := UTF8Copy(Temp, 2, UTF8Length(Temp)-2);
      if Temp = '' then
        P := 0
      else
        P := UTF8Pos(Temp[i], SpecialChars);
    end;
    if Suffix = ' -' then Suffix := '- ';

    I := UTF8Length(Temp);
    if Temp = '' then
      P := 0
    else
      P := UTF8Pos(Temp[i], SpecialChars);
    while P <> 0 do
    begin
      Suffix := Suffix + Temp[I];
      Temp   := UTF8Copy(Temp, 1, UTF8Length(Temp));
      i      := UTF8Length(Temp);
      if Temp = '' then
        P := 0
      else
        P := UTF8Pos(Temp[i], SpecialChars);
      end;
    if Prefix = '- ' then Prefix := ' -';

    Result := Suffix + Temp + Prefix;
  end;
begin
  A := Text;
  B := '';
  Posit := UTF8Pos(Delimiter, A);
  while Posit > 0 do
  begin
    B     := B + FixSubString(UTF8Copy(A, 1, Posit-1)) + Delimiter;
    A     := Copy(A, Posit + UTF8Length(Delimiter));
    Posit := UTF8Pos(Delimiter, A);
  end;
  B := B + FixSubString(A);
  Result := B;
end;

// -----------------------------------------------------------------------------

function IsHearingImpaired(const Text: String): Boolean;
begin
  if ((Pos('(', Text) > 0) and (Pos(')', Text) > Pos('(', Text))) or
    ((Pos('[', Text) > 0) and (Pos(']', Text) > Pos('[', Text))) or
    ((Pos('<', Text) > 0) and (Pos('>', Text) > Pos('<', Text))) or
    (StringCount('♪', Text) > 1) or (StringCount('♫', Text) > 1) then
    Result := True
  else
    Result := False;
end;

// -----------------------------------------------------------------------------

function FixHearingImpaired(const Text: String; const Enter: String = sLineBreak): String;

  function RHearingImpairedBetweenChar(Line, AChar: String): String;
  var
    a, b: Integer;
  begin
    Result := Line;
    repeat
      a := UTF8Pos(AChar, Result);
      b := UTF8Pos(AChar, Result, a+1);
      if (a > 0) and (b > 0) then UTF8Delete(Result, a, b);
    until (a = 0) or (b = 0);
  end;

  function RHearingImpairedBetweenChars(Line, AChar, BChar: String): String;
  begin
    Result := Line;
    while (UTF8Pos(AChar, Result) > 0) and (UTF8Pos(BChar, Result) > UTF8Pos(AChar, Result)) do
    begin
      if UTF8Copy(Result, UTF8Pos(BChar, Result) + 1, 1) = ':' then UTF8Delete(Result, UTF8Pos(BChar, Result) + 1, 1);
      UTF8Delete(Result, UTF8Pos(AChar, Result), UTF8Pos(BChar, Result) - UTF8Pos(AChar, Result) + 1);
    end;
  end;

  function RHearingImpaired(Line: String): String;
  begin
    Result := RHearingImpairedBetweenChars(Line, '(', ')');
    Result := RHearingImpairedBetweenChars(Result, '[', ']');
    Result := StringsReplace(Result, ['♪', '♫'], ['', ''], [rfReplaceAll]);
  end;

var
  PosEnter : Integer;
  A, B     : String;
  sl       : TStrings;
  i        : Integer;
begin
  Result := '';
  if Text <> '' then
  begin
    A := Text;
    B := '';
    PosEnter := UTF8Pos(Enter, A);
    while PosEnter > 0 do
    begin
      B        := B + RHearingImpaired(UTF8Copy(A, 1, PosEnter-1)) + Enter;
      A        := UTF8Copy(A, PosEnter + UTF8Length(Enter), UTF8Length(A));
      PosEnter := UTF8Pos(Enter, A);
    end;
    B := RemoveUnnecessarySpaces(RHearingImpaired(B + RHearingImpaired(A)));

    PosEnter := UTF8Pos(Enter, B);
    if (PosEnter > 0) and (UTF8Copy(B, 1, PosEnter-1).Trim = '-') then
    begin
      UTF8Delete(B, 1, PosEnter+UTF8Length(Enter)-1);
    end;

    if (UTF8Pos(Enter, B) = 0) and (UTF8Copy(B, 1, 1) = '-') then
    begin
      UTF8Delete(B, 1, 1);
      Result := RemoveUnnecessarySpaces(B);
    end
    else
      Result := B;

    // remnants after Remove Text for Hearing Impaired
    if Result <> Text then
    begin
      sl := TStringList.Create;
      try
        sl.Text := Result;
        if sl.Count > 0 then
          for i := sl.Count-1 downto 0 do
          begin
            A := sl[i].Trim;
            if (A.IsEmpty) or (A.StartsWith('-') and (UTF8Length(A) = 1)) then
              sl.Delete(i);
          end;
        Result := sl.Text.Trim;
      finally
        sl.Free;
      end;
    end;
  end;
end;

// -----------------------------------------------------------------------------

function HasRepeatedChar(const Text, RepeatableChars: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to UTF8Length(Text)-1 do
  begin
    if (UTF8Pos(Text[i], RepeatableChars) > 0) and (Text[i+1] = Text[i]) then
      if (Text[i] <> '/') or (UTF8Copy(Text, i-1, 3) <> '://') then
      begin
        Result := True;
        Exit;
      end;
  end;
end;

// -----------------------------------------------------------------------------

function FixRepeatedChar(Text: String; const RepeatableChars: String): String;
var
  i: Integer;
begin
  for i := UTF8Length(Text) downto 2 do
  begin
    if (UTF8Pos(Text[i], RepeatableChars) > 0) and (Text[i-1] = Text[i]) then
      if (Text[i] <> '/') or (UTF8Copy(Text, i-2, 3) <> '://') then
        UTF8Delete(Text, i, 1);
  end;
  Result := Text;
end;

// -----------------------------------------------------------------------------

function FixIncompleteOpenedHyphen(const Text: String): String;
var
  sl: TStringList;
  i, c: Integer;
begin
  Result := Text;
  if Result.IsEmpty or (Pos('-', Text) = 0) then Exit;

  sl := TStringList.Create;
  try
    sl.SkipLastLineBreak := True;
    sl.Text := Text;
    c := sl.Count;

    for i := sl.Count-1 downto 0 do
      if sl[i].Trim = '-' then
        sl.Delete(i);

    if c <> sl.Count then
      Result := sl.Text;
  finally
    sl.Free;
  end;
end;

// -----------------------------------------------------------------------------

function SpacingOfOpeningHyphen(const Text: String; const AddSpace: Boolean): String;
var
  sl, slt : TStringList;
  i, x : Integer;
  s : String;
begin
  Result := Text;
  if Result.IsEmpty or (Result.Length < 3) then Exit;

  sl := TStringList.Create;
  try
    slt := TStringList.Create;
    try
      sl.SkipLastLineBreak := True;
      slt.SkipLastLineBreak := True;
      sl.Text  := ReplaceRegExpr('\{.*?\}', Text, '', True); // text without tags
      slt.Text := Text; // normal text

      for i := 0 to sl.Count-1 do
        if sl[i].StartsWith('-') then
        begin
          s := slt[i];
          x := Pos('-', s)+1;
          if AddSpace then
          begin
            if s[x] <> ' ' then
              Insert(' ', s, x);
          end
          else
          begin
            while s[x] = ' ' do //if s[x] = ' ' then
              Delete(s, x, 1);
          end;
          slt[i] := s;
        end;

        Result := slt.Text;
    finally
      slt.Free;
    end;
  finally
    sl.Free;
  end;
end;

// -----------------------------------------------------------------------------

function FixInterrobang(Text: String): String;
begin
  Result := Text.Replace('!?', '?!', [rfReplaceAll]);
end;

// -----------------------------------------------------------------------------

function RemoveSpacesWithinCustomBrackets(const Text: String; const OpenBracket, CloseBracket: String): String;
var
  x, b1, b2, l: Integer;
  s : String;
begin
  Result := Text;

  x := 1;
  while x > 0 do
  begin
    b1 := UTF8Pos(OpenBracket, Result, x);
    b2 := UTF8Pos(CloseBracket, Result, b1);

    if (b1 = 0) or (b2 = 0) then Exit;

    x := b2+1;
    b1 += 1;

    l := b2-b1;
    s := UTF8Copy(Result, b1, l);
    UTF8Delete(Result, b1, l);
    UTF8Insert(s.Trim, Result, b1);
  end;
end;

// -----------------------------------------------------------------------------

function RemoveSpacesWithinBrackets(const Text: String): String;
begin
  Result := RemoveSpacesWithinCustomBrackets(Text, '[', ']');
  Result := RemoveSpacesWithinCustomBrackets(Result, '(', ')');
end;

// -----------------------------------------------------------------------------

function StraightToCurlyQuotes(const Text: String): String;
var
  i: Integer;
  Ch: String;
  Output: String;
  InDoubleQuote, InSingleQuote: Boolean;
begin
  Output := '';
  InDoubleQuote := False;
  InSingleQuote := False;

  for i := 1 to UTF8Length(Text) do
  begin
    Ch := UTF8Copy(Text, i, 1);

    if Ch = '"' then
    begin
      if not InDoubleQuote then
        Output += #$201C  // “
      else
        Output += #$201D; // ”
      InDoubleQuote := not InDoubleQuote;
    end
    else if Ch = '''' then
    begin
      if not InSingleQuote then
        Output += #$2018  // ‘
      else
        Output += #$2019; // ’
      InSingleQuote := not InSingleQuote;
    end
    else
      Output += Ch;
  end;

  Result := Output;
end;

// -----------------------------------------------------------------------------

function CurlyToStraightQuotes(const Text: String): String;
var
  i: Integer;
  Ch: String;
  Output: String;
begin
  Output := '';
  for i := 1 to UTF8Length(Text) do
  begin
    Ch := UTF8Copy(Text, i, 1);

    if (Ch = #$2018) or (Ch = #$2019) then
      Output += ''''
    else if (Ch = #$201C) or (Ch = #$201D) then
      Output += '"'
    else
      Output += Ch;
  end;

  Result := Output;
end;

// -----------------------------------------------------------------------------

function FixBrackets(const Text: String): String;
const
  Opens: array[1..4] of Char = ('(', '[', '{', '<');
  Closes: array[1..4] of Char = (')', ']', '}', '>');

var
  Stack: array of Integer;  // Guarda el índice del bracket de apertura
  StackPos: Integer;
  i, j, idx: Integer;
  Ch, NextCh: String;
  Output: String;
  Skip: array of Boolean;
begin
  SetLength(Stack, 0);
  SetLength(Skip, UTF8Length(Text) + 1); // Para eliminar brackets vacíos
  for i := 1 to Length(Skip) do Skip[i] := False;

  Output := '';
  StackPos := 0;
  i := 1;
  while i <= UTF8Length(Text) do
  begin
    Ch := UTF8Copy(Text, i, 1);

    // 1. Brackets invertidos ]texto[ -> [texto]
    // Busca patrón ]...[
    if (Ch = ']') or (Ch = ')') or (Ch = '}') or (Ch = '>') then
    begin
      // Busca si más adelante hay el bracket abierto correspondiente antes de uno de cierre
      for j := i + 1 to UTF8Length(Text) do
      begin
        NextCh := UTF8Copy(Text, j, 1);
        idx := -1;
        if (Ch = ']') and (NextCh = '[') then idx := 2;
        if (Ch = ')') and (NextCh = '(') then idx := 1;
        if (Ch = '}') and (NextCh = '{') then idx := 3;
        if (Ch = '>') and (NextCh = '<') then idx := 4;
        if idx <> -1 then
        begin
          // Intercambia
          Skip[i] := True; // Elimina el bracket de cierre invertido
          Skip[j] := True; // Elimina el bracket de apertura invertido
          Output += Opens[idx] + UTF8Copy(Text, i + 1, j - i - 1) + Closes[idx];
          i := j; // Salta hasta después del bracket de apertura invertido
          Break;
        end
        else if (NextCh = ']') or (NextCh = ')') or (NextCh = '}') or (NextCh = '>') then
          Break; // Otro bracket de cierre, no corregimos
      end;
    end

    // 2. Mismatched: <ejemplo} -> <ejemplo>
    else if (Ch = '(') or (Ch = '[') or (Ch = '{') or (Ch = '<') then
    begin
      // Busca el cierre
      idx := -1;
      for j := 1 to 4 do
        if Ch = Opens[j] then
        begin
          idx := j;
          Break;
        end;
      if idx <> -1 then
      begin
        StackPos := StackPos + 1;
        SetLength(Stack, StackPos);
        Stack[StackPos - 1] := idx; // Guarda el tipo de bracket abierto
        Output += Ch;
      end;
    end
    else if (Ch = ')') or (Ch = ']') or (Ch = '}') or (Ch = '>') then
    begin
      idx := -1;
      for j := 1 to 4 do
        if Ch = Closes[j] then
        begin
          idx := j;
          Break;
        end;
      if (StackPos > 0) and (Stack[StackPos - 1] <> idx) then
        Output[Length(Output)] := Closes[Stack[StackPos - 1]] // Corrige mismatched
      else
        Output += Ch;
      if StackPos > 0 then
        Dec(StackPos);
    end

    // 3. Brackets vacíos: () [] {} <> -> se eliminan
    else
    begin
      // Mira hacia atrás si hay bracket abierto y siguiente char es bracket cerrado
      if (Length(Output) > 0) and
         ((Output[Length(Output)] in ['(', '[', '{', '<']) and
         (i <= UTF8Length(Text)) and
         ((UTF8Copy(Text, i, 1) = ')') or (UTF8Copy(Text, i, 1) = ']') or (UTF8Copy(Text, i, 1) = '}') or (UTF8Copy(Text, i, 1) = '>'))) then
      begin
        Output := Copy(Output, 1, Length(Output)-1); // Elimina el bracket abierto
        Inc(i); // Salta el bracket cerrado
        Continue;
      end;
      Output += Ch;
    end;
    Inc(i);
  end;

  Result := Output;
end;

// -----------------------------------------------------------------------------

{ DrawASSText }

// -----------------------------------------------------------------------------

function BGRHex2Color(Value: String): TColor;
begin
  Result := 0;

  if Value <> '' then
    Result := LCLIntf.RGB(StrToInt('$'+Copy(Value, 5, 2)),
                  StrToInt('$'+Copy(Value, 3, 2)),
                  StrToInt('$'+Copy(Value, 1, 2)));
end;

// -----------------------------------------------------------------------------

procedure DrawASSText(const ACanvas: TCanvas; const ARect: TRect; Text: String);

  function CloseTag(const ATag: String): String;
  begin
    Result := Concat('0', ATag);
  end;

  function GetTagValue(const ATag: String; out TagID: String): String;
  var
    p, px: Integer;
  begin
    Result := '';
    TagID  := '';

    // color
    p := UTF8Pos('&', ATag);
    px := UTF8Pos('&', ATag, p+1);
    if (p > 0) and (px > 0) then
    begin
      TagID := 'c';
      Result := UTF8Copy(ATag, p + 1, px - 1);
      Exit;
    end;
    // font name
    p := UTF8Pos('fn', ATag);
    if (p > 0) then
    begin
      TagID := 'fn';
      Result := UTF8Copy(ATag, p + 2, MaxInt);
      Exit;
    end;
    // font size
    p := UTF8Pos('fs', ATag);
    if (p > 0) then
    begin
      TagID := 'fs';
      Result := UTF8Copy(ATag, p + 2, MaxInt);
      Exit;
    end;
    // font encoding
    p := UTF8Pos('fe', ATag);
    if (p > 0) then
    begin
      TagID := 'fe';
      Result := UTF8Copy(ATag, p + 2, MaxInt);
      Exit;
    end;
  end;

var
  x, y, idx,
  CharWidth,
  MaxCharHeight   : Integer;
  CurrChar        : String;
  Tag, TagValue   : String;
  TagTmp, TagTmpX : String;
  TagID           : String;
  PrevFontColour  : TColor;
  NeedBreak       : Boolean;
begin
  if IsRightToLeftByUCC(Text) then
    Text := ReverseText(Text);

  NeedBreak        := False;
  PrevFontColour   := ACanvas.Font.Color;
  x                := ARect.Left;
  y                := ARect.Top;
  idx              := 1;

  MaxCharHeight := ACanvas.TextHeight('Aj');

  while idx <= UTF8Length(Text) do
  begin
    CurrChar := UTF8Copy(Text, idx, 1);
    // Is this a start tag?
    if UTF8CompareStr(CurrChar, startTag) = 0 then
    begin
      Tag := '';
      Inc(idx);

      // Find the end of the tag
      while (UTF8CompareStr(UTF8Copy(Text, idx, 1), endTag) <> 0) and (idx <= UTF8Length(Text)) do
      begin
        Tag := Concat(Tag, (UTF8Copy(Text, idx, 1)));
        Inc(idx);
      end;
      // Simple tags
      if UTF8Copy(Tag, 1, 1) = '\' then
      begin
        TagTmp  := UTF8Copy(Tag, 2, 1);
        TagTmpX := UTF8RightStr(Tag, 1);
        if Length(Tag) = 3 then
        begin
          // Starting tags
          if TagTmpX = '1' then
          begin
            if TagTmp = boldTag then
              ACanvas.Font.Style := ACanvas.Font.Style + [TFontStyle.fsBold]
            else if TagTmp = italicTag then
              ACanvas.Font.Style := ACanvas.Font.Style + [TFontStyle.fsItalic]
            else if TagTmp = underlineTag then
              ACanvas.Font.Style := ACanvas.Font.Style + [TFontStyle.fsUnderline]
            else if TagTmp = strikeoutTag then
              ACanvas.Font.Style := ACanvas.Font.Style + [TFontStyle.fsStrikeout]
          end;
          // Closing tags
          if TagTmpX = '0' then
          begin
            if TagTmp = boldTag then
              ACanvas.Font.Style := ACanvas.Font.Style - [TFontStyle.fsBold]
            else if TagTmp = italicTag then
              ACanvas.Font.Style := ACanvas.Font.Style - [TFontStyle.fsItalic]
            else if TagTmp = UnderlineTag then
              ACanvas.Font.Style := ACanvas.Font.Style - [TFontStyle.fsUnderline]
            else if TagTmp = strikeoutTag then
              ACanvas.Font.Style := ACanvas.Font.Style - [TFontStyle.fsStrikeout]
          end;
        end
        else
        // Tags with values
        begin
          if TagTmp = colorTag then
            ACanvas.Font.Color := PrevFontColour;

          // Get the tag value (everything after ':')
          TagValue := GetTagValue(Tag, TagID);
          if TagValue <> '' then
          begin
            if TagID = colorTag then
            begin
              PrevFontColour := ACanvas.Font.Color;
              try
                ACanvas.Font.Color := BGRHex2Color(TagValue);
              except
              end;
            end;
          end;
        end;
      end;
    end
    else
    // Enter char?
    if CurrChar = #10 then
    begin
      Inc(y, MaxCharHeight);
      x := ARect.Left;
    end
    // Draw the character if it's not a ctrl char
    else if (CurrChar >= #32) then
    begin
      CharWidth := ACanvas.TextWidth(CurrChar);

      if (x + CharWidth > ARect.Right) then // too long line!!
        NeedBreak := True;

      if not NeedBreak and (y < ARect.Bottom) then
      begin
        ACanvas.Brush.Style := bsClear;
        ACanvas.TextOut(x, y, CurrChar);
      end;

      x := x + CharWidth;
      NeedBreak := False;
    end;
    Inc(idx);
  end;
end;

// -----------------------------------------------------------------------------

end.
