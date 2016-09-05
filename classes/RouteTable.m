classdef RouteTable < handle
    %    
    %   Generic route table class
    %
    properties (Access = private)
        main = table;        
    end
    
    methods
        
        function obj = add(obj,dest,next,hops,metric,flags) 
            
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end
            
            if ~ischar(next) && isnumeric(next)
                next = num2str(next);
            end
            
%             if ~ischar(flags)
%                 flags = char(flags);
%             end             
            
            entry = {{dest},{next},hops,metric,{flags}};
            rtnew = cell2table(entry,...
                'VariableNames',{'dest','next','hops','metric','flags'});
            rtnew.Properties.RowNames = strcat(rtnew.dest,'-',num2str(hops));
            obj.main = [obj.main; rtnew];   
            obj.main = unique(obj.main);
        end
        
        function obj = remove(obj,dest)
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end
            rows = strcmpi(obj.main.dest, dest);
            obj.main(rows,:) = [];
        end
        
        function out = contains(obj,dest,hops)            
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end            
            rows = strcmpi(obj.main.dest, dest);
            h = obj.main.hops == hops;
            rr = rows & h;
            if sum(rr) > 0
                out = 1;
            else
                out = 0;
            end
        end
        
        function obj = updateMetric(obj,dest,metric)
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end             
            rows = strcmpi(obj.main.dest, dest);
            obj.main(rows,:).metric = metric;
        end
        
        function obj = updateHops(obj,dest,hops)
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end             
            rows = strcmpi(obj.main.dest, dest);
            obj.main(rows,:).hops = hops;
        end  
        
        function obj = updateFlags(obj,dest,flags)
            if ~ischar(dest) && isnumeric(dest)
                dest = num2str(dest);
            end                         
            rows = strcmpi(obj.main.dest, dest);
            obj.main(rows,:).flags = {flags};
        end         
        
        function out = neighbors(obj)
            rows = obj.main.hops==1;
            out = sum(rows);
        end
        
        function out = show(obj)
            out = obj.main;
        end                
        
    end
    
end

