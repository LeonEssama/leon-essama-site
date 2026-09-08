function H = build_busbar_tab(parentTab, getInputFcn)
%BUILD_BUSBAR_TAB  Build the "Busbar Check" tab inside CycloGUI.
%
%   H = build_busbar_tab(parentTab, getInputFcn)
%
%   parentTab    a uitab created in CycloGUI_v2_0.m
%   getInputFcn  function handle returning the current Input struct, e.g.
%                @() buildInput(Thy). Called when the user presses Check,
%                so the tab always evaluates live values.
%
%   RETURNS H, a struct of handles and accessor function handles:
%     H.refresh()        recompute now (call after a dimensioning run)
%     H.getSections()    current section list (reflects user edits)
%     H.setSections(S)   replace the section list and redraw
%     H.getResult()      most recent busbar_check output, [] if never run
%     H.getSettings()    all persistable settings as one struct
%     H.setSettings(S)   restore them
%
%   STATE LIVES IN parentTab.UserData, NOT IN H.
%   MATLAB structs have value semantics: a struct returned from this
%   function is a COPY, disconnected from the copy the callbacks mutate.
%   Storing the section list in H would mean the caller never sees the
%   user's table edits, and project save would silently persist the
%   defaults forever. parentTab is a graphics handle object, so its
%   UserData is shared between the callbacks and the caller. Accessors are
%   returned rather than raw data for the same reason.
%
%   THE k1/k2/k5 OVERRIDES ARE TEXT FIELDS, NOT NUMERIC ONES.
%   A numeric uieditfield cannot hold NaN: its Value must be a finite
%   scalar within Limits, and NaN fails that check. Blank therefore
%   carries the "not set" meaning, and str2override maps blank to the NaN
%   that busbar_check expects. It also reads better than a field showing
%   the word NaN.
%
%   INTEGRATION into CycloGUI_v2_0.m: see the accompanying guide.
%
%   NOT EXECUTED: statically reviewed only, no MATLAB runtime was
%   available when this was written.

arguments
    parentTab   (1,1) matlab.ui.container.Tab
    getInputFcn (1,1) function_handle
end

%% ---------------- Shared mutable state ---------------------------------
parentTab.UserData = struct( ...
    'Sections',   BusbarSectionDefaults(), ...
    'LastResult', [], ...
    'CurrentFig', gobjects(1));   % handle of the open distribution figure

H = struct();
H.Tab = parentTab;

g = uigridlayout(parentTab, [3 1]);
g.RowHeight   = {'fit', '1x', 'fit'};
g.ColumnWidth = {'1x'};

%% ---------------- Settings panel ---------------------------------------
p = uipanel(g, 'Title', 'Settings');
p.Layout.Row = 1;
pg = uigridlayout(p, [4 8]);
pg.RowHeight   = {22, 22, 22, 22};
pg.ColumnWidth = {110, 90, 110, 90, 130, 90, '1x', 150};

uilabel(pg, 'Text', 'Min. reserve [p.u.]');
H.Threshold = uieditfield(pg, 'numeric', 'Value', 1.00, ...
    'Limits', [0 Inf], 'LowerLimitInclusive', false, ...
    'ValueDisplayFormat', '%.2f');

uilabel(pg, 'Text', 'Installation');
H.Location = uidropdown(pg, 'Items', {'indoor','outdoor'}, 'Value', 'indoor');

uilabel(pg, 'Text', 'k5 override [-]');
H.k5 = uieditfield(pg, 'text', 'Value', '', ...
    'Tooltip', ['Leave blank to use Tab. 13-14. Above 4000 m it ' ...
                'extrapolates and warns.']);

uilabel(pg, 'Text', '');
H.CheckButton = uibutton(pg, 'Text', 'Run Busbar Check');

uilabel(pg, 'Text', 'k1 override [-]');
H.k1 = uieditfield(pg, 'text', 'Value', '', ...
    'Tooltip', 'Leave blank for 1 (no conductivity data supplied).');

uilabel(pg, 'Text', 'k2 [-]');
% k2 is prefilled with the standard value 1 rather than left blank, so
% the temperature factor is always an explicit, visible design decision.
% Numerically 1 and blank are identical; the difference is that the
% provenance then reads 'override' instead of 'default', which is the
% honest description once a value has been chosen and left in place.
H.k2 = uieditfield(pg, 'text', 'Value', '1', ...
    'Tooltip', ['Standard value 1 = reference 35/65 degC. Read a ' ...
                'different value off Bild 13-4 if the design ' ...
                'temperatures differ.']);

