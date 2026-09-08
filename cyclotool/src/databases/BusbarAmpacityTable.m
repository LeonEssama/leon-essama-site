function DB = BusbarAmpacityTable()
%BUSBARAMPACITYTABLE  Base thermal current rating of the converter busbars.
%
%   DB = BusbarAmpacityTable() returns a struct array, one entry per
%   copper busbar profile, with fields:
%
%     Profile        char   - label, 'n x (W x T)'
%     nBars          double - number of parallel bars [-]
%     Width_mm       double - bar width  W [mm]
%     Thickness_mm   double - bar thickness T [mm]
%     I_bare_lt16    double - bare bar,    f < 16 Hz [A]
%     I_bare_gt20    double - bare bar,    f > 20 Hz [A]
%     I_painted_lt16 double - painted bar, f < 16 Hz [A]
%     I_painted_gt20 double - painted bar, f > 20 Hz [A]
%     Source         char   - provenance of the four current values
%
%   REFERENCE CONDITIONS of the tabulated currents
%     Ambient 35 degC, bar surface 65 degC, altitude < 1000 m, single
%     circuit, no adjacent-bar derating. Deviations are covered by the
%     correction factors k1..k5 (see busbar_k_factors.m).
%
%   STANDARDS
%     No IEC/IEEE requirement found for this item. These currents and the
%     associated k-factor scheme come from the BBC/ABB Schaltanlagen-
%     Handbuch, chapter 13 (Bild 13-4, Tabellen 13-13 and 13-14). They are
%     manufacturer/industry practice, not a standard requirement. IEC
%     61439-1 covers temperature-rise verification of assemblies but does
%     not publish busbar ampacity tables.
%
%   FREQUENCY BANDS
%     The table is given for two bands only, f < 16 Hz and f > 20 Hz.
%     There is NO data between 16 Hz and 20 Hz; busbar_check.m resolves
%     that gap conservatively and warns. This is why the k4 (frequency)
%     factor is 1 throughout: the frequency effect is carried by the
%     choice of band, not by k4.
%
%   Entries 1..4 are tabulated values, transcribed verbatim from
%   Schienenueberpruefung.xlsx, sheet 'blanke Schienen'/'gestrichene
%   Schienen', rows 5..8, columns H..K.
%
%   Entry 5 is NOT tabulated. In the source workbook (row 9) only the
%   bare/<16 Hz value is given; the other three are derived from it and
%   from entry 3. Those derivations are reproduced here explicitly so the
%   assumptions stay visible instead of being frozen into constants:
%
%     I_bare_gt20    = I_bare_lt16 / F150_FREQ_RATIO
%     I_painted_lt16 = I_bare_lt16 * I_painted_lt16(3) / I_bare_lt16(3)
%     I_painted_gt20 = I_bare_gt20 * I_painted_gt20(3) / I_bare_gt20(3)
%
%   PROFILE IDENTITY OF ENTRY 5 - CONFIRMED
%     The source workbook labels this profile inconsistently: '2 x (150 x
%     20)' in the base table and '1 x (150 x 10)' in the rows that use it.
%     It is a SINGLE 150 x 20 bar, confirmed by the MEGADRIVE CYCLO busbar
%     arrangement drawing, which labels both the motor-side and line-side
%     cable connection bars '1 x 150 x 20'. A 150 x 20 bar has the same cooling
%     perimeter as the 160 x 10 bar of entry 3 (2*(150+20) = 2*(160+10) =
%     340 mm), so for an equal temperature rise the rating scales as the
%     square root of the cross-section:
%       I = 2470 A * sqrt(3000 mm2 / 1600 mm2) = 3382 A, vs 3350 A
%       tabulated (+1 %). At 150 x 10 the same model gives 2251 A (-33 %)
%       and at 2 x (150 x 20), 6025 A (+80 %).
%     CONFIRMED against the busbar layout drawing (Schienenplan sheet),
%     which labels both cable connection bars '1 x 150 x 20'. The
%     perimeter/sqrt(A) inference above agreed with it to 1 %. The two
%     inconsistent labels in the source workbook are both wrong.
%     The correction has no numerical effect either way: Tabelle 13-13 has
%     no single-bar entry, so k3 = 1 for this profile at any thickness.

