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

clear Nodes;

%% simulation options -----------------------------------------
showtext = 1;
showmoretext = 1;
showlines = 1;
showsender = 1;
showalledges = 0;
showroutetable = 1;
printstat = 1;

%% simulation constants ---------------------------------------
NODES = 10;           % total nodes in simulation
S = 1;                % total senders in simulation
R = 5;                % total receivers in simulation

%% global variables -------------------------------------------
SIMTIME = 30 * 1000;  % simulation time, ms
SAMPLING = 10;        % network event update, ms
DELAYPLOT = 10;       % delay in plot update, ms
SQUARE = 2000;        % square area, m
SPEED = 0;            % max speed of movement, m/s
RADIO = 800;          % range of the , m
LOSS = 0;             % loss percent per link, %
UP = SIMTIME / 10;    % when nodes wake up, ms

%% runtime vars -----------------------------------------------
L = randi([0 LOSS],1,NODES);        % node loss matrix
U = randi([0 UP],1,NODES);          % node start time matrix
E = randi([0 100],1,NODES);         % node energy matrix
M = randi([0 SPEED],1,NODES);       % node mobility matrix
D = randi([0 360],1,NODES);         % node direction matrix, degrees
Coord = randi([0 SQUARE],NODES,2);  % node initial coordinates

%% Protocols use in this simulation ---------------------------
Protocols = [{'ODMRP'}]; % add more protocols into simulation if needed: [{'proto1'},{'proto2'}]

%% Agents used in this simulation -----------------------------
Agents = agentrole(NODES,S,R);  % 0 - no data traffic, 1 - multicast receiver, 2 - multicast sender

%% Applications used in this simulation -----------------------
Apps = struct('data','CBR','packetlen',512,'period',100);

%% init nodes and plot topology -------------------------------
for i=1:NODES
    Nodes(i) = Node(i,Coord(i,1),Coord(i,2),M(i),D(i),U(i),L(i),Protocols,Agents(i),Apps);
end

%% start descrete simulation ----------------------------------
for t = 1:SAMPLING:SIMTIME
    pause(DELAYPLOT/1000);              

    % update topology matrix
    A = topology(Coord, RADIO, Nodes);    
                
    % update plot graph and edges z
    [a,c] = nodecolors(Nodes);    
    scatter(Coord(:,1),Coord(:,2),a,c,'filled');
    
    for j=1:NODES        
        
        % move node
        [Coord(j,1),Coord(j,2)]=mobility(Nodes(j).x,Nodes(j).y,(Nodes(j).speed/1000*SAMPLING),Nodes(j).dir);       
        Nodes(j).setCoord(Coord(j,1),Coord(j,2));
        text(Nodes(j).x+10,Nodes(j).y-10,num2str(Nodes(j).id,'%d'));
        
        
        % first we connect listener of the neighbor nodes based on topology
        for k=1:NODES
            if k~=j && A(j,k) == 1
                Nodes(k).connectListener(Nodes(j));                
            end
        end
        
        
        % now, process output queue for new packets
        message = Nodes(j).generate_pkt(t,SAMPLING);
                
        % plot sender related info once
        if showmoretext == 1
            if ~isempty(Nodes(j).neighbor)
            s = size(Nodes(j).neighbor.ids);
            for i=1:s(2)
                text(Nodes(j).x-50,Nodes(j).y-(40*i), num2str(Nodes(j).neighbor.ids(i),'%d'),'FontSize',8,'Color','b');
            end
            end
            
            if ~isempty(Nodes(j).odmrp)
                text(Nodes(j).x-50,Nodes(j).y-(100), strcat(num2str(Nodes(j).odmrp.FORWARDING_GROUP_FLAG,'%d'),':',num2str(Nodes(j).odmrp.member_table.Count)),'FontSize',8,'Color','b');                
            end
        end
        if showsender == 1 && ~isempty(message)
            circle2(Nodes(j).x,Nodes(j).y,30); % highlight the tx node
        end
        
        % loop thru neighbors 
        for k=1:NODES            
            
            if k==j
                continue;
            end           
            
            % delete connected listener and plot link
            if A(j,k) == 1
                Nodes(k).deleteListener();
                if isempty(message) % no data sent
                        if showalledges == 1
                            line( [Nodes(j).x Nodes(k).x], [Nodes(j).y Nodes(k).y],'Color','b','LineStyle','-');
                        end
                else % packet has been sent                        
                        if showlines == 1
                            line( [Nodes(j).x Nodes(k).x], [Nodes(j).y Nodes(k).y],'Color','r','LineStyle','-');
                        end
                        if showtext == 1
                            text(Nodes(j).x+((Nodes(k).x-Nodes(j).x)/2),Nodes(j).y+((Nodes(k).y-Nodes(j).y)/2),message,'FontSize',10);
                        end
                end 
            end
            
        end                
    end
