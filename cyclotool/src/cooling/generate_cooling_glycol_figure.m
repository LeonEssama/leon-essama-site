function Fig = generate_cooling_glycol_figure(Sweep, outputFolder)
%GENERATE_COOLING_GLYCOL_FIGURE  Cooling glycol-concentration sweep (4-panel).
%
%   Fig = generate_cooling_glycol_figure(Sweep, outputFolder)
%
%   Plots pressure drop, cooling-branch DeltaT, inlet temperature and
%   coolant specific heat vs. glycol concentration.
%
%   Note vs. the original: see generate_cooling_sweep_figure.m for the
%   same backward-compatible headless-export option added here.
%
%   Calculation/plotting logic and data values are unchanged.

arguments
    Sweep (1,1) struct
    outputFolder (1,1) string = ""
end

requiredFields = {'GlycolPercent', 'DpConverter_kPa', 'DeltaTKD_C', ...
    'TinKD_C', 'Cp_kJkgK'};
missing = requiredFields(~isfield(Sweep, requiredFields));
if ~isempty(missing)
    error('generate_cooling_glycol_figure:MissingFields', ...
        'Sweep is missing field(s): %s', strjoin(missing, ', '));
end

exportRequested = strlength(outputFolder) > 0;

Fig = figure( ...
    'Name', 'Cooling Glycol Sweep', ...
    'Color', 'w', ...
    'Visible', ~exportRequested);

%% Pressure drop
subplot(2,2,1)
plot(Sweep.GlycolPercent, Sweep.DpConverter_kPa, 'o-', 'LineWidth', 2);
grid on
xlabel('Glycol [%]')
ylabel('\DeltaP_{Converter} [kPa]')
title('Glycol vs Pressure Drop')

%% Delta T
subplot(2,2,2)
plot(Sweep.GlycolPercent, Sweep.DeltaTKD_C, 'o-', 'LineWidth', 2);
grid on
xlabel('Glycol [%]')
ylabel('\DeltaT_{KD} [°C]')
title('Glycol vs \DeltaT')

%% Inlet temperature
subplot(2,2,3)
plot(Sweep.GlycolPercent, Sweep.TinKD_C, 'o-', 'LineWidth', 2);
grid on
xlabel('Glycol [%]')
ylabel('T_{in} [°C]')
title('Glycol vs Inlet Temperature')

%% Cp
subplot(2,2,4)
plot(Sweep.GlycolPercent, Sweep.Cp_kJkgK, 'o-', 'LineWidth', 2);
grid on
xlabel('Glycol [%]')
ylabel('Cp [kJ/kgK]')
title('Glycol vs Specific Heat')

sgtitle('CycloTool Cooling Glycol Sweep')

%% Export (only when outputFolder is given, preserving old behavior otherwise)
if exportRequested
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    figureFile = fullfile(outputFolder, "cooling_glycol_sweep.png");
    exportgraphics(Fig, figureFile, 'Resolution', 300, 'BackgroundColor', 'white');
    close(Fig);
    if ~isfile(figureFile)
        error('generate_cooling_glycol_figure:ExportFailure', ...
            'The cooling glycol sweep figure was not exported.');
    end
end

end
