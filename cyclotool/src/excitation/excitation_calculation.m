function E = excitation_calculation(Input)
%EXCITATION_CALCULATION  Field/excitation supply sizing (DCS880 selection).
%
%   E = excitation_calculation(Input)
%
%   Computes the required excitation no-load voltage, rounds up to the
%   nearest standard excitation voltage class, applies altitude-based
%   converter current derating, sizes the excitation transformer (with a
%   user-adjustable margin), selects a DCS880 field unit and its matching
%   fan (by frame Size AND supply Frequency), sizes the thermal-relay/CT
%   protection, and picks surge arrester ratings -- for both the selected
%   voltage and the oversized/downsized target voltage, each as a full,
%   independent re-sizing of the downstream chain.
%
%   Source: user-supplied reference workbook "Excitation_design.xlsx",
%   sheet "Excitation". No IEC/IEEE/NEMA/ANSI standard is cited on that
%   workbook for any formula below; every formula is the vendor/
%   reference-document's own ("Formula regarding Turgi (Peter
%   Burmeister)", cell E7), reproduced verbatim with its cell reference
%   noted. DCS_Utilization/DCS_Margin(%) are NOT workbook cells -- they
%   are an engineering estimate added by this tool, computed against the
%   altitude-derated current capacity rather than the catalog nameplate
%   value.
%
%   Required Input fields (all SI/engineering units as named):
%     Uf_nom, Uf_max          [Vdc]   Nominal / maximum excitation voltage
%     If_nom, If_max          [Adc]   Nominal / maximum excitation current
%     VoltageVariation        [%]     Supply voltage variation, deltaUL
%     Altitude                [m]     Site altitude above sea level
%     FanFrequency             [Hz]    Fan supply frequency (50 or 60)
%     UL_exc                  [V]     Transformer primary supply voltage
%     UV0_Selected, UV0_Oversized [VAC] Selected / oversized excitation
%                                       secondary voltage (manual choice)
%     TrafoMarginPercent      [%]     Transformer sizing margin, 0-40
%                                       (workbook D57)
%     CTRatio                 [-]     Thermal-relay CT ratio, ":1"
%                                       (workbook D72)

if Input.If_nom == 0
    error('excitation_calculation:ZeroIfNom', 'Input.If_nom must be nonzero.');
end

E = struct();

%% Required excitation voltage (workbook F45)
iD = Input.If_max / Input.If_nom;
x = 1 - Input.VoltageVariation/100;
E.UV0_calc = 1.15 * Input.Uf_max / (1.35 * (x*cosd(10) - 0.05*iD));

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

%% Altitude-based converter current derating (workbook F47)
if Input.Altitude >= 1000
    E.AltitudeDerating = -0.01*Input.Altitude + 110;   % % of nameplate Imax
else
    E.AltitudeDerating = 100;                          % % of nameplate Imax
end

%% Thermal relay / CT protection setting current (workbook F72)
E.RelaySetting_A = Input.If_nom * 1.1 / Input.CTRatio * 0.816;

%% "Add 280A4 >600V" protection check (workbook F73, tests NOMINAL Uf)
if Input.Uf_nom > 600
    E.Add280A4 = 'yes';
else
    E.Add280A4 = 'not required';
end

%% Excitation unit / fan databases (shared by both sizing runs below)
DB    = DCS880_FieldDatabase();
FanDB = DCS880_FanDatabase();

%% Full downstream sizing chain (SEx/STr/I1P/I1S/DCS880/fan), run once
%% for the selected voltage and once for the oversized/downsized target
%% voltage -- the workbook's "over/downsizing to" column is a complete
%% parallel recomputation, not merely "the next catalog part".
Sel = sizeExcitationChain(E.UV0_selected,  Input, DB, FanDB, E.AltitudeDerating);
Ovr = sizeExcitationChain(E.UV0_oversized, Input, DB, FanDB, E.AltitudeDerating);

E.SEx = Sel.SEx;
E.STr = Sel.STr;
E.I1P = Sel.I1P;
E.I1S = Sel.I1S;

E.DCS_Type               = Sel.DCS_Type;
E.DCS_Size               = Sel.DCS_Size;
E.DCS_UV0                = Sel.DCS_UV0;
E.Imax_Converter         = Sel.Imax_Converter;
E.Imax_Converter_Derated = Sel.Imax_Converter_Derated;
E.DCS_Utilization        = Sel.DCS_Utilization;
E.DCS_Margin             = Sel.DCS_Margin;
E.DCS_MarginPercent      = Sel.DCS_MarginPercent;

E.FanType            = Sel.FanType;
E.FanVoltage         = Sel.FanVoltage;
E.FanTolerance       = Sel.FanTolerance;
E.FanConnection      = Sel.FanConnection;
E.FanFrequency       = Sel.FanFrequency;
E.FanPower           = Sel.FanPower;
E.FanCurrent         = Sel.FanCurrent;
E.FanBlockingCurrent = Sel.FanBlockingCurrent;

