classdef phy_Object < handle
    % Minimal phyloCell object shim for loading legacy segmentation MAT files.
    properties
        n = 0
        x = []
        y = []
        area = 0
        ox = 0
        oy = 0
        vx = 0
        vy = 0
        image = 0
        mother = 0
        daughterList = []
        divisionTimes = []
        budTimes = []
        Mean = 0
        Max = 0
        Min = 0
        Median = 0
        Nrpoints = 0
        Mean_cell = 0
        htext = []
        hcontour = []
        move = 0
        selected = false
        dependentData = 0
        fluoMean = 0
        fluoVar = 0
        fluoMin = 0
        fluoMax = 0
        fluoCytoMean = 0
        fluoCytoVar = 0
        fluoCytoMin = 0
        fluoCytoMax = 0
        fluoNuclMean = 0
        fluoNuclVar = 0
        fluoNuclMin = 0
        fluoNuclMax = 0
    end

    methods
        function obj = phy_Object(N, X, Y, image, area, ox, oy, mother)
            if nargin > 0
                obj.n = N;
                obj.x = X;
                obj.y = Y;
                obj.image = image;
                obj.area = area;
                obj.ox = ox;
                obj.oy = oy;
                obj.mother = mother;
            end
        end
    end
end