uilabel(pg, 'Text', 'Band gap 16..20 Hz');
H.BandGap = uidropdown(pg, 'Items', {'conservative','error'}, ...
    'Value', 'conservative');

H.Status = uilabel(pg, 'Text', 'Not yet run.', 'FontWeight', 'bold');
H.Status.Layout.Column = [7 8];

% Row 3: which view of the results, and a read-only echo of the site
% conditions that k5 was derived from.
uilabel(pg, 'Text', 'Show');
H.View = uidropdown(pg, ...
    'Items', {'Summary', 'Bare (detail)', 'Painted (detail)'}, ...
    'Value', 'Summary');

H.Info = uilabel(pg, 'Text', ...
    'Altitude is taken from the Excitation tab. Run the check to see it.');
H.Info.Layout.Row    = 3;
H.Info.Layout.Column = [3 8];

% Row 4: opens the current distribution figure for the live IM. Placed
% here rather than in the report code so the drawing can be checked
% against the busbar currents without running a full report.
H.CurrentFigButton = uibutton(pg, 'Text', 'Current Distribution Figure');
H.CurrentFigButton.Layout.Row    = 4;
H.CurrentFigButton.Layout.Column = [1 2];

%% ---------------- Results table ----------------------------------------
rp = uipanel(g, 'Title', 'Results (bare vs painted)');
rp.Layout.Row = 2;
rg = uigridlayout(rp, [1 1]);
H.ResultTable = uitable(rg);

%% ---------------- Section editor ---------------------------------------
sp = uipanel(g, 'Title', ['Busbar sections (editable)  -  RunLength_m ' ...
    'is read only for vertical bars: <= 2 m exempts them from Tab. ' ...
    '13-13 (k3 = 1). Inf means "assume a long run".']);
sp.Layout.Row = 3;
sg = uigridlayout(sp, [1 1]);
sg.RowHeight = {180};

% ColumnFormat is NOT used: it has no effect when Data is a table array.
% The dropdown editors come from the categorical column types built in
% sectionsToTable, which also restrict what the user can enter.
H.SectionTable = uitable(sg, ...
    'Data', sectionsToTable(parentTab.UserData.Sections), ...
    'ColumnEditable', [false true true true true true], ...
    'Tooltip', ['RunLength_m is read only for vertical sections: ' ...
                'Tab. 13-13 exempts vertical runs of 2 m or less. ' ...
                'Blank on horizontal rows means not applicable.']);

%% ---------------- Callbacks and accessors ------------------------------
H.CheckButton.ButtonPushedFcn   = @(~,~) runCheck();
H.View.ValueChangedFcn          = @(~,~) renderView();
H.CurrentFigButton.ButtonPushedFcn = @(~,~) showCurrentFigure();
H.closeCurrentFigure = @closeCurrentFigure;
H.SectionTable.CellEditCallback = @(src, evt) onSectionEdit(src, evt);

H.refresh     = @runCheck;
H.getSections = @() parentTab.UserData.Sections;
H.setSections = @setSections;
H.getResult   = @() parentTab.UserData.LastResult;
H.getSettings = @getSettings;
H.setSettings = @setSettings;

%% ========================================================================
    function runCheck()
        try
            Input = getInputFcn();
        catch err
            setStatus(['Cannot read inputs: ' err.message], [0.6 0 0]);
            return
        end

        % The three k overrides are TEXT fields: blank means "compute".
        % A numeric uieditfield cannot hold NaN, so blank-as-sentinel is
        % the only representation that survives the control.
        [k1v, err1] = str2override(H.k1.Value);
        [k2v, err2] = str2override(H.k2.Value);
        [k5v, err5] = str2override(H.k5.Value);
        for e = {{'k1', err1}, {'k2', err2}, {'k5', err5}}
            if ~isempty(e{1}{2})
                setStatus(sprintf('%s override %s', e{1}{1}, e{1}{2}), ...
                    [0.6 0 0]);
                return
            end
        end

        lastwarn('');
        try
            B = busbar_check(Input, ...
                'Sections',    parentTab.UserData.Sections, ...
                'Threshold',   H.Threshold.Value, ...
                'Location',    H.Location.Value, ...
                'k1',          k1v, ...
                'k2',          k2v, ...
                'k5',          k5v, ...
                'BandGapRule', H.BandGap.Value);
        catch err
            setStatus(['Check failed: ' err.message], [0.6 0 0]);
            H.ResultTable.Data = table();
            return
        end
        warnMsg = lastwarn();

        % The tab and the engine are separate files and can be updated
        % independently. Check the contract explicitly, so a stale
        % busbar_check.m names itself instead of failing later with an
        % opaque "Unrecognized field name".
        problem = checkEngineContract(B);
        if ~isempty(problem)
            setStatus(problem, [0.6 0 0]);
            H.ResultTable.Data = table();
            return
        end

        parentTab.UserData.LastResult = B;
        renderView();
        updateInfo(B);
        showCurrentFigure(Input);   % refresh the distribution drawing

        if B.AllOK
            msg = sprintf('PASS - all %d sections meet reserve >= %.2f p.u.', ...
                height(B.Summary), B.Threshold);
            col = [0 0.45 0];
        else
            msg = sprintf('FAIL - %d bare, %d painted below %.2f p.u.', ...
                sum(~B.Bare.OK), sum(~B.Painted.OK), B.Threshold);
            col = [0.6 0 0];
        end
        if ~isempty(warnMsg)
            msg = [msg '  |  ' warnMsg];
        end
        setStatus(msg, col);
    end

