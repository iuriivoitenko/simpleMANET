classdef TDMA
    %TDMA class
    %   Class represents TDMA-based MAC protocol
    
    properties
        slot % duration of a single TDMA slot, ms
    end
    
    methods
        function obj = TDMA(slot)
            obj.slot = slot;
        end
    end
    
end

