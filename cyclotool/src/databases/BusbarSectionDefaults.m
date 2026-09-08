function S = BusbarSectionDefaults()
%BUSBARSECTIONDEFAULTS  Default busbar sections of an SR module.
%
%   S = BusbarSectionDefaults() returns a struct array, one entry per
%   busbar section, reproducing the eight sections of
%   Schienenueberpruefung.xlsx (rows 14..24 of both sheets).
%
%   Fields
%     Name         char   - section designation (German, as in the source)
%     NameEN       char   - English designation
%     Profile      char   - must match a BusbarAmpacityTable Profile label
%     CurrentBasis char   - 'Motor' | 'Line' | 'Stack', see busbar_check.m
%     FreqBasis    char   - 'Motor' | 'Line'
%     Orientation  char   - 'horizontal' | 'vertical'
%     RunLength_m  double - run length [m]. READ ONLY WHEN Orientation is
%                           'vertical': Tab. 13-13 exempts vertical runs of
%                           2 m or less from the arrangement derating.
%                           Horizontal bars are derated regardless of
%                           length, so the value is unused there and is set
%                           to Inf. Inf is the fail-safe default: it means
%                           'assume a long run', so flipping a section to
%                           vertical keeps the derating applied rather than
%                           silently granting a 20 % rating increase.
%     k3_override  double - NaN to compute from Tab. 13-13
%
%   WHY RUN LENGTH IS BLANK ON MOST ROWS
%   Tab. 13-13 derates bars in HORIZONTAL position, or vertical runs
%   LONGER THAN 2 m. Length therefore only affects the result for a
%   vertical section. Horizontal sections carry NaN, meaning 'not
%   applicable', and the column shows blank for them. Only 'Netzseite
%   Steigschiene' needs a real number.
%
%   ORIENTATION AND RUN LENGTH are not recorded anywhere in the source
%   workbook. The values below are INFERRED from the k3 the workbook
%   applies to each row, so that the tool reproduces the workbook exactly:
%   every 2-bar section carries the Tab. 13-13 factor except 'Netzseite
%   Steigschiene', which carries k3 = 1. A riser is vertical, and Tab.
%   13-13 exempts vertical runs of 2 m or less, so a short vertical run is
%   the only consistent reading. CONFIRM the actual routing lengths before
%   issuing a design; if the riser exceeds 2 m its rating drops by 20 %.
%
%   k3_override on 'Stapelverschienung': the source workbook applies
%   k3 = 0.8 (bare) / 0.85 (painted) to this section even though it is a
%   SINGLE bar, for which Tab. 13-13 has no entry and the other single-bar
%   sections are not derated. The cell links to the master k3 cell, so this
%   is plausibly a copy-paste error, but it is conservative and it is what
%   the released workbook does. It is pinned here as an explicit override,
%   with NaN meaning 'compute'. Set it to NaN to remove the derating once
%   the intent is confirmed.

S(1) = sec('Sternpunkt Stromrichter beim Stapel', ...
           'Converter star point at the stack', ...
           '2 x (160 x 10)', 'Motor', 'Motor', 'horizontal', NaN, NaN);

% Profile confirmed against the busbar layout drawing (Schienenplan),
% which labels this bar '1 x 150 x 20'. The source workbook's row label
% '1 x (150 x 10)' is wrong.
S(2) = sec('Motorseitige Kabelanschlussschiene', ...
           'Motor-side cable connection bar', ...
           '1 x (150 x 20)', 'Motor', 'Motor', 'horizontal', NaN, NaN);

S(3) = sec('Motorphase Stromrichter beim Stapel', ...
           'Motor phase at the stack', ...
           '2 x (160 x 10)', 'Motor', 'Motor', 'horizontal', NaN, NaN);

% Profile confirmed against the busbar layout drawing: '1 x 150 x 20'.
S(4) = sec('Netzseite Kabelanschlussschiene', ...
           'Line-side cable connection bar', ...
           '1 x (150 x 20)', 'Line', 'Line', 'horizontal', NaN, NaN);

S(5) = sec('Netzseite Steigschiene', ...
           'Line-side riser bar', ...
           '2 x (100 x 10)', 'Line', 'Line', 'vertical', 2, NaN);

S(6) = sec('Netzseite Horizontalschiene', ...
           'Line-side horizontal bar', ...
           '2 x (120 x 10)', 'Line', 'Line', 'horizontal', NaN, NaN);

S(7) = sec('Stapelverschienung', ...
           'Stack busbar', ...
           '1 x (160 x 10)', 'Stack', 'Line', 'horizontal', NaN, -1);

S(8) = sec('Wandlerverschienung', ...
           'Current-transformer busbar', ...
           '2 x (120 x 10)', 'Stack', 'Line', 'horizontal', NaN, NaN);

end

%% ========================================================================
function s = sec(name, nameEN, profile, curBasis, freqBasis, orient, L, k3)
%SEC  Build one section record.
%
%   k3 = -1 is a sentinel meaning 'use the workbook's linked k3 for a
%   2-bar horizontal arrangement of the same finish'. busbar_check.m
%   resolves it; NaN means compute normally from Tab. 13-13.
s = struct( ...
    'Name',         name, ...
    'NameEN',       nameEN, ...
    'Profile',      profile, ...
    'CurrentBasis', curBasis, ...
    'FreqBasis',    freqBasis, ...
    'Orientation',  orient, ...
    'RunLength_m',  L, ...
    'k3_override',  k3);
end
