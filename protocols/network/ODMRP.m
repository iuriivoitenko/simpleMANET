classdef ODMRP < IPv6
    % ODMRP Summary of this class goes here
    % This class represents ODMRP protocol logic taken from 
    % www.cs.ucla.edu/classes/fall03/cs218/paper/odmrp-wcnc99.pdf
    properties (Constant)
        FG_TIMEOUT = 880;
        HELLO_INTERVAL = 1000;
        HELLO_TIMEOUT_INTERVAL = 3000;
        JT_REFRESH = 160;
        MEM_REFRESH = 400;
        MEM_TIMEOUT = 960;
        RTE_TIMEOUT = 960;
        RT_DISCV_TIMEOUT = 30000;
        TTL_VALUE = 32;
        version = 0;
        overhead = 64;
        msender = [1 0 0];
        mnode = [1 1 0];
        mreceiver = [33 205 163] ./ 255;
        show = 1;             % show protocol packets in the debug window
    end        
    
    properties ( Access = private )
        id
    end
    
    properties
%         type  
%         seq 
%         prev
        protoname
        timestamp
        timer
        fgtimer
        %dataseq
        dataperiod
        datatimer
        isSender
        isReceiver
        datalen
        %hops
        %count
        %mgroup                       
        result
        data
        ctrl
        groups_tx
        groups_rx
        mdata
        jreq        
        jtable
        rtable
        FORWARDING_GROUP_FLAG
        message_cache
        member_table
        member_cache
        receiver_table
    end
    
    methods
        function obj = ODMRP(id, agent, app)
            obj.id = id;
            obj.timer = 0;
            obj.fgtimer = 0;
            obj.dataperiod = 0;
            obj.datatimer = 0;
            obj.result = 0;
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
            obj.FORWARDING_GROUP_FLAG = 0;
            obj.protoname = 'ODMRP';
            obj.rtable = RouteTable;
            obj.message_cache = table;
            obj.receiver_table = containers.Map;
            obj.member_table = containers.Map;
            obj.member_cache = table;
            
            % here we define protocol messages 
            obj.jreq = struct('ver',0,'type','JOIN REQ','reserved',0,'ttl',obj.TTL_VALUE,...
                'hops',0,'mgroup','A','seq',0,'src',id,'prev',id);            
            
            obj.jtable = struct('ver',0,'type','JOIN TABLE','count',0,'reserved',0,...
                'mgroup',0,'senders',[],'nexts',[]);           
            
            obj.mdata = struct('ver',0,'type','DATA','dataseq',0,'prev',id,'payload','');
            
            % 'A' is a multicast group id
            if agent == 1
                obj = obj.join_group_receiver('A');
                obj = obj.insertIntoMessageCache(id,'A',0,id,'R',0);
            elseif agent == 2
                obj = obj.join_group_sender('A',app.packetlen);
                obj = obj.insertIntoMessageCache(id,'A',0,id,'S',0);
            else
                obj = obj.insertIntoMessageCache(id,id,0,id,'N',0);
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
            obj.groups_tx = [obj.groups_tx gr];
            obj.groups_rx = [obj.groups_rx gr];
            obj.datalen = datalen;
            obj.isSender = 1;
            obj.isReceiver = 1;
        end         
        
        function [obj, pkt] = timeout(obj,d,t)
            pkt = [];
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;
            obj.fgtimer = obj.fgtimer + d;
            obj.datatimer = obj.datatimer + d;
            if (obj.timer >= obj.MEM_REFRESH && obj.isSender == 1)
                obj.timer = mod(obj.MEM_REFRESH, d);
                s = numel(obj.groups_tx);
                for i=1:s
                    [obj, pkt] = obj.send_join_req(obj.groups_tx(i));                                       
                    obj.result = pkt.len;
                end
            elseif (obj.datatimer >= obj.dataperiod && obj.isSender == 1)
                obj.datatimer = mod(obj.datatimer, d);
                [obj, pkt] = obj.send_mdata(obj.groups_tx(1));
                obj.result = pkt.len;
                
            elseif (obj.timer >= obj.JT_REFRESH && obj.isReceiver == 1)                
                obj.timer = mod(obj.JT_REFRESH, d);
                if obj.member_table.Count > 0
                    [obj, pkt] = obj.send_join_table(obj.groups_rx(1));  % just 1 multicast group so far                                     
                    obj.result = pkt.len;
                end                
            else
                obj.result = 0;
            end 
            if obj.fgtimer >= obj.FG_TIMEOUT
                obj.fgtimer = mod(obj.FG_TIMEOUT, d);
                obj.FORWARDING_GROUP_FLAG = 0;
                rows = strcmpi(obj.message_cache.src, num2str(obj.id));                
                if obj.isSender == 1
                    obj.message_cache(rows,:).flags = {'S'};
                elseif obj.isReceiver == 1
                    obj.message_cache(rows,:).flags = {'R'};
                else
                    obj.message_cache(rows,:).flags = {'N'};
                end                
            end
            obj.removeExpiredMembers();
            obj.removeExpiredReceivers();
        end
        
        function [obj, pkt] = send_join_req(obj, gr)                     
            % create and fill out IPv6 packet class instance
            pkt = IPv6;             
            pkt.src = obj.id;
            pkt.dst = 0;
            pkt.ttl = obj.TTL_VALUE;
            pkt.next = obj.protoname;
            pkt.len = 40 + obj.overhead;
            
            % ODMRP level
            obj.jreq.seq = obj.jreq.seq + 1;
            pkt.appdata = obj.jreq;
            pkt.appdata.jreq.ttl = obj.TTL_VALUE;
            pkt.appdata.jreq.hops = 0;
            pkt.appdata.jreq.mgroup = gr;   
            pkt.appdata.jreq.seq = obj.jreq.seq;
            pkt.appdata.jreq.prev = obj.id;  
            
            % update own message cache
            rows = strcmpi(obj.message_cache.src, num2str(obj.id));             
            obj.message_cache(rows,:).seq = obj.jreq.seq;
            
            % update stats
            obj.ctrl.packets.sent = obj.ctrl.packets.sent + 1;
            obj.ctrl.bytes.sent = obj.ctrl.bytes.sent + obj.len;
        end
        
        function [obj, pkt] = send_join_table(obj, gr)                     
            % create and fill out IPv6 packet class instance
            pkt = IPv6;             
            pkt.src = obj.id;
            pkt.dst = 0;
            pkt.ttl = obj.TTL_VALUE;
            pkt.next = obj.protoname;
            pkt.len = 40 + obj.overhead;
            
            % special type-dependent ODMRP packet fields
            pkt.appdata = obj.jtable;
            pkt.appdata.jtable.count = (obj.member_table.Count);
            pkt.appdata.jtable.reserved = randi([0 10000000],1,1);
            pkt.appdata.jtable.mgroup = gr;
            pkeys = obj.member_table.keys;
            len = obj.member_table.Count;
            pkt.appdata.jtable.senders = [];
            pkt.appdata.jtable.nexts = [];
            for p=1:len
                key = pkeys(p);
                peer = obj.member_table(char(key));
                pkt.appdata.jtable.senders = [obj.jtable.senders peer.src];
                pkt.appdata.jtable.nexts = [obj.jtable.nexts peer.next];
            end 
            pkt.len = pkt.len + (32 * len);

            % update stats
            obj.ctrl.packets.sent = obj.ctrl.packets.sent + 1;
            obj.ctrl.bytes.sent = obj.ctrl.bytes.sent + obj.len;            
        end 

        function [obj, pkt] = send_mdata(obj, gr)  
            % create and fill out IPv6 packet class instance
            pkt = IPv6;             
            pkt.src = obj.id;
            pkt.dst = gr;
            pkt.ttl = obj.TTL_VALUE;
            pkt.next = obj.protoname;
            pkt.len = 40 + obj.overhead + obj.datalen;
            
            % special type-dependent ODMRP packet fields
            pkt.appdata = obj.mdata;
            pkt.appdata.dataseq = obj.data.packets.sent + 1;
            
            % update stats
            obj.data.packets.sent = obj.data.packets.sent + 1;
            obj.data.bytes.sent = obj.data.bytes.sent + obj.len;            
        end         
        
        function [odmrp, pkt] = process_data(odmrp,pkt)
            
            odmrp.result = check_ip(odmrp.id,pkt); % ip level check
            if (odmrp.result < 0 && ismember(char(pkt.dst), odmrp.groups_rx) == 0 && odmrp.isReceiver == 1) 

            elseif odmrp.result < 0 && ismember(char(pkt.dst), odmrp.groups_tx) == 1 
                
            elseif strcmpi(pkt.next, odmrp.protoname) == 0
                odmrp.result = -4;
            else % custom protocol check
                                               
                pkt.ttl = pkt.ttl - 1;
                
                type = pkt.getType;
                
                switch (type)
                    case ('JOIN REQ')    
                        [odmrp, pkt] = odmrp.process_join_req(pkt);   
                        fprintf('node %d processed JREQ, seq=%d, res=%d\n', odmrp.id, pkt.appdata.jreq.seq, odmrp.result);
                    case ('JOIN TABLE')
                        [odmrp, pkt] = odmrp.process_join_table(pkt);
                        fprintf('node %d join_table (%d) processed with res=%d\n', odmrp.id, pkt.appdata.jtable.reserved, odmrp.result);
                    case ('DATA')
                        [odmrp, pkt]  = odmrp.process_mdata(pkt);
                        fprintf('node %d data processed with res=%d\n', odmrp.id, odmrp.result);
                    otherwise
                        % ignore
                        fprintf('unknown type: %d\n',pkt.type);
                        odmrp.result = -5;
                end                
            end
        end
        
        function [odmrp, pkt] = process_join_req(odmrp, pkt)            
            % ODMRP DRAFT, page 26
            % 5.1.2 Processing Join Request
            %
            odmrp.ctrl.packets.rcvd = odmrp.ctrl.packets.rcvd + 1;
            odmrp.ctrl.bytes.rcvd = odmrp.ctrl.bytes.rcvd + pkt.len;
            
            % 1. Check if duplicate
            if odmrp.containsMessageCache(pkt.src, pkt.appdata.jreq.mgroup) == 0
                % 2. If not duplicate insert or update
                % flags:
                % S - sender
                % R - receiver
                % F - forwarding group member
                % N - simple node
                %
                %fprintf('inserting into message cache group=%s\n', pkt.jreq.mgroup);
                odmrp = odmrp.insertIntoMessageCache(pkt.src, pkt.appdata.jreq.mgroup, pkt.appdata.jreq.seq, pkt.appdata.jreq.prev, 'S', pkt.appdata.jreq.hops+1);
            else
                rows = strcmpi(odmrp.message_cache.src, num2str(pkt.src));
                %fprintf('%d updating message cache, rows=%d, pkt.seq=%d, odmrp.seq=%d\n', odmrp.id, sum(rows), pkt.jreq.seq, (odmrp.message_cache(rows,:).seq));
                if(odmrp.message_cache(rows,:).seq < pkt.appdata.jreq.seq)
                    % update seq                    
                    odmrp.message_cache(rows,:).seq = pkt.appdata.jreq.seq;
                    %fprintf('updated\n');
                else
                    %fprintf('old value\n');
                    odmrp.ctrl.packets.dropped = odmrp.ctrl.packets.dropped + 1;
                    odmrp.ctrl.bytes.dropped = odmrp.ctrl.bytes.dropped + pkt.len;                     
                    odmrp.result = -6;
                    return
                end
            end
            
            % 3. If node is a receiver
            %if --- ismember(pkt.jreq.mgroup, odmrp.groups_rx)
            %if odmrp.isSender == 0
                % insert/update Member Table
                odmrp.updateMemberTable(pkt.src, pkt.appdata.jreq.mgroup, pkt.appdata.jreq.prev, pkt.appdata.jreq.seq);
                % originate JOIN_TABLE
                %odmrp.timer = odmrp.JT_REFRESH;
            %end
            
            % 4. Hop Count++
            pkt.appdata.jreq.hops = pkt.appdata.jreq.hops + 1;
            
            % 5. Hop count >= TTL ? DROP
            if pkt.appdata.jreq.hops > odmrp.TTL_VALUE
                odmrp.ctrl.packets.dropped = odmrp.ctrl.packets.dropped + 1;
                odmrp.ctrl.bytes.dropped = odmrp.ctrl.bytes.dropped + pkt.len;                
                odmrp.result = -7;
            else % 6. Relay
                pkt.ttl = odmrp.TTL_VALUE - pkt.appdata.jreq.hops;
                pkt.appdata.jreq.prev = odmrp.id;
