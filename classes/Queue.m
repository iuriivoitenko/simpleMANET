classdef Queue < handle
    properties ( Access = private )
        elements
        size
        nextInsert
        nextRemove
    end

    properties ( Dependent = true )
        NumElements
    end

    methods
        function obj = Queue(size)
            obj.size = size;
            obj.elements = cell(1, size);
            obj.nextInsert = 1;
            obj.nextRemove = 1;
        end
        function add( obj, el )
            if (obj.NumElements() < obj.size)
                if obj.nextInsert == length( obj.elements )
                    obj.elements = [ obj.elements, cell( 1, length( obj.elements ) ) ];
                end
                obj.elements{obj.nextInsert} = el;
                obj.nextInsert = obj.nextInsert + 1;
            end
        end
        function el = remove( obj )
            if obj.isEmpty()
                error( 'Queue is empty' );
            end
            el = obj.elements{ obj.nextRemove };
            obj.elements{ obj.nextRemove } = [];
            obj.nextRemove = obj.nextRemove + 1;
            % Trim "elements"
            if obj.nextRemove > ( length( obj.elements ) / 2 )
                ntrim = fix( length( obj.elements ) / 2 );
                obj.elements = obj.elements( (ntrim+1):end );
                obj.nextInsert = obj.nextInsert - ntrim;
                obj.nextRemove = obj.nextRemove - ntrim;
            end
        end
        function tf = isEmpty( obj )
            tf = ( obj.nextRemove >= obj.nextInsert );
        end
        function n = get.NumElements( obj )
            n = obj.nextInsert - obj.nextRemove;
        end
        function s = get.size( obj )
            s = obj.size;
        end
    end
end