%% ========================================================================
    function onSectionEdit(src, evt)
        r = evt.Indices(1);
        c = evt.Indices(2);
        % Columns 2..5 are categorical, so NewData arrives as a
        % categorical value, not a char row vector.
        v = evt.NewData;
        S = parentTab.UserData.Sections;
        switch c
            case 2, S(r).Profile      = catToChar(v);
            case 3, S(r).CurrentBasis = catToChar(v);
            case 4, S(r).FreqBasis    = catToChar(v);
            case 5, S(r).Orientation  = catToChar(v);
            case 6
                if ~isnumeric(v) || ~isscalar(v) || v < 0
                    src.Data = sectionsToTable(S);      % revert
                    setStatus('Run length must be a non-negative number.', ...
                        [0.6 0 0]);
                    return
                end
                S(r).RunLength_m = v;
        end
        parentTab.UserData.Sections = S;
        setStatus('Sections edited - press Run Busbar Check.', [0.4 0.3 0]);
    end

%% ========================================================================
    function setSections(S)
        validateattributes(S, {'struct'}, {'nonempty'}, mfilename, 'Sections');
        required = {'Name','Profile','CurrentBasis','FreqBasis', ...
                    'Orientation','RunLength_m','k3_override'};
        missing = required(~isfield(S, required));
        if ~isempty(missing)
            error('build_busbar_tab:BadSections', ...
                'Section list is missing field(s): %s', strjoin(missing, ', '));
        end
        parentTab.UserData.Sections = S;
        H.SectionTable.Data = sectionsToTable(S);
        setStatus('Sections replaced - press Run Busbar Check.', [0.4 0.3 0]);
    end

%% ========================================================================
    function S = getSettings()
        S = struct( ...
            'Sections',    parentTab.UserData.Sections, ...
            'Threshold',   H.Threshold.Value, ...
            'Location',    H.Location.Value, ...
            'k1',          str2override(H.k1.Value), ...
            'k2',          str2override(H.k2.Value), ...
            'k5',          str2override(H.k5.Value), ...
            'BandGapRule', H.BandGap.Value);
    end

%% ========================================================================
    function setSettings(S)
        % Tolerant of older project files: every field is optional, and a
        % dropdown value that is not in Items is reported, not assigned.
        if ~isstruct(S), return; end
        if isfield(S, 'Sections')  && ~isempty(S.Sections)
            setSections(S.Sections);
        end
        if isfield(S, 'Threshold') && isscalar(S.Threshold) && S.Threshold > 0
            H.Threshold.Value = S.Threshold;
        end
        assignOverride(H.k1, S, 'k1');
        assignOverride(H.k2, S, 'k2');
        assignOverride(H.k5, S, 'k5');
        assignDropdown(H.Location, S, 'Location');
        assignDropdown(H.BandGap,  S, 'BandGapRule');
        setStatus('Settings restored - press Run Busbar Check.', [0.4 0.3 0]);
    end