%                 odmrp.jreq = pkt.jreq;
%                 odmrp.src = pkt.src;
%                 odmrp.dst = pkt.dst;
%                 odmrp.ttl = pkt.ttl;
%                 odmrp.type = pkt.jreq.type;
%                 odmrp.seq = pkt.jreq.seq;
%                 odmrp.prev = pkt.jreq.prev;
%                 odmrp.hops = pkt.jreq.hops;
                
                % collect stats
                odmrp.ctrl.packets.relayed = odmrp.ctrl.packets.relayed + 1;
                odmrp.ctrl.bytes.relayed = odmrp.ctrl.bytes.relayed + pkt.len;
                odmrp.result = pkt.len;
            end 
        end
        
        function [odmrp, pkt] = process_join_table(odmrp, pkt)
            % ODMRP DRAFT, page 28
            % 5.1.4 Processing Join Table 
            % 1. The node looks up to the next hop
            if ismember(odmrp.id, pkt.appdata.jtable.nexts)
                % +++ reserved => nonce
                if odmrp.updateReceiverTable(pkt.appdata.jtable.reserved) == 1                                    
                     odmrp.ctrl.packets.dropped = odmrp.ctrl.packets.dropped + 1;
                     odmrp.ctrl.bytes.dropped = odmrp.ctrl.bytes.dropped + pkt.len;
                     odmrp.result = -8;
                     return
                end
               
                % collect stats
                odmrp.ctrl.packets.rcvd = odmrp.ctrl.packets.rcvd + 1;
                odmrp.ctrl.bytes.rcvd = odmrp.ctrl.bytes.rcvd + pkt.len;
                % set forwarding flag = 1 and originate own Join Table
                odmrp.FORWARDING_GROUP_FLAG = 1;  
                rows = strcmpi(odmrp.message_cache.src, num2str(odmrp.id));
                if odmrp.isSender == 1
                    odmrp.message_cache(rows,:).flags = {'SF'};
                elseif odmrp.isReceiver == 1
                    odmrp.message_cache(rows,:).flags = {'RF'};
                else
                    odmrp.message_cache(rows,:).flags = {'NF'};
                end
                
                if odmrp.member_table.Count > 0
                    %odmrp = odmrp.send_join_table(pkt.jtable.mgroup);
                    %odmrp.jtable.reserved = pkt.jtable.reserved; % keep the same nonce when relay
                    odmrp.fgtimer = 0;
                    %pkt.ttl = pkt.ttl - 1;
                    %odmrp.prev = odmrp.id;
                    
                    % collect stats
                    odmrp.ctrl.packets.relayed = odmrp.ctrl.packets.relayed + 1;
                    odmrp.ctrl.bytes.relayed = odmrp.ctrl.bytes.relayed + pkt.len;                
                    odmrp.result = pkt.len;
                    %fprintf('%d relay join table for %d\n', odmrp.id, pkt.id);
                else
                    odmrp.result = 0;
                end
            else                
                odmrp.ctrl.packets.dropped = odmrp.ctrl.packets.dropped + 1;
                odmrp.ctrl.bytes.dropped = odmrp.ctrl.bytes.dropped + pkt.len;                 
                odmrp.result = -9;
                %fprintf('%d join table dropped for %d\n', odmrp.id, pkt.id);
            end            
        end        
        
        function [odmrp, pkt] = process_mdata(odmrp, pkt) 
            
            droppkt = 1;
            
            if odmrp.containsMemberCache(pkt.src,'A') == 0
                odmrp = odmrp.insertIntoMemberCache(pkt.src,'A',pkt.appdata.dataseq);
            else
                rows = strcmpi(odmrp.member_cache.src, num2str(pkt.src));
                if odmrp.member_cache(rows,:).seq < pkt.appdata.dataseq                   
                    odmrp.member_cache(rows,:).seq = pkt.appdata.dataseq;
                    if odmrp.isReceiver == 1
                        odmrp.data.packets.rcvd = odmrp.data.packets.rcvd + 1;
                        odmrp.data.bytes.rcvd = odmrp.data.bytes.rcvd + pkt.len;
                        droppkt = 0;
                    end
                else
                    odmrp.data.packets.dups = odmrp.data.packets.dups + 1;
                    odmrp.data.bytes.dups = odmrp.data.bytes.dups + pkt.len;
                    odmrp.result = -10;
                    return
                end
            end
            
            if odmrp.FORWARDING_GROUP_FLAG == 1
