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

classdef Node < handle
    %NODE class
    %   Represents a single network node in a network
    properties ( Access = private )
        localtime = 0;
        inited = 0;
        connected = 0;   
        debug = 1;             % show debug text
        msg
    end
    properties
        id
        color 
        radius
        x
        y
        energy
        loss
        uptime        
        packets
        bytes
        queue
        waypoint
        rxlisn
        txlisn
        lklisn
        curproto
        phy
        link
        % 1. add custom protocol here
        neighbor
        hlmrp
        odmrp
        % newproto
    end
    
    events
        PacketStart % emitted when packet sending started on tx node
        PacketSent  % emitted when packet is sent on tx node
    end
    
    methods
      function obj = Node(id, x, y, simtime, speed, uptime, loss, energy, phy, mac, protocols, agent, apps)
            obj.id = id;
            obj.color = [.5 .5 .5]; % gray by default
            obj.radius = 50;
            obj.x = x;
            obj.y = y;
            obj.loss = loss; % loss percent [0...1]
            obj.waypoint = Waypoint(simtime, speed);
            obj.queue = Queue(100); % tx queue
            obj.packets = struct('sent',0,'rcvd',0,'dropped',0,'relayed',0);
            obj.bytes = struct('sent',0,'rcvd',0);
            obj.energy = energy;
            obj.uptime = uptime; 
            obj.phy = phy;
            obj.link = LinkModel(id,mac);
            obj.lklisn = addlistener(obj.link,'finishedSending',@obj.sent_pkt); 
            % 2. init protocols here
            p = size(protocols);
            for i=1:p(2)                
                switch upper(char(protocols(i)))
                    case 'NEIGHBOR'
                        obj.neighbor = Neighbor(id); 
                    case 'HLMRP'
                        obj.hlmrp = HLMRP(id, agent, apps);
                    case 'ODMRP'
                        obj.odmrp = ODMRP(id, agent, apps);
                    % case 'NEWPROTO'
                    %   obj.newproto = NewProto(id);
                    otherwise
                        error('unknown protocol');
                end
            end
      end
      
      % this function determines whether new packet should be generated or not, called every time simulation is paused
      % packets can be generated either by timeout or fetched from tx queue
      function [type, p] = generate_pkt(obj, t, delay, p)
          
          type = '';
          obj.localtime = t;
          if obj.uptime > t              
              return
          elseif obj.inited==0
              obj.color = [33 205 163] ./ 255;
              obj.inited = 1;
          else 
              obj.waypoint.timeout;
              obj.link.timeout(delay);
              % Colorize nodes 
              if isempty(obj.neighbor) == 0
                  obj.color = obj.neighbor.colorNode;
              elseif isempty(obj.odmrp) == 0
                  obj.color = obj.odmrp.colorNode;
              end
          end
          
          % Protocol timeouts ----------------------------------------
          % Neighbor protocol timeout function
          if isempty(obj.neighbor) == 0 
              [obj.neighbor, pkt] = obj.neighbor.timeout(delay, t);
              if obj.neighbor.result > 0 % packet generated on timeout   
                  obj.send_pkt(pkt);
              end
          end
                   
          % HLMRP protocol timeout function
          if isempty(obj.hlmrp) == 0
              [obj.hlmrp, pkt] = obj.hlmrp.timeout(delay, t);
              if obj.hlmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(pkt);
              end
          end
          
          % ODMRP protocol timeout function
          if isempty(obj.odmrp) == 0
              [obj.odmrp, pkt] = obj.odmrp.timeout(delay, t);
              if obj.odmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(pkt);
              end    
          end
          
          % ************************************************
          % Place to add custom protocol timeout function
          % ************************************************
          %  if isempty(obj.proto1) == 0
          %    obj.proto1 = obj.proto1.timeout(delay, t);
          %    if obj.proto1.result > 0 % packet generated on timeout              
          %        obj.send_pkt(obj.proto1);
          %    end    
          %  end
          %
          
          % Process outgoing queue
          if obj.queue.NumElements > 0 && obj.link.until <= 0 % prevent sending several packets at the same time, so just wait until it's transmitted          
              pkt = obj.queue.remove();   % fetch IPv6 packet from TX queue         
              obj.link.lastlen = pkt.len; % put length of this packet into link layer
              type = pkt.getType;         % get the packet type      
              p = p + 1;                  % global increment of packets TX
                  
              obj.link.linkLockTx(obj.id, obj.phy.duration(pkt.len), pkt); % enable MAC protocol
              notify(obj,'PacketStart');   % start sending packet immediately
                  
              obj.packets.sent = obj.packets.sent + 1; 
              obj.bytes.sent = obj.bytes.sent + pkt.len;

              % print protocol data
              if ~isempty(type)
                  switch pkt.next
                      case 'NEIGHBOR'
                          if obj.neighbor.show == 1
                          switch type                                  
                              case 'HELLO'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, cluster=%s, M=%d, P=%d \n', p, t, obj.neighbor.src, obj.neighbor.dst, obj.neighbor.protoname, type, obj.neighbor.hello.seq, char(obj.neighbor.cluster), obj.neighbor.metric, obj.neighbor.peers);
                              case 'ADVERT'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, cluster=%s, M=%d, P=%d \n', p, t, obj.neighbor.src, obj.neighbor.dst, obj.neighbor.protoname, type, obj.neighbor.advert.seq, char(obj.neighbor.cluster), obj.neighbor.metric, obj.neighbor.peers);
                              otherwise
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, NEIGHBOR packet unknown\n', p, t, pkt.src, pkt.dst);
                          end
                          end
                      case 'HLMRP'
                          if obj.hlmrp.show == 1
                          switch type
                              case 'HEARTBEAT'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, LAST: %d, type=%s, nonce=%d, ttl=%d, hops=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, pkt.last, type, pkt.nonce, pkt.ttl, pkt.hops);
                              case 'DATA'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, LAST: %d, type=%s, nonce=%d, ttl=%d, hops=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, pkt.last, type, pkt.hbeat.nonce, pkt.hbeat.ttl, pkt.hbeat.hops);                                  
                              otherwise
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, HLMRP packet unknown\n', p, t, pkt.src, pkt.dst);
                          end
                          end
                      case 'ODMRP'
                          if obj.odmrp.show == 1
                          switch type 
                              case 'JOIN REQ'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, prev=%d, hops=%d, ttl=%d \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.jreq.seq, pkt.appdata.jreq.prev, pkt.appdata.jreq.hops, pkt.ttl);
                              case 'JOIN TABLE' 
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, count=%d, nonce=%d, group=%s \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.jtable.count, pkt.appdata.jtable.reserved, pkt.appdata.jtable.mgroup);                                 
                              case 'DATA'
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %s, PROTO: %s, type=%s, seq=%d, len=%d, last=%d \n', p, t, pkt.src, pkt.dst, pkt.next, type, pkt.appdata.dataseq, pkt.len, pkt.appdata.prev);
                              otherwise
                                    obj.msg=sprintf('%d. time: %d ms, SRC: %d, DST: %d, ODMRP packet unknown\n', p, t, pkt.src, pkt.dst);
                           end
                           end
                      % case 'NEWPROTO'
                      %     obj.msg=sprintf('bla bla bla\n');
                      otherwise
                           obj.msg=sprintf('%d. time: %d ms, UNKNOWN PROTOCOL\n', p, t);
                  end
              end                  
          end       
      end
      
      function send_pkt(obj, pkt)                        
          obj.queue.add(pkt); % we put outgoing packet in the tx queue 
      end

      function rcvd_pkt(obj,src,~)   
          
          pkt = src.link.pkt; % extract pkt from link layer of sending node, it's like it was successfully received :)

          %fprintf('rcvd_pkt, %d from %d, pkt.next: %s\r\n', obj.id, src.id, pkt.next);                    
          obj.link.linkReleaseRx; % at least one node has finished sending            
          %fprintf('medium at Node %d, busy=%d, err=%d\r',obj.id, obj.link.busy, obj.link.err);
          
          if obj.link.isBusy == 0 % if medium was idle, we can receive packet              
                            
              % update stats
              obj.packets.rcvd = obj.packets.rcvd + 1;
              obj.bytes.rcvd = obj.bytes.rcvd + pkt.len;
              
              if ~isempty(pkt.next)
              switch pkt.next
                  case 'NEIGHBOR'
                      [obj.neighbor, pkt] = obj.neighbor.process_data(pkt);               
                      if obj.neighbor.result > 0
                          obj.send_pkt(pkt);
                      elseif obj.neighbor.result < 0
                          obj.packets.dropped = obj.packets.dropped + 1;
                      end
                  case 'HLMRP'
                      % HLMRP process packet if not NODE
                      if obj.neighbor.cluster ~= Cluster.NODE
                          [obj.hlmrp, pkt] = obj.hlmrp.process_data(pkt);   
                          if obj.hlmrp.result > 0
                              obj.send_pkt(pkt);
                          elseif obj.hlmrp.result < 0
                              obj.packets.dropped = obj.packets.dropped + 1;
                          end       
                      end
                  case 'ODMRP'
                      % ODMRP process packet                       
                      [obj.odmrp, pkt] = obj.odmrp.process_data(pkt);   
                      if obj.odmrp.result > 0
                          obj.send_pkt(pkt);
                      elseif obj.odmrp.result < 0
                          obj.packets.dropped = obj.packets.dropped + 1;
                      end       

                  %
                  % Add custom protocol process function
                  %                  
                  otherwise
              end
              end
          end
      end
      
      function start_pkt(obj,src,~)
          %fprintf('start_pkt, %d -> %d\r\n', src.id, obj.id);
          obj.link.linkLockRx(src.id);
      end
      
      function sent_pkt(obj,~,~)
          %fprintf('sent_pkt, %d\r\n', obj.id);
          obj.link.linkReleaseTx;
          notify(obj,'PacketSent'); 
          fprintf(obj.msg); % print out log to command window
      end
            
      function obj = connectListener(obj,src) 
          if obj.inited == 0
              return
          end
          if obj.connected == 0
            obj.rxlisn = addlistener(src,'PacketSent',@(s,evnt)obj.rcvd_pkt(s,evnt));
            obj.txlisn = addlistener(src,'PacketStart',@obj.start_pkt);                              
            obj.connected = 1;
          end
      end
      
      function obj = enableListener(obj)
          if obj.inited == 0
              return
          end
          if obj.connected == 1
            obj.rxlisn.Enabled = true;
            obj.txlisn.Enabled = true;
          end
      end
      
      function obj = disableListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            obj.rxlisn.Enabled = false;
            obj.txlisn.Enabled = false;
          end
      end
      
      function obj = deleteListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            delete(obj.rxlisn);
            delete(obj.txlisn);
            obj.connected = 0;
          end
      end
      
      function set.color(obj,color)
          obj.color = color;
      end
      
      function set.uptime(obj,up)          
         if (isnumeric(up))
            obj.uptime = up;
         else
            error('Invalid uptime');
         end
      end  
      
      function set.energy(obj,e)          
         if (isnumeric(e))
            obj.energy = e;
         else
            error('Invalid energy');
         end
      end      
      
      function setCoord(obj,x,y)          
         if (isnumeric(x) && isnumeric(y))
             obj.x = x;
             obj.y = y;             
         else
            error('Invalid coordinates');
         end
      end
      
      function set.x(obj,x)
          if (isnumeric(x))
            obj.x = x;
          else
            error('Invalid coordinate');
          end
      end
      
      function set.y(obj,y)
          if (isnumeric(y))
            obj.y = y;
          else
            error('Invalid coordinate');
          end
      end
    end
    
end

