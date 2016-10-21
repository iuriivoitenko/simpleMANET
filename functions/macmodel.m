function [ M ] = macmodel( NODES, macproto )
%MACMODEL Summary of this function goes here
%   function creates a vector of MAC protocols 
%   used at Nodes in simulation

M = cell(1,NODES);
for i=1:NODES
    M(1,i) = cellstr(macproto);
end

end

