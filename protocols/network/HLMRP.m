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

classdef HLMRP < IPv6
    % HLMRP Summary of this class goes here
    % HLMRP: hop limited multicast routing protocol
    % this class represents the protocol logic
    properties (Constant)
        show = 1;             % show protocol packets in the debug window
    end 
    
    properties ( Access = private )
        id      
        period                 % timeout interval, ms  
        maxhops = 8;
        overhead = 48;
    end
    
    properties
        protoname
        timer          % current timer tick value
        hbeat        
        mdata
        data
        ctrl
        datalen
        dataperiod
        datatimer
        isSender
        isReceiver
        groups_rx
        groups_tx
        nonces
        mgroup
        result
        timestamp      % local time 
        rtable         
    end
    
    methods
        function obj = HLMRP(id, agent, app)
            obj.id = id;
            obj.protoname = 'HLMRP';
            obj.period = 180;
            obj.timer = 0;
            obj.dataperiod = 0;
            obj.datatimer = 0;
            obj.datalen = 0;
            obj.data = struct('packets',struct(),'bytes',struct());
            obj.data.packets = struct('sent',0,'rcvd',0,'relayed',0,'dropped',0,'dups',0);
            obj.data.bytes = struct('sent',0,'rcvd',0,'relayed',0,'dropped',0,'dups',0);
            obj.ctrl = struct('packets',struct(),'bytes',struct());
            obj.ctrl.packets = struct('sent',0,'rcvd',0,'relayed',0,'dropped',0,'dups',0);
            obj.ctrl.bytes = struct('sent',0,'rcvd',0,'relayed',0,'dropped',0,'dups',0);            
            obj.isSender = 0;
            obj.isReceiver = 0;
            obj.groups_tx = [];
            obj.groups_rx = [];
            
            obj.timestamp = 0;
            obj.nonces = containers.Map;
            obj.rtable = RouteTable; 
            obj.rtable.add(id,id,0,id,'N');
            obj.result = 0; 
            
            % here we define protocol messages 
            obj.hbeat = struct('ver',2,'type','HEARTBEAT','hops',obj.maxhops,'ttl',obj.maxhops,...
                'groups',0,'nonce',0,'last',id,'mgroups',[]);
            
            obj.mdata = struct('ver',2,'type','DATA','payload','');
            
            % 'A' is a multicast group id
            if agent == 1
                obj = obj.join_group_receiver('A');
                %obj = obj.insertIntoMessageCache(id,'A',0,id,'R',0);
            elseif agent == 2
                obj = obj.join_group_sender('A',app.packetlen);
                %obj = obj.insertIntoMessageCache(id,'A',0,id,'S',0);
            else
                %obj = obj.insertIntoMessageCache(id,id,0,id,'N',0);
            end
            
            switch app.data
                case 'CBR'
                    obj.dataperiod = app.period;
                otherwise
                    obj.dataperiod = 0;
            end
        end
        
        function obj = join_group_sender(obj, gr, datalen)
            obj.groups_tx = [obj.groups_tx gr];
            obj.datalen = datalen;
            obj.isSender = 1;
            obj.isReceiver = 0;
        end
        
        function obj = join_group_receiver(obj, gr)
            obj.groups_rx = [obj.groups_rx gr];
            obj.isSender = 0;
            obj.isReceiver = 1;
        end   
        
        function obj = join_group_rxtx(obj, gr, datalen)
            obj.datalen = datalen;
            obj.groups_tx = [obj.groups_tx gr];
            obj.groups_rx = [obj.groups_rx gr];
            obj.isSender = 1;
            obj.isReceiver = 1;
        end         
            
        function [hlmrp, pkt] = process_data(hlmrp,pkt)
            
            hlmrp.result = check_ip(hlmrp.id,pkt); % ip level check
            if (hlmrp.result < 0) 
                return;
            elseif strcmpi(pkt.next, hlmrp.protoname) == 0
                hlmrp.result = -4;
            else % custom protocol check
                                  
                if isfield(pkt.appdata,'last') == 1 
                    if strcmpi(num2str(hlmrp.id), num2str(pkt.appdata.last)) == 1
                        hlmrp.result = -5;
                        return;
                    elseif pkt.appdata.hops > hlmrp.maxhops
                        hlmrp.result = -6;
                        return;
                    end
                end
                
                pkt.ttl = pkt.ttl - 1;
                
                type = pkt.getType;
                
                switch (type)
                    case ('HEARTBEAT')                        
                        [hlmrp, pkt] = hlmrp.process_heartbeat(pkt);                        
                    case ('DATA')
                        [hlmrp, pkt] = hlmrp.process_mdata(pkt);
                    otherwise % ignore
                        hlmrp.result = -7;
                end                
            end
        end
        
        function [obj, pkt] = timeout(obj,d,t)
            pkt = [];
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;
            obj.datatimer = obj.datatimer + d;
            
            if (obj.datatimer >= obj.dataperiod && obj.isSender == 1) % data timer, if sender
                %fprintf('sending HLMRP DATA\r\n');
                obj.datatimer = mod(obj.datatimer, d);                
                [obj, pkt] = obj.send_mdata(obj.groups_tx(1));
                obj.result = pkt.len;
            elseif (obj.timer >= obj.period) % heartbeat timer
                %obj.period = obj.period + (obj.peers * 3000); 
                obj.timer = mod(obj.period, d);                
                [obj, pkt] = obj.send_heartbeat(obj.id);                                
                obj.result = pkt.len;
            else
                obj.result = 0;
            end                                     
        end
        
        function [hlmrp, pkt] = send_heartbeat(hlmrp, id)
            % create and fill out IPv6 packet class instance
            pkt = IPv6;             
            pkt.src = hlmrp.id;
            pkt.dst = 0;
            pkt.ttl = hlmrp.maxhops;
            pkt.next = hlmrp.protoname;
            pkt.len = 40 + hlmrp.overhead + (16 * hlmrp.hbeat.groups);
            % HLMRP level
            pkt.appdata = hlmrp.hbeat;
            pkt.appdata.groups = numel(hlmrp.groups_rx);
            pkt.appdata.nonce = randi([0 1000000],1,1);
            pkt.appdata.ttl = hlmrp.maxhops;
            pkt.appdata.hops = hlmrp.maxhops;
            pkt.appdata.last = id;
            pkt.appdata.mgroups = hlmrp.groups_rx;           
            
            % collect stats
            hlmrp.data.packets.sent = hlmrp.data.packets.sent + 1;
            hlmrp.data.bytes.sent = hlmrp.data.bytes.sent + hlmrp.len;  
            
            % remember own nonce to avoid rebroadcast
            hlmrp.nonces(num2str(pkt.appdata.nonce)) = hlmrp.timestamp + 1000;
        end
        
        function [hlmrp, pkt] = send_mdata(hlmrp, gr) 
            % create and fill out IPv6 packet class instance
            pkt = IPv6;             
            pkt.src = hlmrp.id;
            pkt.dst = gr;
            pkt.ttl = hlmrp.maxhops;
            pkt.next = hlmrp.protoname;
            pkt.len = 40 + hlmrp.overhead + hlmrp.datalen;            
            % HLMRP level
            pkt.appdata = hlmrp.mdata;
            pkt.appdata.type = 'DATA';            
            
            % update stats
            hlmrp.data.packets.sent = hlmrp.data.packets.sent + 1;
            hlmrp.data.bytes.sent = hlmrp.data.bytes.sent + hlmrp.len;            
        end 
        
        function [hlmrp, pkt] = process_heartbeat(hlmrp, pkt)
            
            if pkt.appdata.ttl <= 0
                hlmrp.result = -8;
            elseif hlmrp.nonces.isKey(num2str(pkt.appdata.nonce)) == 0 % not known packet, forward it
                hlmrp.nonces(num2str(pkt.appdata.nonce)) = hlmrp.timestamp + 1000;
                pkt.appdata.last = hlmrp.id;
                pkt.appdata.ttl = pkt.appdata.ttl - 1; % HLMRP level TTL                              
                hlmrp.result = pkt.len;
                % collect stats
                hlmrp.ctrl.packets.relayed = hlmrp.ctrl.packets.relayed + 1;
                hlmrp.ctrl.bytes.relayed = hlmrp.ctrl.bytes.relayed + pkt.len;
            else
                hlmrp.result = 0;
                hlmrp.ctrl.packets.dups = hlmrp.ctrl.packets.dups + 1;
                hlmrp.ctrl.bytes.dups = hlmrp.ctrl.bytes.dups + pkt.len;
            end
            hlmrp.removeNonces;
        end
        
        function [hlmrp, pkt] = process_mdata(hlmrp, pkt)
            hlmrp.result = 0;
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

