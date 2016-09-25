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
        debug = 1;             % show protocol packets in the debug window
    end        
    
    properties ( Access = private )
        id
    end
    
    properties
        type  
        seq 
        prev
        protoname
        timestamp
        timer
        fgtimer
        dataseq
        dataperiod
        datatimer
        isSender
        isReceiver
        datalen
        hops
        count
        mgroup
        result
        data
        ctrl
        groups_tx
        groups_rx
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
            obj.seq = 0;
            obj.prev = 0;
            obj.result = 0;
            obj.datalen = 0;
            obj.data = struct('packets',struct(),'bytes',struct());
            obj.data.packets = struct('sent',0,'rcvd',0,'relayed',0,'droped',0,'dups',0);
            obj.data.bytes = struct('sent',0,'rcvd',0,'relayed',0,'droped',0,'dups',0);
            obj.ctrl = struct('packets',struct(),'bytes',struct());
            obj.ctrl.packets = struct('sent',0,'rcvd',0,'relayed',0,'droped',0,'dups',0);
            obj.ctrl.bytes = struct('sent',0,'rcvd',0,'relayed',0,'droped',0,'dups',0);            
            obj.isSender = 0;
            obj.isReceiver = 0;
            obj.groups_tx = [];
            obj.groups_rx = [];
            obj.FORWARDING_GROUP_FLAG = 0;
            obj.protoname = 'ODMRP';
            obj.next = 'ODMRP';
            obj.rtable = RouteTable;
            obj.message_cache = table;
            obj.receiver_table = containers.Map;
            obj.member_table = containers.Map;
            obj.member_cache = table;
            
            % here we define protocol messages 
            jreq = struct('ver',0,'type','JOIN REQ','reserved',0,'ttl',obj.TTL_VALUE,...
                'hops',0,'mgroup','A','seq',0,'src',id,'prev',id);
            
            obj.jreq = jreq;
            
            jtable = struct('ver',0,'type','JOIN TABLE','count',0,'reserved',0,...
                'mgroup',0,'senders',[],'nexts',[]);
            
            obj.jtable = jtable;
            
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
        
        function obj = join_group_rxtx(obj, gr)
            obj.groups_tx = [obj.groups_tx gr];
            obj.groups_rx = [obj.groups_rx gr];
            obj.isSender = 1;
            obj.isReceiver = 1;
        end         
        
        function obj = timeout(obj,d,t)
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;
            obj.fgtimer = obj.fgtimer + d;
            obj.datatimer = obj.datatimer + d;
            if (obj.timer >= obj.MEM_REFRESH && obj.isSender == 1)
                obj.timer = mod(obj.MEM_REFRESH, d);
                s = numel(obj.groups_tx);
                for i=1:s
                    obj = obj.send_join_req(obj.groups_tx(i));                                       
                    obj.result = obj.len;
                end
            elseif (obj.datatimer >= obj.dataperiod && obj.isSender == 1)
                obj.datatimer = mod(obj.datatimer, d);
                obj = obj.send_mdata(obj.groups_tx(1));
                obj.result = obj.len;
                
            elseif (obj.timer >= obj.JT_REFRESH && obj.isReceiver == 1)                
                obj.timer = mod(obj.JT_REFRESH, d);
                if obj.member_table.Count > 0
                    obj = obj.send_join_table(obj.groups_rx(1));  % just 1 multicast group so far                                     
                    obj.result = obj.len;
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
        
        function obj = send_join_req(obj, gr)                     
            % IP level
            obj.src = obj.id;
            obj.dst = 0;
            obj.ttl = obj.TTL_VALUE;
            obj.next = obj.protoname;
            % ODMRP level
            obj.jreq.ttl = obj.TTL_VALUE;
            obj.jreq.hops = 0;
            obj.jreq.mgroup = gr;
            obj.jreq.seq = obj.jreq.seq + 1;
            obj.type = obj.jreq.type;
            obj.len = 56;
            % update own message cache
            rows = strcmpi(obj.message_cache.src, num2str(obj.id));             
            obj.message_cache(rows,:).seq = obj.jreq.seq;
            % update visualization params
            obj.seq = obj.jreq.seq;
            obj.hops = 0;
            obj.prev = obj.jreq.prev;
            % update stats
            obj.ctrl.packets.sent = obj.ctrl.packets.sent + 1;
            obj.ctrl.bytes.sent = obj.ctrl.bytes.sent + obj.len;
        end
        
        function obj = send_join_table(obj, gr)                     
            % IP level
            obj.src = obj.id;
            obj.dst = 0;
            obj.ttl = obj.TTL_VALUE;
            obj.next = obj.protoname;
            % ODMRP level
            obj.type = obj.jtable.type;
            obj.jtable.count = (obj.member_table.Count);
            obj.jtable.reserved = randi([0 10000000],1,1);
            obj.jtable.mgroup = gr;
            pkeys = obj.member_table.keys;
            len = obj.member_table.Count;
            obj.jtable.senders = [];
            obj.jtable.nexts = [];
            for p=1:len
                key = pkeys(p);
                peer = obj.member_table(char(key));
                obj.jtable.senders = [obj.jtable.senders peer.src];
                obj.jtable.nexts = [obj.jtable.nexts peer.next];
            end 
            obj.len = 60 + (32 * len);
            % update own message cache

            % update visualization params
            obj.count = obj.jtable.count;
            obj.mgroup = 'A';
            % update stats
            obj.ctrl.packets.sent = obj.ctrl.packets.sent + 1;
            obj.ctrl.bytes.sent = obj.ctrl.bytes.sent + obj.len;            
        end 

        function obj = send_mdata(obj, gr)                     
            % IP level
            obj.src = obj.id;
            obj.dst = gr;
            obj.ttl = obj.TTL_VALUE;
            obj.next = obj.protoname;
            obj.len = 40 + obj.datalen;
            % ODMRP level
            obj.type = 'DATA';
            obj.dataseq = obj.data.packets.sent + 1;
            
            % update visualization params
            obj.mgroup = 'A';
            obj.prev = obj.id;
            
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
                
                switch (pkt.type)
                    case ('JOIN REQ')    
                        odmrp = odmrp.process_join_req(pkt);   
                        %fprintf('%d processed JREQ, seq=%d, res=%d\n', odmrp.id, pkt.jreq.seq, odmrp.result);
                    case ('JOIN TABLE')
                        odmrp = odmrp.process_join_table(pkt);
                        %fprintf('%d join_table (%d) processed with res=%d\n', odmrp.id, pkt.jtable.reserved, odmrp.result);
                    case ('DATA')
                        odmrp  = odmrp.process_mdata(pkt);
                        %fprintf('%d data processed with res=%d\n', odmrp.id, odmrp.result);
                    otherwise
                        % ignore
                        %fprintf('unknown type: %d\n',pkt.type);
                        odmrp.result = 0;
                end                
            end
        end
        
        function odmrp = process_join_req(odmrp, pkt)            
            % ODMRP DRAFT, page 26
            % 5.1.2 Processing Join Request
            %
            odmrp.ctrl.packets.rcvd = odmrp.ctrl.packets.rcvd + 1;
            odmrp.ctrl.bytes.rcvd = odmrp.ctrl.bytes.rcvd + pkt.len;
            
            % 1. Check if duplicate
            if odmrp.containsMessageCache(pkt.src, pkt.jreq.mgroup) == 0
                % 2. If not duplicate insert or update
                % flags:
                % S - sender
                % R - receiver
                % F - forwarding group member
                % N - simple node
                %
                %fprintf('inserting into message cache group=%s\n', pkt.jreq.mgroup);
                odmrp = odmrp.insertIntoMessageCache(pkt.src, pkt.jreq.mgroup, pkt.jreq.seq, pkt.jreq.prev, 'S', pkt.jreq.hops+1);
            else
                rows = strcmpi(odmrp.message_cache.src, num2str(pkt.src));
                %fprintf('%d updating message cache, rows=%d, pkt.seq=%d, odmrp.seq=%d\n', odmrp.id, sum(rows), pkt.jreq.seq, (odmrp.message_cache(rows,:).seq));
                if(odmrp.message_cache(rows,:).seq < pkt.jreq.seq)
                    % update seq                    
                    odmrp.message_cache(rows,:).seq = pkt.jreq.seq;
                    %fprintf('updated\n');
                else
                    %fprintf('old value\n');
                    odmrp.ctrl.packets.droped = odmrp.ctrl.packets.droped + 1;
                    odmrp.ctrl.bytes.droped = odmrp.ctrl.bytes.droped + pkt.len;                     
                    odmrp.result = -10;
                    return
                end
            end
            
            % 3. If node is a receiver
            %if --- ismember(pkt.jreq.mgroup, odmrp.groups_rx)
            %if odmrp.isSender == 0
                % insert/update Member Table
                odmrp.updateMemberTable(pkt.src, pkt.jreq.mgroup, pkt.jreq.prev, pkt.jreq.seq);
                % originate JOIN_TABLE
                %odmrp.timer = odmrp.JT_REFRESH;
            %end
            
            % 4. Hop Count++
            pkt.jreq.hops = pkt.jreq.hops + 1;
            
            % 5. Hop count >= TTL ? DROP
            if pkt.jreq.hops > odmrp.TTL_VALUE
                odmrp.ctrl.packets.droped = odmrp.ctrl.packets.droped + 1;
                odmrp.ctrl.bytes.droped = odmrp.ctrl.bytes.droped + pkt.len;                
                odmrp.result = -20;
            else % 6. Relay
                pkt.len = 56;
                pkt.ttl = odmrp.TTL_VALUE - pkt.jreq.hops;
                pkt.jreq.prev = odmrp.id;
                odmrp.jreq = pkt.jreq;
                odmrp.src = pkt.src;
                odmrp.dst = pkt.dst;
                odmrp.ttl = pkt.ttl;
                odmrp.type = pkt.jreq.type;
                odmrp.seq = pkt.jreq.seq;
                odmrp.prev = pkt.jreq.prev;
                odmrp.hops = pkt.jreq.hops;
                odmrp.result = pkt.len;
                % collect stats
                odmrp.ctrl.packets.relayed = odmrp.ctrl.packets.relayed + 1;
                odmrp.ctrl.bytes.relayed = odmrp.ctrl.bytes.relayed + pkt.len;
            end 
        end
        
        function odmrp = process_join_table(odmrp, pkt)
            % ODMRP DRAFT, page 28
            % 5.1.4 Processing Join Table 
            % 1. The node looks up to the next hop
            if ismember(odmrp.id, pkt.jtable.nexts)
                % +++ reserved => nonce
                if odmrp.updateReceiverTable(pkt.jtable.reserved) == 1               
                     odmrp.result = 0;
                     odmrp.ctrl.packets.droped = odmrp.ctrl.packets.droped + 1;
                     odmrp.ctrl.bytes.droped = odmrp.ctrl.bytes.droped + pkt.len;
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
                    odmrp = odmrp.send_join_table(pkt.jtable.mgroup);
                    odmrp.jtable.reserved = pkt.jtable.reserved; % keep the same nonce when relayed
                    odmrp.fgtimer = 0;
                    odmrp.ttl = odmrp.ttl - 1;
                    odmrp.prev = odmrp.id;
                    odmrp.result = pkt.len;
                    % collect stats
                    odmrp.ctrl.packets.relayed = odmrp.ctrl.packets.relayed + 1;
                    odmrp.ctrl.bytes.relayed = odmrp.ctrl.bytes.relayed + pkt.len;                
                    %fprintf('%d relay join table for %d\n', odmrp.id, pkt.id);
                end
            else
                odmrp.result = -6;
                odmrp.ctrl.packets.droped = odmrp.ctrl.packets.droped + 1;
                odmrp.ctrl.bytes.droped = odmrp.ctrl.bytes.droped + pkt.len;                 
                %fprintf('%d join table dropped for %d\n', odmrp.id, pkt.id);
            end            
        end        
        
        function odmrp = process_mdata(odmrp, pkt) 
            
            if odmrp.containsMemberCache(pkt.src,'A') == 0
                odmrp = odmrp.insertIntoMemberCache(pkt.src,'A',pkt.dataseq);
            else
                rows = strcmpi(odmrp.member_cache.src, num2str(pkt.src));
                if odmrp.member_cache(rows,:).seq < pkt.dataseq;                    
                    odmrp.member_cache(rows,:).seq = pkt.dataseq;
                    if odmrp.isReceiver == 1
                        odmrp.data.packets.rcvd = odmrp.data.packets.rcvd + 1;
                        odmrp.data.bytes.rcvd = odmrp.data.bytes.rcvd + pkt.len; 
                    end
                else
                    odmrp.data.packets.dups = odmrp.data.packets.dups + 1;
                    odmrp.data.bytes.dups = odmrp.data.bytes.dups + pkt.len;
                    odmrp.result = 0;
                    return
                end
            end
            
            if odmrp.FORWARDING_GROUP_FLAG == 1
                odmrp.src = pkt.src;
                odmrp.dst = pkt.dst;
                odmrp.ttl = pkt.ttl;
                odmrp.type = pkt.type;
                odmrp.dataseq = pkt.dataseq;
                odmrp.len = pkt.len;
                odmrp.result = pkt.len;
                % collect stats
                odmrp.data.packets.relayed = odmrp.data.packets.relayed + 1;
                odmrp.data.bytes.relayed = odmrp.data.bytes.relayed + pkt.len;
            else
                odmrp.data.packets.droped = odmrp.data.packets.droped + 1;
                odmrp.data.bytes.droped = odmrp.data.bytes.droped + pkt.len;                
                odmrp.result = 0;    
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

