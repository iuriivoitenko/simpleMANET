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
 
classdef Neighbor < ProtocolIP
    % Neighbor Summary of this class goes here
    % This class represents 1-hop neighbor discovery and clastering
    properties (Constant)
        cl_node_color = [1 0 0];
        cl_gate_color = [1 1 0];
        cl_lead_color = [33 205 163] ./ 255;
        neighlifetime = 15000; % neighbor valid, ms
    end
    
    properties ( Access = private )
        id                     % same id as node        
        period                 % timeout interval, ms
    end
    
    properties        
        type
        timer          % current timer tick value
        result
        packets        % protocol packets statistics
        bytes          % protocol byte statistics
        hello          % struct for hello packet
        advert         % struct for outgoing advert packet
        protoname      % port bound to this service or any other id to distinguish this service from another
        timestamp      % local time 
        metric         % cluster metric
        cluster        % 2 - leader, 1 - gateway, 0 - node
        battery        % battery level, %
        peers          % total neighbors  
        ids            % cluster ids i belong to
        peerlist       % peers id
        rtable 
    end
    
    methods
        
        function obj = Neighbor(id)
            obj.id = id;
            obj.type;
            obj.protoname = 'NEIGHBOR';
            obj.period = 3000;
            obj.timer = 0;
            obj.timestamp = 0;
            obj.packets = struct('sent',0,'rcvd',0,'droped',0,'dups',0);
            obj.bytes = struct('sent',0,'rcvd',0,'droped',0,'dups',0);             
            obj.hello = struct('type','HELLO','seq',0,'cluster',0,'peers',0,'metric',0,'ids',[],'peerlist',[]);
            obj.advert = struct('type','ADVERT','seq',0,'cluster',0,'peers',0,'metric',0,'ids',[]);
            obj.metric = id;
            obj.cluster = Cluster.LEADER;
            obj.battery = 100;
            obj.peers = 0;
            obj.ids = []; 
            obj.peerlist = containers.Map;
            obj.rtable = RouteTable; 
            obj.rtable.add(id,id,0,id,'L');
            obj.ids = id;
            obj.result = 0;
        end
        
        function proto = process_data(proto,pkt)
            
            proto.result = check_ip(proto.id, pkt); % ip level check
            if (proto.result < 0) 
                proto.packets.droped = proto.packets.droped + 1; 
                proto.bytes.droped = proto.bytes.droped + pkt.len;
            elseif strcmpi(pkt.next, proto.protoname) == 0
                proto.packets.droped = proto.packets.droped + 1;
                proto.bytes.droped = proto.bytes.droped + pkt.len;
                proto.result = -4;
            else % custom protocol check
                                               
                pkt.ttl = pkt.ttl - 1;
                
                switch (pkt.type)
                    case ('HELLO')                        
                        % reply with ADVRT, if not known 
                        proto = proto.processHello(pkt.src, pkt.len, pkt.hello);
                        if  proto.result > 0
                            proto = proto.advertise(pkt);   
                        end
                        
                    case ('ADVERT')   
                        % collect neighbors and update rtable, if seq                        
                        if proto.hello.seq == pkt.advert.seq                             
                            proto = proto.processAdvert(pkt.src, pkt.len, pkt.advert); 
                        else
                            proto.packets.dups = proto.packets.dups + 1;
                            proto.bytes.dups = proto.bytes.dups + pkt.len;
                        end
                        
                        proto.result = 0;           
                    otherwise
                        % collect stats and discard silently
                        proto.packets.droped = proto.packets.droped + 1;
                        proto.bytes.droped = proto.bytes.droped + pkt.len;
                        proto.result = 0;
                end                
            end
        end
        
        function obj = timeout(obj,d,t)
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;
            if (obj.timer >= obj.period)
                obj = obj.send_hello();
                obj.timer = mod(obj.period, d);
                %obj.period = obj.period + (obj.peers * 3000); 
                obj.result = obj.len;
            else
                obj.result = 0;
            end            
        end
        
        function obj = send_hello(obj)                        
            
            obj = obj.clusterUpdate();
            
            % IP level
            obj.src = obj.id;
            obj.dst = 0; % 0 - broadcast
            obj.ttl = 1;
            obj.len = 80;
            obj.next = obj.protoname;
            
            % custom proto level
            % fill HELLO packet struct
            % Normally this is what we send out to the network            
            obj.type = 'HELLO';
            obj.peers = obj.rtable.neighbors();
            obj.hello.seq = obj.hello.seq + 1; % unique nonce
            obj.hello.cluster = obj.cluster;
            obj.hello.peers = obj.rtable.neighbors();
            obj.hello.metric = obj.metric;
            obj.hello.ids = obj.ids;
            obj.hello.peerlist = obj.peerlist.keys;
            
            % update stats
            obj.packets.sent = obj.packets.sent + 1;
            obj.bytes.sent = obj.bytes.sent + obj.len; 
        end
        
        function obj = processHello(obj, src, len, hello)
            if ismember(num2str(obj.id), hello.peerlist) == 0
                obj.result = 1;
            else
                %fprintf('%d prolonging peer %s \n', (obj.id), num2str(src));
                if obj.peerlist.isKey(num2str(src))
                    peer = obj.peerlist(num2str(src));
                    peer.expire = obj.timestamp + obj.neighlifetime;
                    peer.cluster = hello.cluster;
                    peer.metric = hello.metric;
                    peer.peers = hello.peers;
                    peer.ids = hello.ids;
                    obj.peerlist(num2str(src)) = peer;
                    %fprintf('prolonged till %d\n', peer.expire);
                    
                    if obj.rtable.contains(src,1) == 1
                        switch hello.cluster
                            case Cluster.LEADER
                                flags = 'L';
                            case Cluster.GATEWAY
                                flags = 'G';
                            case Cluster.NODE
                                flags = 'N';
                            otherwise                  
                        end                        
                        %fprintf('%d rtable hello update %s, M=%d, F=%s\n', (obj.id), num2str(src), hello.metric, flags);
                        obj.rtable.updateMetric(src, hello.metric);
                        obj.rtable.updateFlags(src, flags);
                        %obj.rtable.show                        
                    end                    
                end                
                obj.result = 0;
            end
            
            %obj = obj.clusterUpdate();
            
            obj.packets.rcvd = obj.packets.rcvd + 1;
            obj.bytes.rcvd = obj.bytes.rcvd + len;            
        end
        
        function obj = advertise(obj,pkt)
            
            %obj = obj.clusterUpdate();
            
            % IP level
            obj.src = obj.id;
            obj.dst = pkt.src;             
            obj.ttl = 1;
            obj.len = 80 + (numel(obj.ids) * 2) + (obj.peers * 6);
          
            % custom proto level
            obj.type = 'ADVERT';
            obj.peers = obj.rtable.neighbors();
            obj.metric = obj.calcMetric();
            obj.advert.seq = pkt.hello.seq;
            obj.advert.metric = obj.metric;
            obj.advert.cluster = obj.cluster;
            obj.advert.peers = obj.rtable.neighbors();
            obj.advert.ids = obj.ids;
            obj.result = obj.len;
            
            % update stats
            obj.packets.sent = obj.packets.sent + 1;
            obj.bytes.sent = obj.bytes.sent + obj.len; 
        end   
        
        function obj = processAdvert(obj,src,len,advert)
            
            peer = struct('id',src,'metric',advert.metric,'cluster',advert.cluster,...
                'expire',0,'peers',advert.peers,'ids',advert.ids);
            peer.expire = obj.timestamp + obj.neighlifetime;
            obj.peerlist(num2str(src)) = peer;
                       
            switch advert.cluster
                case Cluster.LEADER
                    flags = 'L';
                case Cluster.GATEWAY
                    flags = 'G';
                case Cluster.NODE
                    flags = 'N';
                otherwise                  
            end            
            
            if obj.rtable.contains(src,1) == 0
                %fprintf('%d rtable insert %s\n', (obj.id), num2str(src));
                obj.rtable.add(src,src,1,advert.metric,flags);
                %obj.rtable.show
            else
                %fprintf('%d rtable update %s, M=%d, F=%s\n', (obj.id), num2str(src), advert.metric, flags);
                obj.rtable.updateMetric(src, advert.metric);
                obj.rtable.updateFlags(src, flags);
                %obj.rtable.show

            end
                
            obj = obj.clusterUpdate();
            
            obj.packets.rcvd = obj.packets.rcvd + 1;
            obj.bytes.rcvd = obj.bytes.rcvd + len;            
        end
        
        function obj = removeExpiredPeers(obj)
            pkeys = obj.peerlist.keys;
            len = obj.peerlist.length;
            for p=1:len
                key = pkeys(p);
                peer = obj.peerlist(char(key));
                if (peer.expire < obj.timestamp)
                    %fprintf('%d removing peer %s\n', (obj.id), num2str(peer.id));
                    obj.peerlist.remove(pkeys(p));                    
                    obj.rtable.remove(peer.id);
                    if ismember(peer.id, obj.ids)
                        obj.ids((obj.ids == peer.id)) = [];
                    end
                end
            end 
        end
        
        function obj = set.timer(obj,t)          
          if (isnumeric(t))
             obj.timer = t;
          else
             error('Invalid timer');
          end
        end
        
        function obj = set.battery(obj,b)          
          if (isnumeric(b))
             obj.battery = b;
          else
             error('Invalid battery level');
          end
        end
        
        function obj = set.cluster(obj,m)           
          switch m
              case Cluster.LEADER
                  obj.cluster = Cluster.LEADER;
              case Cluster.GATEWAY
                  obj.cluster = Cluster.GATEWAY;
              case Cluster.NODE
                  obj.cluster = Cluster.NODE;                  
              otherwise
                  error('Invalid cluster status');
          end
        end        
        
        function c = get.cluster(obj)
            c = obj.cluster;
        end
        
        function c = get.metric(obj)
            c = obj.metric;
        end 
        
        function m = calcMetric(obj)
            m = (obj.rtable.neighbors()*1000) + obj.id;
        end        
               
        function obj = clusterUpdate(obj)            
            maxM = 0;
            leaders = 0;
            gates = 0;
            snodes = 0;
            joint = [];
            cl = [];
            
            obj.ids = [];
            obj.metric = calcMetric(obj);
            obj.rtable.updateMetric(obj.id,obj.metric);
            
            obj = obj.removeExpiredPeers();
            
            pkeys = obj.peerlist.keys;
            for p=1:obj.peerlist.length
                peer = obj.peerlist(char(pkeys(p)));
                if(peer.metric > maxM)
                    maxM = peer.metric;
                    if peer.cluster == Cluster.LEADER
                        cl = peer.ids;
                    end
                end
                
                switch peer.cluster
                    case Cluster.LEADER
                        leaders = leaders + 1;
                        joint = union(joint, peer.ids);
                    case Cluster.GATEWAY
                        %joint = union(joint, peer.ids);
                        gates = gates + 1;
                    case Cluster.NODE
                        snodes = snodes + 1;
                    otherwise
                end
            end 
            
            s = numel(joint);
            if (leaders == 0 || obj.metric > maxM)
                obj.ids = obj.id;
                obj.cluster = Cluster.LEADER;
                flags = 'L';
            elseif (leaders > 1) || ((obj.cluster ~= Cluster.LEADER) && (s > 1))
                obj.ids = joint;  
                obj.cluster = Cluster.GATEWAY;
                flags = 'G';
            else
                if ~isempty(cl)
                    obj.ids = cl;
                elseif ~isempty(joint)
                    obj.ids = joint;
                end
                obj.cluster = Cluster.NODE;
                flags = 'N';
            end
            
            obj.rtable.updateFlags(obj.id,flags);
            
        end
        
        function out = colorNode(obj)
            switch obj.cluster
              case Cluster.LEADER
                  out = obj.cl_lead_color;
              case Cluster.GATEWAY
                  out = obj.cl_gate_color;
              case Cluster.NODE
                  out = obj.cl_node_color;
              otherwise
                  out = obj.cl_node_color;
            end            
        end
    end
end

