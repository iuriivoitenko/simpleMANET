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
warning on
warning off verbose
warning off backtrace

clear Nodes;

%% visualization options --------------------------------------
showtext = 1;        % show type of a sent packet
showmoretext = 1;    % show supplementary info of the Node (bottom left to the Node)
showlines = 1;       % show line when packet sent 
showsender = 1;      % show circle around transmitting Node
showalledges = 0;    % show connectivity on the topology
printstat = 1;       % print detavoid
bypassphyrange = 1;  % avoid real RF range calculation based on PHY params and friis formula
enablemac = 0;       % enable MAC protocol, if=0 all packets deliver sucessfully

%% simulation constants ---------------------------------------
NODES = 10;           % total nodes in simulation
SENDERS = 5;          % total senders in simulation
RECEIVERS = 1;        % total receivers in simulation

%% global variables -------------------------------------------
SIMTIME = 30 * 1000;  % simulation time, ms
SAMPLING = 1;         % network event update, ms
DELAYPLOT = 10;       % delay in plot update, ms
SQUARE = 2000;        % square area, m
SPEED = 10;           % max speed of movement, m/s
RADIO = 2000;          % range of the radio, m
LOSS = 0;             % loss percent per link, %
UP = SIMTIME / 100;    % when nodes wake up, ms

%% runtime vars -----------------------------------------------
P = 0;                              % total packets generated in the simulation
L = randi([0 LOSS],1,NODES);        % node loss matrix
U = randi([0 UP],1,NODES);          % node start time matrix
E = randi([0 100],1,NODES);         % node energy matrix
Coord = randi([0 SQUARE],NODES,2);  % node initial coordinates

%% PHY used in this simulation --------------------------------
PHY = PhyModel(bypassphyrange, RADIO);
PHY.freq = 400*10^6;        % carrier frequency, Hz
PHY.modulation = 'BPSK';    % modulation scheme
PHY.bitrate = 360*10^3;     % bitrate, b/s
PHY.coding = 1/2;           % coding rate
PHY.Pt = 20;                % Tx power, dBm
PHY.Pr = -95;               % Rx sensitivity, dBm
PHY.Gt = 0;                 % Tx antenna gain, dBi
PHY.Gr = 0;                 % Rx antenna gain, dBi
PHY.L = 0;                  % other losses, dB
PHY.Fade = 40;              % fade margin, dB

%% MAC protocol used in this simulation -----------------------
MAC = macmodel(enablemac, NODES, 'ALOHA'); % in future every node will have own MAC protocol

%% Protocols used in this simulation --------------------------
Protocols = [{'neighbor'},{'hlmrp'}]; % add more protocols into simulation if needed: [{'proto1'},{'proto2'}]

%% Agents used in this simulation -----------------------------
Agents = agentrole(NODES,SENDERS,RECEIVERS);  % 0 - no data traffic, 1 - receiver, 2 - sender

%% Applications used in this simulation -----------------------
Apps = struct('data','CBR','packetlen',512,'period',100);

%% init nodes -------------------------------------------------
for i=1:NODES
    Nodes(i) = Node(i,Coord(i,1),Coord(i,2),SIMTIME,SPEED,U(i),L(i),E(i),PHY,MAC(i),Protocols,Agents(i),Apps);
end

%% start discrete simulation ----------------------------------
for t = 1:SAMPLING:SIMTIME
    pause(DELAYPLOT/1000);    

    % update topology matrix
    A = topology(Coord, Nodes); 
    
    % update plot graph and edges
    [a,c] = nodecolors(Nodes);    
    scatter(Coord(:,1),Coord(:,2),a,c,'filled');
    
    for j=1:NODES        
        
        % move node
        [Coord(j,1),Coord(j,2)]=mobility(Nodes(j).x,Nodes(j).y,(Nodes(j).waypoint.speed/1000*SAMPLING),Nodes(j).waypoint.dir);       
        Nodes(j).setCoord(Coord(j,1),Coord(j,2));
        text(Nodes(j).x+10,Nodes(j).y-10,num2str(Nodes(j).id,'%d'));
        
        
        % first we connect listener of the neighbor nodes based on topology
        for k=1:NODES
            if k~=j && A(j,k) == 1
                Nodes(k).connectListener(Nodes(j));                
            end
        end
        
        
        % now, process output queue for new packets
        [message, P] = Nodes(j).generate_pkt(t,SAMPLING,P);
                
        % plot sender related info once
        if showmoretext == 1
            % Neighbor protocol info, show how many 1-hop neighbors and clusters we have
            if ~isempty(Nodes(j).neighbor)
                s = size(Nodes(j).neighbor.ids);
                for i=1:s(2)
                    text(Nodes(j).x-50,Nodes(j).y-(40*i), num2str(Nodes(j).neighbor.ids(i),'%d'),'FontSize',8,'Color','b');
                end
            end
            % ODMRP protocol info, show FORWARDING_FLAG and number of entries in Member_table 
            if ~isempty(Nodes(j).odmrp)
                text(Nodes(j).x-50,Nodes(j).y-(100), strcat(num2str(Nodes(j).odmrp.FORWARDING_GROUP_FLAG,'%d'),':',num2str(Nodes(j).odmrp.member_table.Count)),'FontSize',8,'Color','b');                
            end
            % custom proto1 info on the topology graph
            % if ~isempty(Nodes(j).proto1)
            %
            % end
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
    simstat(SIMTIME,Nodes,SENDERS,RECEIVERS,Protocols,Apps);
end