%                 odmrp.src = pkt.src;
%                 odmrp.dst = pkt.dst;
%                 odmrp.ttl = pkt.ttl;
%                 odmrp.type = pkt.type;
%                 odmrp.dataseq = pkt.appdata.dataseq;
%                 odmrp.len = pkt.len;
                odmrp.result = pkt.len;
                % collect stats
                odmrp.data.packets.relayed = odmrp.data.packets.relayed + 1;
                odmrp.data.bytes.relayed = odmrp.data.bytes.relayed + pkt.len;
            else
                if droppkt == 1
                    odmrp.data.packets.dropped = odmrp.data.packets.dropped + 1;
                    odmrp.data.bytes.dropped = odmrp.data.bytes.dropped + pkt.len;                
                    odmrp.result = -11;    
                else
                    odmrp.result = 0;    
                end
                
            end            
        end
        
        function obj = removeExpiredMembers(obj)
            pkeys = obj.member_table.keys;
            len = obj.member_table.length;
            for p=1:len
                key = pkeys(p);
                peer = obj.member_table(char(key));
                if (peer.expire < obj.timestamp)
                    %fprintf('%d removing peer %s\n', (obj.id), num2str(peer.id));
                    obj.member_table.remove(pkeys(p));
                end
            end 
        end
        % Added to DRAFT by I.V.
        function obj = removeExpiredReceivers(obj)
            pkeys = obj.receiver_table.keys;
            len = obj.receiver_table.length;
            for p=1:len
                key = pkeys(p);
                peer = obj.receiver_table(char(key));
                if (peer.expire < obj.timestamp)
                    %fprintf('%d removing peer %s\n', (obj.id), num2str(peer.id));
                    obj.receiver_table.remove(pkeys(p));
                end
            end 
        end        
               
        function out = updateMemberTable(obj,src,group,next,seq)   
                       
            if obj.member_table.isKey(num2str(src)) % known      
                out = 1;
            else % new node
                out = 0;
            end
            peer = struct('src',src,'group',group,'next',0,'expire',0,'seq',0);
            peer.expire = obj.timestamp + obj.MEM_TIMEOUT;
            peer.seq = seq;
            peer.next = next;
            obj.member_table(num2str(src)) = peer; 
        end        
        
        function odmrp = insertIntoMessageCache(odmrp,src,group,seq,prev,flags,hops)
            
            if ~ischar(src) && isnumeric(src)
                src = num2str(src);
            end
            
            if ~ischar(group) && isnumeric(group)
                group = num2str(group);
            end
            
            if ~ischar(flags)
                flags = num2str(flags);
            end            
            
            entry = {{src}, {group}, seq, prev, {flags}, hops};
            t2 = cell2table(entry,...
            'VariableNames',{'src','mgroup','seq','prev','flags','hops'});
            t2.Properties.RowNames = strcat(t2.src,'-',t2.mgroup);
            odmrp.message_cache = [odmrp.message_cache; t2];
            odmrp.message_cache = unique(odmrp.message_cache);
        end
        
        function odmrp = insertIntoMemberCache(odmrp,src,group,seq)
            
            if ~ischar(src) && isnumeric(src)
                src = num2str(src);
            end
            
            if ~ischar(group) && isnumeric(group)
                group = num2str(group);
            end         
            
            entry = {{src}, {group}, seq};
            t2 = cell2table(entry,...
            'VariableNames',{'src','mgroup','seq'});
            t2.Properties.RowNames = strcat(t2.src,'-',t2.mgroup);
            odmrp.member_cache = [odmrp.member_cache; t2];
            odmrp.member_cache = unique(odmrp.member_cache);
        end
        
        function out = containsMessageCache(obj,src,group)   
            
            if isempty(obj.message_cache)
                out = 0;
                return
            end
            
            if ~ischar(src) && isnumeric(src)
                src = num2str(src);
            end         
            
            rows = strcmpi(obj.message_cache.src, src);
            h = strcmpi(obj.message_cache.mgroup, group);
            rr = rows & h;
            if sum(rr) > 0
                out = 1;
            else
                out = 0;
            end
        end
        
        function out = containsMemberCache(obj,src,group)   
            
            if isempty(obj.member_cache)
                out = 0;
                return
            end
            
            if ~ischar(src) && isnumeric(src)
                src = num2str(src);
            end         
            
            rows = strcmpi(obj.member_cache.src, src);
            h = strcmpi(obj.member_cache.mgroup, group);
            rr = rows & h;
            if sum(rr) > 0
                out = 1;
            else
                out = 0;
            end
        end       
        
        function out = updateReceiverTable(obj,nonce)
            if obj.receiver_table.isKey(num2str(nonce)) % known      
                out = 1;
            else % new node               
                peer = struct('nonce',nonce,'expire',0);
                peer.expire = obj.timestamp + obj.MEM_TIMEOUT; 
                obj.receiver_table(num2str(nonce)) = peer;
                out = 0;
            end            
        end        
        
        function out = colorNode(obj)
            if obj.isSender
                  out = obj.msender;
            elseif obj.isReceiver
                  out = obj.mreceiver;
            else
                  out = obj.mnode;
            end            
        end        
       
    end
    
end

