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
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    properties ( Access = private )
        inited = 0;
        connected = 0;   
        debug = 1;             % show debug text
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
        curproto
        % 1. add custom protocol here
        neighbor
        hlmrp
        odmrp
        % newproto
    end
    
    events
        PacketSent 
    end
    
    methods
      function obj = Node(id, x, y, simtime, speed, uptime, loss, energy, protocols, agent, apps)
            obj.id = id;
            obj.color = [.5 .5 .5]; % gray by default
            obj.radius = 50;
            obj.x = x;
            obj.y = y;
            obj.loss = loss; % loss percent [0...1]
            obj.waypoint = Waypoint(simtime, speed);
            obj.queue = Queue(100); % tx queue
            obj.packets = struct('sent',0,'rcvd',0,'droped',0,'relayed',0);
            obj.bytes = struct('sent',0,'rcvd',0);
            obj.energy = energy;
            obj.uptime = uptime; 
            % 2. init protocol here
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
      function [out, p] = generate_pkt(obj, t, delay, p)
          
          if obj.uptime > t
              out = '';
              return
          elseif obj.inited==0
              obj.color = [33 205 163] ./ 255;
              obj.inited = 1;
          else
              obj.waypoint = obj.waypoint.timeout;
              if isempty(obj.neighbor) == 0
                  obj.color = obj.neighbor.colorNode;
              elseif isempty(obj.odmrp) == 0
                  obj.color = obj.odmrp.colorNode;
              end
          end
          
          % Neighbor protocol timeout function
          if isempty(obj.neighbor) == 0 
              obj.neighbor = obj.neighbor.timeout(delay, t);
              if obj.neighbor.result > 0 % packet generated on timeout   
                  obj.send_pkt(obj.neighbor);
              end
          end
          
          % HLMRP protocol timeout function
          if isempty(obj.hlmrp) == 0
              obj.hlmrp = obj.hlmrp.timeout(delay, t);
              if obj.hlmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(obj.hlmrp);
              end
          end
          
          % ODMRP protocol timeout function
          if isempty(obj.odmrp) == 0
              obj.odmrp = obj.odmrp.timeout(delay, t);
              if obj.odmrp.result > 0 % packet generated on timeout              
                  obj.send_pkt(obj.odmrp);
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
          if obj.queue.NumElements() > 0
              while obj.queue.NumElements() > 0
                  pkt = obj.queue.remove(); 
                  p = p + 1;
                  obj.packets.sent = obj.packets.sent + 1; 
                  obj.bytes.sent = obj.bytes.sent + pkt.len;
                  out = pkt.type;
                  notify(obj,'PacketSent');   % we don't have MAC protocol so send packet immediately
                  % print protocol data
                  if ~isempty(out)
                      switch pkt.protoname
                          case 'NEIGHBOR'
                              if pkt.debug == 1
                              switch pkt.type                                  
                                  case 'HELLO'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, cluster=%s, M=%d, P=%d \n', p, t, obj.neighbor.src, obj.neighbor.dst, obj.neighbor.protoname, out, obj.neighbor.hello.seq, char(obj.neighbor.cluster), obj.neighbor.metric, obj.neighbor.peers);
                                  case 'ADVERT'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, cluster=%s, M=%d, P=%d \n', p, t, obj.neighbor.src, obj.neighbor.dst, obj.neighbor.protoname, out, obj.neighbor.advert.seq, char(obj.neighbor.cluster), obj.neighbor.metric, obj.neighbor.peers);
                                  otherwise
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, NEIGHBOR packet unknown\n', p, t, pkt.src, pkt.dst);
                              end
                              end
                          case 'HLMRP'
                              if pkt.debug == 1
                              switch pkt.type
                                  case 'HEARTBEAT'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, LAST: %d, type=%s, nonce=%d, ttl=%d, hops=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, pkt.last, out, pkt.nonce, pkt.ttl, pkt.hops);
                                  case 'DATA'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, LAST: %d, type=%s, nonce=%d, ttl=%d, hops=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, pkt.last, out, pkt.hbeat.nonce, pkt.hbeat.ttl, pkt.hbeat.hops);                                  
                                  otherwise
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, HLMRP packet unknown\n', p, t, pkt.src, pkt.dst);
                              end
                              end
                          case 'ODMRP'
                              if pkt.debug == 1
                              switch pkt.type 
                                  case 'JOIN REQ'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, seq=%d, prev=%d, hops=%d, ttl=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, out, pkt.seq, pkt.prev, pkt.hops, pkt.ttl);
                                  case 'JOIN TABLE'
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, PROTO: %s, type=%s, count=%d, nonce=%d, group=%s \n', p, t, pkt.src, pkt.dst, pkt.protoname, out, pkt.count, pkt.jtable.reserved, pkt.mgroup);                                 
                                  case 'DATA'
                                        %out = strcat(pkt.type,':',num2str(pkt.dataseq));
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %s, PROTO: %s, type=%s, seq=%d, len=%d, last=%d \n', p, t, pkt.src, pkt.dst, pkt.protoname, out, pkt.dataseq, pkt.len, pkt.prev);
                                  otherwise
                                        fprintf('%d. time: %d ms, SRC: %d, DST: %d, ODMRP packet unknown\n', p, t, pkt.src, pkt.dst);
                              end
                              end
                          % case 'NEWPROTO'
                          %     fprintf('bla bla bla\n');
                          otherwise
                              fprintf('%d. time: %d ms, UNKNOWN PROTOCOL\n', p, t);
                      end
                  end                  
              end
          else
              out = '';
          end          
      end
      
      function send_pkt(obj, pkt)              
          % we put outgoing packet in the tx queue 
          obj.curproto = pkt.protoname;
          obj.queue.add(pkt);
      end

      function rcvd_pkt(obj,src,~)                             
          obj.packets.rcvd = obj.packets.rcvd + 1;          
          
          switch src.curproto
              case 'NEIGHBOR'
                  obj.bytes.rcvd = obj.bytes.rcvd + src.neighbor.len;
                  obj.neighbor = obj.neighbor.process_data(src.neighbor);               
                  if obj.neighbor.result > 0
                      obj.send_pkt(obj.neighbor);
                  elseif obj.neighbor.result < 0
                      obj.packets.droped = obj.packets.droped + 1;
                  end
              case 'HLMRP'
                  % HLMRP process packet if not NODE
                  obj.bytes.rcvd = obj.bytes.rcvd + src.hlmrp.len;
                  
                  if obj.neighbor.cluster ~= Cluster.NODE
                      [obj.hlmrp, src.hlmrp] = obj.hlmrp.process_data(src.hlmrp);   
                      if obj.hlmrp.result > 0
                          obj.send_pkt(obj.hlmrp);
                      elseif obj.hlmrp.result <= 0
                          obj.packets.droped = obj.packets.droped + 1;
                      end       
                  end
              case 'ODMRP'
                  % ODMRP process packet 
                  obj.bytes.rcvd = obj.bytes.rcvd + src.odmrp.len;
                  
                  [obj.odmrp, src.odmrp] = obj.odmrp.process_data(src.odmrp);   
                  if obj.odmrp.result > 0
                      obj.send_pkt(obj.odmrp);
                  elseif obj.odmrp.result <= 0
                      obj.packets.droped = obj.packets.droped + 1;
                  end       
                           
              %
              % Add custom protocol process function
              %                  
              otherwise
          end
          
      end
      
      function obj = connectListener(obj,src) 
          if obj.inited == 0
              return
          end
          if obj.connected == 0
            obj.rxlisn = addlistener(src,'PacketSent',@obj.rcvd_pkt);          
            obj.connected = 1;
          end
      end
      
      function obj = enableListener(obj)
          if obj.inited == 0
              return
          end
          if obj.connected == 1
            obj.rxlisn.Enabled = true;
          end
      end
      
      function obj = disableListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            obj.rxlisn.Enabled = false;
          end
      end
      
      function obj = deleteListener(obj)
          if obj.inited == 0
              return
          end          
          if obj.connected == 1
            delete(obj.rxlisn);
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

