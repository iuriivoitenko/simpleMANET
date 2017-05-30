classdef ALOHA
    %ALOHA class 
    %   Represents pure ALOHA MAC protocol
    
    properties
        protoname = 'ALOHA';
    end
    
    methods
        function obj = ALOHA()            
        end
        
        function [b, c] = isBusy( obj, err, linkbusy )
            c = 0; % collision marker
            if (err == 1)
                b = 1;
            elseif linkbusy > 0 && err == 0 
                b = 1;
                c = 1;
            elseif linkbusy > 0
                b = 1;
            else
                b = 0;
            end
        end
    end    
end

