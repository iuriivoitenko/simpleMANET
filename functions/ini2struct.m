% Copyright (c) 2014, freeb
% Copyright (c) 2008, Andriy Nych
% Copyright (c) 2009-2010, Evgeny Prilepin aka Iroln
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
%     * Neither the name of the  nor the names
%       of its contributors may be used to endorse or promote products derived
%       from this software without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

function Struct = ini2struct(FileName)
% Parses .ini file
% Returns a structure with section names and keys as fields.
%
% Based on init2struct.m by Andriy Nych
% 2014/02/01

f = fopen(FileName,'r');                    % open file
while ~feof(f)                              % and read until it ends
    s = strtrim(fgetl(f));                  % remove leading/trailing spaces
    if isempty(s) || s(1)==';' || s(1)=='#' % skip empty & comments lines
        continue
    end
    if s(1)=='['                            % section header
        Section = genvarname(strtok(s(2:end), ']'));
        Struct.(Section) = [];              % create field
        continue
    end
    
    [Key,Val] = strtok(s, '=');             % Key = Value ; comment
    Val = strtrim(Val(2:end));              % remove spaces after =
    
    if isempty(Val) || Val(1)==';' || Val(1)=='#' % empty entry
        Val = [];
    elseif Val(1)=='"'                      % double-quoted string
        Val = strtok(Val, '"');
    elseif Val(1)==''''                     % single-quoted string
        Val = strtok(Val, '''');
    else
        Val = strtok(Val, ';');             % remove inline comment
        Val = strtok(Val, '#');             % remove inline comment
        Val = strtrim(Val);                 % remove spaces before comment
        
        [val, status] = str2num(Val);       %#ok<ST2NM>
        if status, Val = val; end           % convert string to number(s)
    end
    
    if ~exist('Section', 'var')             % No section found before
        Struct.(genvarname(Key)) = Val;
    else                                    % Section found before, fill it
        Struct.(Section).(genvarname(Key)) = Val;
    end

end
fclose(f);