%% Tabulated profiles (verbatim) -----------------------------------------
SRC_TAB = 'Schienenueberpruefung.xlsx rows 5..8 (BBC/ABB Schaltanlagen-Handbuch ch.13)';

DB(1) = entry('2 x (100 x 10)', 2, 100, 10, 2890, 2480, 3310, 2850, SRC_TAB);
DB(2) = entry('2 x (120 x 10)', 2, 120, 10, 3390, 2860, 3900, 3280, SRC_TAB);
DB(3) = entry('1 x (160 x 10)', 1, 160, 10, 2470, 2220, 3010, 2700, SRC_TAB);
DB(4) = entry('2 x (160 x 10)', 2, 160, 10, 4400, 3590, 5060, 4130, SRC_TAB);

%% Derived profile -------------------------------------------------------
% Only I_bare_lt16 is a given value. The rest follow the workbook's own
% derivation, restated as named constants.
I150_BARE_LT16  = 3350;   % [A]  given, workbook cell H9
F150_FREQ_RATIO = 1.12;   % [-]  workbook cell I9, '=H9/1.12'.
                          %      ENGINEERING ESTIMATE: this is the <16/>20 Hz
                          %      ratio of entry 3 (2470/2220 = 1.1126)
                          %      rounded up to 1.12, i.e. marginally
                          %      conservative. No source is given in the
                          %      workbook.

I150_bare_gt20    = I150_BARE_LT16 / F150_FREQ_RATIO;
I150_painted_lt16 = I150_BARE_LT16 * DB(3).I_painted_lt16 / DB(3).I_bare_lt16;
I150_painted_gt20 = I150_bare_gt20 * DB(3).I_painted_gt20 / DB(3).I_bare_gt20;

DB(5) = entry('1 x (150 x 20)', 1, 150, 20, ...
    I150_BARE_LT16, I150_bare_gt20, I150_painted_lt16, I150_painted_gt20, ...
    sprintf(['Derived: H9 = %g A given; >20 Hz via ratio %g; painted ' ...
             'columns scaled from the 1 x (160 x 10) profile'], ...
             I150_BARE_LT16, F150_FREQ_RATIO));

%% Validation ------------------------------------------------------------
for k = 1:numel(DB)
    I = [DB(k).I_bare_lt16, DB(k).I_bare_gt20, ...
         DB(k).I_painted_lt16, DB(k).I_painted_gt20];
    if any(~isfinite(I)) || any(I <= 0)
        error('BusbarAmpacityTable:BadRating', ...
            'Entry %d (%s) has a non-finite or non-positive rating.', ...
            k, DB(k).Profile);
    end
    if DB(k).I_bare_lt16 < DB(k).I_bare_gt20 || ...
       DB(k).I_painted_lt16 < DB(k).I_painted_gt20
        warning('BusbarAmpacityTable:FrequencyOrder', ...
            ['Entry %d (%s): the >20 Hz rating exceeds the <16 Hz rating. ' ...
             'Skin/proximity effect should make the opposite true.'], ...
            k, DB(k).Profile);
    end
    if DB(k).I_painted_lt16 < DB(k).I_bare_lt16
        warning('BusbarAmpacityTable:FinishOrder', ...
            ['Entry %d (%s): the painted rating is below the bare rating. ' ...
             'Paint raises emissivity and should increase it.'], ...
            k, DB(k).Profile);
    end
end

end

%% ========================================================================
function e = entry(profile, n, w, t, b16, b20, p16, p20, src)
%ENTRY  Build one table record.
e = struct( ...
    'Profile',        profile, ...
    'nBars',          n, ...
    'Width_mm',       w, ...
    'Thickness_mm',   t, ...
    'I_bare_lt16',    b16, ...
    'I_bare_gt20',    b20, ...
    'I_painted_lt16', p16, ...
    'I_painted_gt20', p20, ...
    'Source',         src);
end
