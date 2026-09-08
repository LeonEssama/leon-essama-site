function V = ExcitationVoltageClasses()
%EXCITATIONVOLTAGECLASSES  Standard excitation voltage classes.
%
%   V = ExcitationVoltageClasses() returns an Nx2 matrix where each row
%   is [UV0_class, Ufmax_class] (V), sorted ascending by UV0_class.
%   excitation_calculation.m selects the first row whose UV0_class
%   covers the calculated required excitation voltage.
%
%   Data values are unchanged from the original.

V = [ ...
    230  265;
    380  440;
    400  465;
    415  480;
    440  510;
    460  530;
    480  555;
    500  580;
    525  610;
    575  670;
    600  700;
    660  765;
    690  800;
    800  915;
    990  1160;
    1200 1380];

%% Validation: the "first class >= required" search in
%% excitation_calculation.m depends on this being sorted ascending
if any(diff(V(:,1)) <= 0)
    error('ExcitationVoltageClasses:NotSorted', ...
        'Voltage classes must be strictly ascending by UV0_class.');
end

end
