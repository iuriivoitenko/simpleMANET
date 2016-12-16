function [ M ] = macmodel( enabled, NODES, macproto )
%MACMODEL Summary of this function goes here
%   function creates a vector of MAC protocols 
%   used at Nodes in simulation

M = struct([]);
for i=1:NODES
    s = struct('proto','','enabled',0);
    s.proto = cellstr(macproto);
    s.enabled = enabled;
    if i == 1
        M = s;
    else
        M(i) = s;
    end
end

end

