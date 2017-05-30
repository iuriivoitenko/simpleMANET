classdef DSR < IPv6
    % DSR Summary of this class goes here
    % This class represents DSR protocol from RFC 4728
    properties (Constant)
        FG_TIMEOUT = 880;
        HELLO_INTERVAL = 1000;
        HELLO_TIMEOUT_INTERVAL = 3000;
        JT_REFRESH = 160;
        MEM_REFRESH = 400;
        MEM_TIMEOUT = 960;
        RTE_TIMEOUT = 960;
        RT_DISCV_TIMEOUT = 30000;
        TTL_VALUE = 32;
        version = 0;
        overhead = 64;
        msender = [1 0 0];
        mnode = [1 1 0];
        mreceiver = [33 205 163] ./ 255;
    end
    
    properties
    end
    
    methods
    end
    
end

