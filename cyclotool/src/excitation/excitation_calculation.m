function E = excitation_calculation(Input)
%EXCITATION_CALCULATION  Field/excitation supply sizing (DCS880 selection).
%
%   E = excitation_calculation(Input)
%
%   Computes the required excitation no-load voltage (Excel/VBA-derived
%   formula), rounds up to the nearest standard excitation voltage class,
%   sizes the excitation transformer, selects a DCS880 field unit and its
%   matching fan, and picks surge arrester ratings for the calculated,
%   selected and oversized voltage options.
%
%   The DCS880 / arrester lookups have been vectorized (same "first
%   match" selection logic, no loop).
%
%   Required voltage formula: per ABB TN 95/679 Auslegungsblatt (p.17),
%   the numerator factor depends on drive type -- 1.15 for a Rohrmuehle
%   (tube mill, Hochlauf case), or 2 for "Andere Antriebe" (other
%   drives: rolling mill, hoist/conveyor), which the source document
%   identifies as the case needing the largest voltage reserve. Only
%   the Rohrmuehle factor was implemented previously; Input.DriveType
%   now selects between them (defaults to Rohrmuehle if not supplied,
%   preserving prior behavior).

if Input.If_nom == 0
    error('excitation_calculation:ZeroIfNom', 'Input.If_nom must be nonzero.');
end

E = struct();

%% Required excitation voltage (Excel formula)
iD = Input.If_max / Input.If_nom;
x = 1 - Input.VoltageVariation/100;
if isfield(Input,'DriveType') && ...
        strcmpi(Input.DriveType,'Other (Walzwerk/Foerderantrieb)')
    excFactor = 2;
else
    excFactor = 1.15;
end
E.UV0_calc = excFactor * Input.Uf_max / (1.35 * (x*cosd(10) - 0.05*iD));

%% Standard excitation voltage class (first class >= required)
VClass = ExcitationVoltageClasses();
idxCalc = find(VClass(:,1) >= E.UV0_calc, 1, 'first');
if isempty(idxCalc)
    error('excitation_calculation:VoltageClassExceeded', ...
        'Excitation voltage exceeds available classes');
end
E.UV0_calc_class   = VClass(idxCalc, 1);
E.Ufmax_calc_class = VClass(idxCalc, 2);

E.UV0_selected  = Input.UV0_Selected;
E.UV0_oversized = Input.UV0_Oversized;

%% Excitation power and transformer sizing
E.SEx = sqrt(3) * E.UV0_selected * 0.817 * Input.If_nom / 1000;
E.STr = 1.15 * E.SEx;
E.I1P = E.STr * 1000 / (sqrt(3) * Input.UL_exc);

%% DCS880 excitation unit selection (first unit meeting both limits)
DB = DCS880_FieldDatabase();
match = [DB.UV0] >= E.UV0_selected & [DB.Imax] >= Input.If_max;
idx = find(match, 1, 'first');
if isempty(idx)
    error('excitation_calculation:NoDCS880Match', 'No suitable DCS880 found.');
end
E.DCS_Type = DB(idx).Type;
E.DCS_Size = DB(idx).Size;
E.DCS_UV0  = DB(idx).UV0;
E.Imax_Converter = DB(idx).Imax;

if idx < length(DB)
    E.DCS_Type_Oversized = DB(idx+1).Type;
else
    E.DCS_Type_Oversized = 'N/A';
end

E.DCS_Utilization  = 100 * Input.If_max / E.Imax_Converter;
E.DCS_Margin       = E.Imax_Converter - Input.If_max;
E.DCS_MarginPercent = 100 * E.DCS_Margin / E.Imax_Converter;

%% Fan selection matching the chosen DCS880 size
FanDB = DCS880_FanDatabase();
fanIdx = find(strcmp({FanDB.Size}, E.DCS_Size), 1);
if isempty(fanIdx)
    error('excitation_calculation:NoFanMatch', ...
        'No fan found for DCS880 size %s.', E.DCS_Size);
end
E.FanType            = FanDB(fanIdx).Fan;
E.FanVoltage         = FanDB(fanIdx).Voltage;
E.FanFrequency       = FanDB(fanIdx).Frequency;
E.FanPower           = FanDB(fanIdx).Power;
E.FanCurrent         = FanDB(fanIdx).Current;
E.FanBlockingCurrent = FanDB(fanIdx).BlockingCurrent;

%% Surge arrester selection (calculated / selected / oversized voltages)
ArresterLevels = [900 1000 1300 1600];
E.Arrester_Calculated = selectArresterLevel(ArresterLevels, E.UV0_calc);
E.Arrester_Selected   = selectArresterLevel(ArresterLevels, E.UV0_selected);
E.Arrester_Oversized  = selectArresterLevel(ArresterLevels, E.UV0_oversized);

%% Voltage class warning
if E.UV0_selected > 990
    E.Warning = 'DC field voltage requires 990 V class converter';
else
    E.Warning = '';
end

end

%% ==========================================================
function level = selectArresterLevel(levels, voltage)
%SELECTARRESTERLEVEL  First arrester level >= voltage, else the highest.
idx = find(levels >= voltage, 1, 'first');
if isempty(idx)
    idx = length(levels);
end
level = levels(idx);
end
