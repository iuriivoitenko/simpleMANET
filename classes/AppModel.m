classdef AppModel < handle
    %APPDATAMODEL Summary of this class goes here
    % This class represents application data generators such as CBR, VBR etc
    
    properties
        type
        datalen
        period
        number
        dst % data destination IP
    end 
    
    properties ( Access = private )
        timestamp
        timer = 0;
        pingcnt = 0;
    end
    
    methods
        function obj = AppModel( type, datalen, period, number )
            obj.type = type;
            obj.datalen = datalen;
            obj.period = period;
            obj.number = number;
            
            switch upper(type)
                case 'CBR'
                    obj.type = 'CBR';
                case 'VBR'
                    obj.type = 'VBR';
                case 'PING'
                    obj.type = 'PING';
                    obj.period = 1000;
                otherwise
                    error('Invalid application data type');
            end
        end
        
        function r = timeout( obj, d, t )
            obj.timestamp = t; % remember local time
            obj.timer = obj.timer + d;            
            if obj.timer >= obj.period   
                obj.timer = mod(obj.timer, d);
                if obj.type == 'PING'
                    if obj.number > obj.pingcnt % ICMPv6 protocol timeout function
                       obj.pingcnt = obj.pingcnt + 1;
                       r = 1;
                    else
                       r = 0;
                    end
                else                    
                    r = 1;
                end                                
            else
                r = 0;
            end
        end
    end
    
end