end

%% print statistics
if printstat == 1
pdr = 0; % packet delivery ratio (throughput). data rcvd / data sent
cov = 0; % control overhead. ctrl bytes sent / data bytes rcvd
fef = 0; % forwarding efficiency. data + ctrl packets sent / data packets rcvd

cov_ctrl_bytes_sent = 0;
cov_data_bytes_rcvd = 0;
psent = 0;
prelay = 0;
prcvd = 0;
pdrop = 0;
bsent = 0;
brcvd = 0;
fprintf('\r\n--- SIMULATION STATISTICS ---\r\n');
for i=1:NODES    
    psent = psent + Nodes(1,i).packets.sent;
    prcvd = prcvd + Nodes(1,i).packets.rcvd;
    pdrop = pdrop + Nodes(1,i).packets.droped;
    bsent = bsent + Nodes(1,i).bytes.sent;
    brcvd = brcvd + Nodes(1,i).bytes.rcvd;
    if ismember('ODMRP',Protocols)
        fprintf('ODMRP protocol statistics, node %d\n', i);
        prelay = prelay + Nodes(i).odmrp.packets.ctrl.relayed + Nodes(i).odmrp.packets.data.relayed;
        if showroutetable == 1
            message_cache = Nodes(1,i).odmrp.message_cache;
        end
        data_packets = Nodes(i).odmrp.packets.data;
        ctrl_packets = Nodes(i).odmrp.packets.ctrl;
        data_bytes = Nodes(i).odmrp.bytes.data;
        ctrl_bytes = Nodes(i).odmrp.bytes.ctrl;
        
        data_pkt_rcvd = data_packets.rcvd;
        data_pkt_sent = data_packets.sent;
        
        % 1. PDR
        packet_delivery_ratio = Nodes(i).odmrp.packets.data.rcvd / ((SIMTIME-Nodes(i).uptime) / Apps.period)
        pdr = packet_delivery_ratio + pdr;
        
        % 2. COV
        ctrl_bytes_sent = Nodes(i).odmrp.bytes.ctrl.sent;
        data_bytes_rcvd = Nodes(i).odmrp.bytes.data.rcvd;
        control_overhead = ctrl_bytes_sent / data_bytes_rcvd;
        cov_ctrl_bytes_sent = cov_ctrl_bytes_sent + ctrl_bytes_sent;
        cov_data_bytes_rcvd = cov_data_bytes_rcvd + data_bytes_rcvd;
        
        % 3. FEF
    end
    if ismember('NEIGHBOR',Protocols)
        fprintf('NEIGHBOR protocol\n');
    end
    if ismember('HLMRP',Protocols)
        fprintf('HLMRP protocol\n');
        if showroutetable == 1
            Nodes(1,i).hlmrp.rtable.show
        end
    end
%     fprintf('\rTotal per node %d\n', i);
%     fprintf('packets sent: %d\n',  Nodes(i).packets.sent);
%     fprintf('packets rcvd: %d\n',  Nodes(i).packets.rcvd);
%     fprintf('packets drop: %d\n',  Nodes(i).packets.droped);
%     fprintf('packets relayed: %d\n',  Nodes(i).packets.relayed);
%     fprintf('bytes sent: %d\n',  Nodes(i).bytes.sent);
%     fprintf('bytes rcvd: %d\n',  Nodes(i).bytes.rcvd);
%    fprintf(' --------------------------------- \n');
end
fprintf('\rTotal packets sent: %d\n', (psent));
fprintf('Total packets rcvd: %d\n', (prcvd));
fprintf('Total packets drop: %d\n', (pdrop));
if ismember('ODMRP',Protocols)
    fprintf('Total packets relayed: %d\n', (prelay));
end
if ismember('NEIGHBOR',Protocols)
    
end
if ismember('HLMRP',Protocols)    
end
fprintf('Total bytes sent: %d\n', (bsent));
fprintf('Total bytes rcvd: %d\n', (brcvd));
fprintf('\r\n ---  Protocol performance --- \n');
if ismember('ODMRP',Protocols)
    fprintf('packet delivery ratio %.2f\n', (pdr / R));
    fprintf('control overhead %.2f\n', (cov_ctrl_bytes_sent / cov_data_bytes_rcvd));
    fprintf('forwarding efficiency %.2f\n', (cov_ctrl_bytes_sent / cov_data_bytes_rcvd));
end
if ismember('NEIGHBOR',Protocols)
    
end
if ismember('HLMRP',Protocols)
    
end
end

