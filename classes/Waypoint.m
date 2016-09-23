classdef Waypoint < handle
    %   Waypoint class represents a random waypoint model for the Node.  
    %   'time' property shows how many milliseconds a Node will stay on given
    %   course. Function 'timer' decrements 'time' each timeout tick. When
    %   'time' reaches zero, a new dir and speed is generated.
    %   
    
    properties 
       time
       speed
       dir 
    end
    
    properties (Access = private)
       maxspeed
       simtime
    end
    
    methods
        function obj = Waypoint(simtime, speed)
            obj = obj.direction(simtime, speed);
            obj.maxspeed = speed;
            obj.simtime = simtime;
        end 
        
        function obj = timeout(obj)
            if (obj.time <= 0)
                obj = obj.direction(obj.simtime, obj.maxspeed);
            else
                obj.time = obj.time - 1;    
            end            
        end
        
        function obj = direction(obj, simtime, speed)
            obj.time = randi([0 simtime],1,1);
            obj.speed = randi([0 speed],1,1); % node movement speed
            obj.dir = randi([0 360],1,1);     % node direction, degrees            
        end
        
        function s = get.speed( obj )
            s = obj.speed;
        end        
        
        function d = get.dir( obj )
            d = obj.dir;
        end                
    end
    
end

