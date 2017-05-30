classdef CSMA < handle
    %CSMA Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        maxretry = 3;
        maxbackofftime = 100; % ms
    end
    
    properties
        protoname = 'CSMA';
        timeout
        retry
        backoff
    end
    
    methods
        function obj = CSMA()
            flush();
        end
        
        function flush( obj )
            obj.retry = 0;
            obj.backoff = 0;
            obj.timeout = 0;
        end
        
        function b = RandomBackoff( obj )
            obj.retry = obj.retry + 1;
            if obj.retry > obj.maxretry
                b = -1;
            else
                b = randi([0 (obj.maxbackofftime * obj.retry)],1,1);
            end
        end
    end
    
end