E.SEx_Oversized                    = Ovr.SEx;
E.STr_Oversized                    = Ovr.STr;
E.I1P_Oversized                    = Ovr.I1P;
E.I1S_Oversized                    = Ovr.I1S;
E.DCS_Type_Oversized               = Ovr.DCS_Type;
E.DCS_Size_Oversized               = Ovr.DCS_Size;
E.Imax_Converter_Oversized         = Ovr.Imax_Converter;
E.Imax_Converter_Derated_Oversized = Ovr.Imax_Converter_Derated;
E.FanType_Oversized                = Ovr.FanType;
E.FanPower_Oversized               = Ovr.FanPower;
E.FanCurrent_Oversized             = Ovr.FanCurrent;
E.FanBlockingCurrent_Oversized     = Ovr.FanBlockingCurrent;

%% Surge arrester selection (calculated / selected / oversized voltages)
ArresterLevels = [900 1000 1300 1600];
E.Arrester_Calculated = selectArresterLevel(ArresterLevels, E.UV0_calc);
E.Arrester_Selected   = selectArresterLevel(ArresterLevels, E.UV0_selected);
E.Arrester_Oversized  = selectArresterLevel(ArresterLevels, E.UV0_oversized);

%% Warnings
Warnings = {};
if E.UV0_selected > 990
    Warnings{end+1} = 'DC field voltage requires 990 V class converter';
end
if ~isempty(Sel.FanWarning)
    Warnings{end+1} = Sel.FanWarning;
end
if ~isempty(Ovr.FanWarning)
    Warnings{end+1} = Ovr.FanWarning;
end
E.Warning = strjoin(Warnings, ' | ');

end

%% ==========================================================
function R = sizeExcitationChain(UV0, Input, DB, FanDB, AltitudeDerating)
%SIZEEXCITATIONCHAIN  Excitation power/transformer/DCS880/fan sizing for
%one target excitation secondary voltage UV0 (workbook F51/F57/F58/F59
%and the DCS880/fan selection), factored out so the identical chain runs
%for both the "selected" and the "oversized" voltage columns.

R = struct();

%% Excitation power and transformer sizing (workbook F51/F57/F58/F59)
R.SEx = sqrt(3) * UV0 * 0.817 * Input.If_nom / 1000;   % kVA

m = Input.TrafoMarginPercent;
if m < 0 || m > 40
    error('excitation_calculation:TrafoMarginOutOfRange', ...
        'Input.TrafoMarginPercent must be within [0, 40] %% (got %.4g).', m);
end
R.STr = R.SEx * (1 + m/100);                            % kVA

R.I1P = R.STr * 1000 / (sqrt(3) * Input.UL_exc);         % A, transformer primary side
R.I1S = R.STr * 1000 / (sqrt(3) * UV0);                  % A, transformer secondary / converter side

%% DCS880 excitation unit selection, altitude-derated Imax (workbook Y column)
ImaxDerated = [DB.Imax] * AltitudeDerating / 100;
match = [DB.UV0] >= UV0 & ImaxDerated >= Input.If_max;
idx = find(match, 1, 'first');
if isempty(idx)
    error('excitation_calculation:NoDCS880Match', ...
        'No DCS880 unit meets UV0 >= %.4g V and altitude-derated Imax >= %.4g A.', ...
        UV0, Input.If_max);
end
R.DCS_Type               = DB(idx).Type;
R.DCS_Size               = DB(idx).Size;
R.DCS_UV0                = DB(idx).UV0;
R.Imax_Converter         = DB(idx).Imax;
R.Imax_Converter_Derated = ImaxDerated(idx);

%% Utilization/margin: engineering estimate (not a workbook cell), based
%% on the altitude-derated capacity, the true usable current limit.
R.DCS_Utilization   = 100 * Input.If_max / R.Imax_Converter_Derated;
R.DCS_Margin        = R.Imax_Converter_Derated - Input.If_max;
R.DCS_MarginPercent = 100 * R.DCS_Margin / R.Imax_Converter_Derated;

%% Fan selection: matches Size AND Frequency (workbook AD helper "S"/"-"
%% flags on Size x Frequency). No fan-table entry exists for every
%% Size/Frequency combination -- do not fabricate one ("never guess");
%% report N/A and continue instead of aborting the whole calculation.
fanIdx = find(strcmp({FanDB.Size}, R.DCS_Size) & [FanDB.Frequency] == Input.FanFrequency, 1);
if isempty(fanIdx)
    R.FanType            = 'N/A';
    R.FanVoltage         = 'N/A';
    R.FanTolerance       = 'N/A';
    R.FanConnection      = 'N/A';
    R.FanFrequency       = Input.FanFrequency;
    R.FanPower           = NaN;
    R.FanCurrent         = NaN;
    R.FanBlockingCurrent = NaN;
    R.FanWarning = sprintf(...
        ['No fan-table entry for DCS880 size %s at %g Hz (reference ' ...
         'workbook has none either); consult the ABB DCS880 hardware manual.'], ...
        R.DCS_Size, Input.FanFrequency);
else
    R.FanType            = FanDB(fanIdx).Fan;
    R.FanVoltage         = FanDB(fanIdx).Voltage;
    R.FanTolerance       = FanDB(fanIdx).Tolerance;
    R.FanConnection      = FanDB(fanIdx).Connection;
    R.FanFrequency       = FanDB(fanIdx).Frequency;
    R.FanPower           = FanDB(fanIdx).Power;
    R.FanCurrent         = FanDB(fanIdx).Current;
    R.FanBlockingCurrent = FanDB(fanIdx).BlockingCurrent;
    R.FanWarning = '';
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
