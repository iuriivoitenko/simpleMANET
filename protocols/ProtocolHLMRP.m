%****************************************************************************
%
% Copyright (C) 2016 Iurii Voitenko <iurii.voitenko@ntnu.no>
%
% This file is part of the simpleMANET toolkit.
%
% You may use this file under the terms of the BSD license as follows:
%
% "Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%   * Redistributions of source code must retain the above copyright
%     notice, this list of conditions and the following disclaimer.
%   * Redistributions in binary form must reproduce the above copyright
%     notice, this list of conditions and the following disclaimer in
%     the documentation and/or other materials provided with the
%     distribution.
%   * Neither the name of author and its subsidiary(-ies) nor
%     the names of its contributors may be used to endorse or promote
%     products derived from this software without specific prior written
%     permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
%
%****************************************************************************/

classdef ProtocolHLMRP < ProtocolIP
    % HLMRP Summary of this class goes here
    % HLMRP: hop limited multicast routing protocol
    % this class represents the protocol logic
    properties ( Access = private )
        id      
        period                 % timeout interval, ms  
        maxhops = 8;
    end
    
    properties
        type
        seq
        hops
        groups
        last
        protoname
        timer          % current timer tick value
        nonces
        result
        timestamp      % local time 
        rtable         
    end
    
    methods
        function obj = ProtocolHLMRP(id)
            obj.id = id;
            obj.protoname = 'HLMRP';
            obj.seq = 0;   
            obj.hops = 0;
            obj.last = id;
            obj.groups = [];
            obj.period = 980;
            obj.timer = 0;
            obj.timestamp = 0;
            obj.nonces = containers.Map;
            obj.rtable = RouteTable; 
            obj.rtable.add(id,id,0,id,'N');
            obj.result = 0;            
        end
            
        function [hlmrp, pkt] = process_data(hlmrp,pkt)
            
            hlmrp.result = check_ip(hlmrp.id,pkt); % ip level check
            if (hlmrp.result < 0) 

            elseif strcmpi(pkt.next, hlmrp.protoname) == 0
                hlmrp.result = -4;
            elseif strcmpi(num2str(hlmrp.id), num2str(pkt.last)) == 1
                hlmrp.result = -5;
            elseif hlmrp.hops > hlmrp.maxhops
                hlmrp.result = -6;
            else % custom protocol check
                                               
                pkt.ttl = pkt.ttl - 1;
                
                switch (pkt.type)
                    case ('HEARTBEAT')                        
                        pkt = hlmrp.processHB(pkt);                        
                        hlmrp.result = pkt.result;
                    otherwise
                        % ignore
                        hlmrp.result = 0;
                end                
            end
        end
        
        function obj = timeout(obj,d,t)
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;
            if (obj.timer >= obj.period)
                obj = obj.heartbeat(obj.id);
                obj.timer = mod(obj.period, d);
                obj.period = obj.period; %  + (obj.peers * 3000); 
                obj.result = obj.len;
            else
                obj.result = 0;
            end            
        end
        
        function obj = heartbeat(obj, id)
            % IP level
            obj.src = id;
            obj.dst = 0;
            obj.ttl = 8;
            obj.next = 'HLMRP';
            % HLMRP level
            obj.type = 'HEARTBEAT';
            obj.seq = randi([0 1000000],1,1);
            obj.hops = 0;
            obj.last = id;
            obj.len = 100;
        end
        
        function pkt = processHB(obj, pkt)
            if obj.nonces.isKey(num2str(pkt.seq)) == 0 % not known
                obj.nonces(num2str(pkt.seq)) = obj.timestamp + 1000;
                pkt.last = obj.id;
                pkt.hops = pkt.hops + 1;                
                pkt.len = pkt.len + 6;
                pkt.result = pkt.len;
            else
                pkt.result = 0;
            end
            obj.removeNonces();
        end
        
        function obj = removeNonces(obj)
            pkeys = obj.nonces.keys;
            len = obj.nonces.length;
            for p=1:len
                key = pkeys(p);
                time = obj.nonces(char(key));
                if (time < obj.timestamp)
                    obj.nonces.remove(pkeys(p));
                    %obj.rtable.remove(peer.id);
                end
            end             
        end
    end
end