%% ========================================================================
    function showCurrentFigure(Input)
        % Opens (or refreshes) the current distribution drawing. Reads IM
        % through the same buildInput call the check uses, so the figure
        % and the busbar currents can never diverge.
        %
        % Called automatically at the end of a successful check and from
        % the button. The previous window is closed first: the generator
        % always creates a new figure, so without this every press would
        % leave another one behind.
        if nargin < 1
            try
                Input = getInputFcn();
            catch err
                setStatus(['Cannot read inputs: ' err.message], [0.6 0 0]);
                return
            end
        end

        old = parentTab.UserData.CurrentFig;
        if isgraphics(old)
            delete(old);
        end

        try
            [~, newFig] = ...
                generate_cyclo_current_distribution_figure(Input);
            parentTab.UserData.CurrentFig = newFig;
        catch err
            parentTab.UserData.CurrentFig = gobjects(1);
            % A drawing failure must not mask a valid busbar result, so
            % this warns rather than overwriting the pass/fail status.
            warning('build_busbar_tab:CurrentFigureFailed', ...
                'Current distribution figure could not be drawn: %s', ...
                err.message);
        end
    end

%% ========================================================================
    function renderView()
        % Summary hides k1..k5. The detail views expose every factor that
        % went into I_max, which is the only way to see how k1, k2 and k5
        % were resolved for a given run.
        B = parentTab.UserData.LastResult;
        if isempty(B)
            H.ResultTable.Data = table();
            return
        end
        switch H.View.Value
            case 'Bare (detail)'
                H.ResultTable.Data = B.Bare;
                styleRows(H.ResultTable, B.Bare.OK, B.Bare.OK);
            case 'Painted (detail)'
                H.ResultTable.Data = B.Painted;
                styleRows(H.ResultTable, B.Painted.OK, B.Painted.OK);
            otherwise
                H.ResultTable.Data = B.Summary;
                styleRows(H.ResultTable, B.Bare.OK, B.Painted.OK);
        end
    end

%% ========================================================================
    function updateInfo(B)
        % k1..k5 are identical for every section except k3, so the info
        % line reports the four global ones and names the rule each came
        % from. k3 varies per section and is shown in the detail views.
        src = B.Sources.Bare{1};
        H.Info.Text = sprintf( ...
            ['IM = %.0f A  |  f_motor = %.2f Hz  |  altitude = %.0f m ' ...
             '(%s)  |  k1 = %.4g (%s)  k2 = %.4g (%s)  k5 = %.4g (%s)'], ...
            B.Currents.I_motor_A, B.Currents.f_motor_Hz, ...
            B.Altitude_m, B.Location, ...
            B.Bare.k1(1), src.k1_rule, ...
            B.Bare.k2(1), src.k2_rule, ...
            B.Bare.k5(1), src.k5_rule);
        if strcmp(src.k5_rule, 'extrapolated')
            H.Info.FontColor = [0.6 0.3 0];
        else
            H.Info.FontColor = [0 0 0];
        end
    end

%% ========================================================================
    function problem = checkEngineContract(B)
        %CHECKENGINECONTRACT  Verify busbar_check returned what the tab needs.
        problem = '';

        needTop = {'Summary','Bare','Painted','Currents','Sources', ...
                   'Threshold','Altitude_m','Location','AllOK'};
        missing = needTop(~isfield(B, needTop));
        if ~isempty(missing)
            problem = sprintf(['busbar_check.m is out of date: result is ' ...
                'missing %s. Replace busbar_check.m with the version that ' ...
                'matches this tab.'], strjoin(strcat('B.', missing), ', '));
            return
        end

        needRule = {'k1_rule','k2_rule','k5_rule'};
        if isempty(B.Sources.Bare)
            problem = 'busbar_check.m returned no factor provenance.';
            return
        end
        src = B.Sources.Bare{1};
        missing = needRule(~isfield(src, needRule));
        if ~isempty(missing)
            problem = sprintf(['busbar_k_factors.m is out of date: ' ...
                'provenance is missing %s. Replace busbar_k_factors.m ' ...
                'and busbar_check.m together.'], strjoin(missing, ', '));
        end
    end

%% ========================================================================
    function closeCurrentFigure()
        old = parentTab.UserData.CurrentFig;
        if isgraphics(old)
            delete(old);
        end
        parentTab.UserData.CurrentFig = gobjects(1);
    end

%% ========================================================================
    function setStatus(txt, col)
        H.Status.Text      = txt;
        H.Status.FontColor = col;
    end

end

%% ========================================================================
function assignOverride(h, S, f)
%ASSIGNOVERRIDE  Restore a k-factor override into its TEXT edit field.
%   NaN (or a missing field) restores as blank, meaning "compute".
if ~isfield(S, f), return; end
v = S.(f);
if isnumeric(v) && isscalar(v)
    if isnan(v)
        h.Value = '';
    else
        h.Value = num2str(v, '%.6g');
    end
