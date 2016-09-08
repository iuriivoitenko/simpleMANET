function [out] = simstat( SIMTIME, Nodes, S, R, Protocols, Apps )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

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
N = numel(Nodes);
fprintf('\r\n--- SIMULATION STATISTICS ---\r\n');
for i=1:N  
    
    psent = psent + Nodes(i).packets.sent;
    prcvd = prcvd + Nodes(i).packets.rcvd;
    pdrop = pdrop + Nodes(i).packets.droped;
    bsent = bsent + Nodes(i).bytes.sent;
    brcvd = brcvd + Nodes(i).bytes.rcvd;
    
    if ismember('ODMRP',Protocols)
        fprintf('ODMRP protocol statistics, node %d\n', i);
        prelay = prelay + Nodes(i).odmrp.ctrl.packets.relayed + Nodes(i).odmrp.data.packets.relayed;
        message_cache = Nodes(i).odmrp.message_cache;
        
        data_packets = Nodes(i).odmrp.data.packets;
        ctrl_packets = Nodes(i).odmrp.ctrl.packets;
        data_bytes = Nodes(i).odmrp.data.bytes;
        ctrl_bytes = Nodes(i).odmrp.ctrl.bytes;
        
        % 1. PDR
        packet_delivery_ratio = data_packets.rcvd / ((SIMTIME-Nodes(i).uptime) / Apps.period)
        pdr = packet_delivery_ratio + pdr;
        
        % 2. COV
        control_overhead = ctrl_bytes.sent / data_bytes.rcvd;
        cov_ctrl_bytes_sent = cov_ctrl_bytes_sent + ctrl_bytes.sent;
        cov_data_bytes_rcvd = cov_data_bytes_rcvd + data_bytes.rcvd;
        
        % 3. FEF
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

