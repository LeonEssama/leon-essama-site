function Fig = generate_cooling_sweep_figure(Sweep, outputFolder)
%GENERATE_COOLING_SWEEP_FIGURE  Cooling flow sweep diagnostic (4-panel).
%
%   Fig = generate_cooling_sweep_figure(Sweep, outputFolder)
%
%   Plots pressure drop, cooling-branch DeltaT, inlet temperature and
%   converter flow vs. coolant flow rate.
%
%   Note vs. the original: this function previously created an
%   interactive, visible figure and never saved or closed it -
%   inconsistent with every other generate_cyclo_*_figure function in
%   this project, which all render headlessly and export a PNG. An
%   optional outputFolder argument has been added: if given, the figure
%   is exported to PNG (like its siblings) and closed; if omitted, it
%   behaves exactly as before (visible, left open, returned as Fig) for
%   backward compatibility with any existing interactive callers.
%
%   Calculation/plotting logic and data values are unchanged.

arguments
    Sweep (1,1) struct
    outputFolder (1,1) string = ""
end

requiredFields = {'QwKD_lpm', 'DpConverter_kPa', 'DeltaTKD_C', ...
    'TinKD_C', 'QConverter_lpm'};
missing = requiredFields(~isfield(Sweep, requiredFields));
if ~isempty(missing)
    error('generate_cooling_sweep_figure:MissingFields', ...
        'Sweep is missing field(s): %s', strjoin(missing, ', '));
end

exportRequested = strlength(outputFolder) > 0;

Fig = figure( ...
    'Name', 'Cooling Flow Sweep', ...
    'Color', 'w', ...
    'Visible', ~exportRequested);

%% Pressure drop
subplot(2,2,1)
plot(Sweep.QwKD_lpm, Sweep.DpConverter_kPa, 'o-', 'LineWidth', 2);
grid on
xlabel('Q_{KD} [l/min]')
ylabel('\DeltaP_{Converter} [kPa]')
title('Flow vs Pressure Drop')

%% Delta T
subplot(2,2,2)
plot(Sweep.QwKD_lpm, Sweep.DeltaTKD_C, 'o-', 'LineWidth', 2);
grid on
xlabel('Q_{KD} [l/min]')
ylabel('\DeltaT_{KD} [°C]')
title('Flow vs Cooling Branch \DeltaT')

%% Inlet temperature
subplot(2,2,3)
plot(Sweep.QwKD_lpm, Sweep.TinKD_C, 'o-', 'LineWidth', 2);
grid on
xlabel('Q_{KD} [l/min]')
ylabel('T_{in} [°C]')
title('Flow vs Inlet Temperature')

%% Converter flow
subplot(2,2,4)
plot(Sweep.QwKD_lpm, Sweep.QConverter_lpm, 'o-', 'LineWidth', 2);
grid on
xlabel('Q_{KD} [l/min]')
ylabel('Q_{Converter} [l/min]')
title('Flow vs Converter Flow')

sgtitle('CycloTool Cooling Flow Sweep')

%% Export (only when outputFolder is given, preserving old behavior otherwise)
if exportRequested
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    figureFile = fullfile(outputFolder, "cooling_flow_sweep.png");
    exportgraphics(Fig, figureFile, 'Resolution', 300, 'BackgroundColor', 'white');
    close(Fig);
    if ~isfile(figureFile)
        error('generate_cooling_sweep_figure:ExportFailure', ...
            'The cooling flow sweep figure was not exported.');
    end
end

end
