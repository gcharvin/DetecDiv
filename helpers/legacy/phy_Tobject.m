classdef phy_Tobject < handle
    % Minimal phyloCell track-object shim for loading legacy segmentation MAT files.
    properties
        Obj = phy_Object
        N = 0
        detectionFrame = 0
        birthFrame = 0
        lastFrame = 0
        mothers = []
        lostFrames = []
        divisionTimes = []
        budTimes = []
    end

    properties (SetAccess = private)
        mother = 0
        daughterList = []
        selected = false
    end

    methods
        function obj = phy_Tobject(n, c)
            if nargin > 0
                obj.N = n;
                obj.Obj = c;
            end
        end

        function setNumber(obj, val)
            obj.N = val;
            try
                n = num2cell(val * ones(1, numel(obj.Obj)));
                [obj.Obj.n] = n{:};
            catch
            end
        end

        function flag = setMother(obj, val, frameStart)
            if nargin < 3
                frameStart = -inf;
            end
            flag = true;
            if val ~= 0 && obj.mother ~= 0
                flag = false;
                return;
            end
            obj.mother = val;
            try
                for i = 1:numel(obj.Obj)
                    if obj.Obj(i).image >= frameStart
                        obj.Obj(i).mother = val;
                    end
                end
            catch
            end
            if val == 0
                obj.daughterList = [];
                obj.divisionTimes = [];
                obj.budTimes = [];
            end
        end

        function addDaughter(obj, daughtercell, divisionStart, divisionEnd)
            obj.daughterList = [obj.daughterList daughtercell];
            if nargin >= 3
                obj.budTimes = [obj.budTimes divisionStart];
            end
            if nargin >= 4
                obj.divisionTimes = [obj.divisionTimes divisionEnd];
            end
        end
    end
end
