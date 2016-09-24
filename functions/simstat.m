function [out] = simstat( SIMTIME, Nodes, S, R, Protocols, Apps )
%   Summary of this function goes here
%   Detailed explanation goes here

pdr = 0; % packet delivery ratio (throughput). data rcvd / data sent
cov = 0; % control overhead. ctrl bytes sent / data bytes rcvd
fef = 0; % forwarding efficiency. data + ctrl packets sent / data packets rcvd

psent = 0;
prelay = 0;
prcvd = 0;
pdrop = 0;
bsent = 0;
brcvd = 0;
N = numel(Nodes);

for i=1:N
    psent = psent + Nodes(i).packets.sent;
    prcvd = prcvd + Nodes(i).packets.rcvd;
    pdrop = pdrop + Nodes(i).packets.droped;
    bsent = bsent + Nodes(i).bytes.sent;
    brcvd = brcvd + Nodes(i).bytes.rcvd;
    if ismember('ODMRP',Protocols)
        prelay = prelay + Nodes(i).odmrp.ctrl.packets.relayed + Nodes(i).odmrp.data.packets.relayed;
    end
end
    
fprintf('\r\n--- SIMULATION STATISTICS ---\n');
for i=1:N         
    if ismember('ODMRP',Protocols)
        %fprintf('ODMRP protocol statistics, node %d\n', i);        
        %message_cache = Nodes(i).odmrp.message_cache;
        
        data_packets = Nodes(i).odmrp.data.packets;
        ctrl_packets = Nodes(i).odmrp.ctrl.packets;
        data_bytes = Nodes(i).odmrp.data.bytes;
        ctrl_bytes = Nodes(i).odmrp.ctrl.bytes;
        
        % 1. PDR
        if Nodes(i).odmrp.isReceiver == 1
            packet_delivery_ratio = data_packets.rcvd / ((SIMTIME-Nodes(i).uptime) / Apps.period);
            pdr = packet_delivery_ratio + pdr;
        end
        
        % 2. COV
        if data_bytes.rcvd > 0
            control_overhead = double(ctrl_bytes.sent + (data_packets.sent * 40)) / double(data_bytes.rcvd);
            cov = control_overhead + cov;
        end
        
        % 3. FEF
        if data_packets.rcvd > 0
            forw_eff = (data_packets.sent + data_packets.relayed + ctrl_packets.sent + ctrl_packets.relayed) / data_packets.rcvd;
            fef = forw_eff + fef;
        end
        
    end
    if ismember('NEIGHBOR',Protocols)
        fprintf('NEIGHBOR protocol\n');
    end
    if ismember('HLMRP',Protocols)
        fprintf('HLMRP protocol\n');
        Nodes(i).hlmrp.rtable.show;
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

if ismember('ODMRP',Protocols)
    fprintf('\r ---  ODMRP protocol performance --- \n');
    fprintf('packet delivery ratio: %.2f\n', (pdr / R));
    fprintf('control overhead: %.2f\n', (cov / R));
    fprintf('forwarding efficiency: %.2f\n', (fef / R));
end
if ismember('NEIGHBOR',Protocols)
    
end
if ismember('HLMRP',Protocols)
    
end
end