elseif ischar(v) || (isstring(v) && isscalar(v))
    h.Value = char(v);
end
end

%% ========================================================================
function [v, err] = str2override(txt)
%STR2OVERRIDE  Parse a k-factor override text field.
%
%   Returns v = NaN and err = '' for a blank field, which busbar_check
%   reads as "compute this factor". A non-numeric or non-positive entry
%   returns NaN and a message describing the problem, so the caller can
%   refuse to run rather than silently ignoring what the user typed.
%
%   Correction factors are multiplicative deratings and must be positive
%   and finite; zero would zero the rating and a negative one is
%   meaningless.

err = '';
txt = strtrim(char(txt));

if isempty(txt)
    v = NaN;
    return
end

v = str2double(txt);

if isnan(v)
    err = sprintf('"%s" is not a number.', txt);
    return
end
if ~isfinite(v) || v <= 0
    err = sprintf('must be a positive finite number (got %g).', v);
    v   = NaN;
end
end

%% ========================================================================
function assignDropdown(h, S, f)
%ASSIGNDROPDOWN  Assign only if the stored value is a member of Items.
%   Guards the same failure mode as the BOD_Stator restore error: a
%   dropdown Value outside Items throws.
if ~isfield(S, f), return; end
v = S.(f);
if isstring(v) && isscalar(v), v = char(v); end
if ~ischar(v), return; end
if any(strcmp(cellstr(h.Items), v))
    h.Value = v;
else
    warning('build_busbar_tab:NotSelectable', ...
        'Stored value "%s" for %s is not selectable; keeping "%s".', ...
        v, f, h.Value);
end
end

%% ========================================================================
function T = sectionsToTable(S)
%SECTIONSTOTABLE  Struct array -> uitable data.
%
%   Columns 2..5 are CATEGORICAL with an explicit category set. That is
%   what makes uitable render them as dropdowns and refuse values outside
%   the set. ColumnFormat cannot do this: it is ignored whenever Data is a
%   table array, which is why an earlier version warned twice and left
%   those columns editable as free text.
%
%   The profile category set comes from BusbarAmpacityTable, so the two
%   can never drift apart.

DB = BusbarAmpacityTable();
profiles = {DB.Profile};

prof = categorical({S.Profile}', profiles);
if any(isundefined(prof))
    bad = unique({S(isundefined(prof)).Profile});
    error('build_busbar_tab:UnknownProfile', ...
        ['Section profile(s) %s are not in BusbarAmpacityTable. ' ...
         'Available: %s'], ...
        strjoin(strcat('"', bad, '"'), ', '), strjoin(profiles, ', '));
end

T = table( ...
    string({S.Name}'), ...
    prof, ...
    categorical({S.CurrentBasis}', {'Motor','Line','Stack'}), ...
    categorical({S.FreqBasis}',    {'Motor','Line'}), ...
    categorical({S.Orientation}',  {'horizontal','vertical'}), ...
    [S.RunLength_m]', ...
    'VariableNames', {'Section','Profile','CurrentBasis', ...
                      'FreqBasis','Orientation','RunLength_m'});
end

%% ========================================================================
function c = catToChar(v)
%CATTOCHAR  Normalise a uitable cell edit value to a char row vector.
%   Accepts categorical (table-array columns), string or char.
if iscategorical(v)
    c = char(string(v));
elseif isstring(v)
    c = char(v);
else
    c = char(v);
end
end

%% ========================================================================
function styleRows(uit, okBare, okPainted)
%STYLEROWS  Green / amber / red banding by pass/fail.
%   Green  = passes both finishes
%   Amber  = fails bare, passes painted -> painting is a requirement
%   Red    = fails painted too
removeStyle(uit);
failPainted  = find(~okPainted);
passBoth     = find(okBare & okPainted);
failBareOnly = find(~okBare & okPainted);

if ~isempty(passBoth)
    addStyle(uit, uistyle('BackgroundColor', [0.87 0.95 0.87]), 'row', passBoth);
end
if ~isempty(failBareOnly)
    addStyle(uit, uistyle('BackgroundColor', [1.00 0.95 0.80]), 'row', failBareOnly);
end
if ~isempty(failPainted)
    addStyle(uit, uistyle('BackgroundColor', [0.98 0.85 0.85]), 'row', failPainted);
end
end
