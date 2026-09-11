function Sweep = run_cyclo_operating_point_sweep( ...
    Input, R, Thy, numberOfPeriods, progressFcn)
%RUN_CYCLO_OPERATING_POINT_SWEEP  Detailed cyclo simulation across the
%tool's standard named speed/voltage operating points.
%
%   Sweep = run_cyclo_operating_point_sweep(Input, R, Thy, numberOfPeriods)
%   Sweep = run_cyclo_operating_point_sweep(Input, R, Thy, numberOfPeriods, progressFcn)
%
%   progressFcn (optional, default []): a function handle called twice
%   per point -- once as the point starts and once as it finishes -- so
%   a caller (e.g. the GUI) can show which point is currently running
%   during this otherwise-silent, potentially slow (multi-minute) loop.
%   Called as progressFcn(info), info a scalar struct with fields:
%     Phase           'start' | 'done'
%     Row             1-based point index in this sweep
%     NumberOfPoints  total number of points (nSpeeds * nVoltages)
%     SpeedName       e.g. 'MinSpeed'
%     VoltageName     e.g. 'uLmin'
%     Sweep           the Sweep struct as built so far (rows 1..Row-1
%                     fully populated; row Row has Point/VoltageCase/
%                     Speed/f2/UM_op/IM_op/FieldWeakening/Input set on
%                     'start', plus Result/Status/ErrorMessage on 'done')
%   Ignored (never called) when left [].
%
%   Runs run_detailed_cyclo_simulation once per (SpeedName, VoltageCase)
%   combination -- losses, harmonics, and firing-angle/voltage/current
%   waveforms for each -- reusing the EXACT per-point UM/IM field-
%   weakening formulas already established in CycloGUI_v2_0/
%   generateNetzMatrix (used there for the Netzbelastung operating
%   matrix): below base speed, constant V/Hz; at or above base speed,
%   field weakening -- voltage held at UM_nom*u_L (uLmin case) or
%   UM_nom (uL=1/uLmax cases) while current is scaled by 1/u_L on the
%   uLmin case to hold shaft power roughly constant. This is not a new
%   formula: it is the same one already used for Netzbelastung/Losses/
%   Characteristic operating points elsewhere in this tool, reproduced
%   here so the detailed simulation's operating points are consistent
%   with the rest of the tool rather than independently invented.
%
%   Points swept (5 speeds x 3 voltage cases = 15 runs):
%     Speeds:  Creeping, Inching, MinSpeed, BaseSpeed (nominal), MaxSpeed
%              (Input.CreepingSpeed, Input.InchingSpeed, Input.n_min,
%              Input.n_nom, Input.n_max)
%     Voltage: uLmin (Input.u_L), uL=1, uLmax (2-Input.u_L)
%
%   numberOfPeriods (optional, default 2): motor electrical periods each
%   run's waveforms span, so the resulting plots show a repeated cycle
%   for visual/periodicity inspection. Loss and harmonic RESULTS are
%   unaffected by this choice: prepare_cyclo_fft_record.m and prepare_
%   cyclo_source_fft_record.m already extract exactly one motor period
%   for their FFT-based calculations regardless of how many periods the
%   raw waveform spans, and calculate_cyclo_converter_losses.m's
%   energy-to-average-power conversion is duration-normalized. See
%   prepare_cyclo_simulation_inputs.m's P.numberOfPeriods for detail.
%
%   A point's own detailed-simulation run is wrapped so one point's
%   failure (e.g. an edge-case speed producing too few FFT samples)
%   does not lose the rest of the sweep: Sweep.Status{k} is 'ERROR' and
%   Sweep.ErrorMessage{k} holds the message for that row; every other
%   row still completes. This is a deliberate exception to this
%   codebase's usual fail-loud convention, made specifically for a
%   multi-point batch where an isolated failure should not discard
%   otherwise-valid results.
%
%   Required Input fields (beyond run_detailed_cyclo_simulation's own):
%     CreepingSpeed, InchingSpeed, n_min, n_nom, n_max, u_L, UM, IM,
%     PolePairs.

arguments
    Input (1,1) struct
    R     (1,1) struct
    Thy   (1,1) struct
    numberOfPeriods (1,1) double {mustBePositive, mustBeInteger} = 2
    progressFcn = []
end

hasProgressFcn = ~isempty(progressFcn);

requiredFields = { ...
    'CreepingSpeed', 'InchingSpeed', 'n_min', 'n_nom', 'n_max', ...
    'u_L', 'UM', 'IM', 'PolePairs'};

for fieldIndex = 1:numel(requiredFields)
    fieldName = requiredFields{fieldIndex};
    if ~isfield(Input, fieldName)
        error('Cyclo:MissingSweepInputField', ...
            'Input is missing required field %s.', fieldName);
    end
end

SpeedNames = { ...
    'Creeping', 'Inching', 'MinSpeed', 'BaseSpeed', 'MaxSpeed'};

SpeedValues = [ ...
    Input.CreepingSpeed
    Input.InchingSpeed
    Input.n_min
    Input.n_nom
    Input.n_max];

VoltageNames = {'uLmin', 'uL=1', 'uLmax'};

nSpeeds = numel(SpeedNames);
nVoltages = numel(VoltageNames);
nPoints = nSpeeds * nVoltages;

Sweep = struct();
Sweep.Point          = cell(nPoints, 1);
Sweep.VoltageCase    = cell(nPoints, 1);
Sweep.Speed          = zeros(nPoints, 1);
Sweep.f2             = zeros(nPoints, 1);
Sweep.UM_op          = zeros(nPoints, 1);
Sweep.IM_op          = zeros(nPoints, 1);
Sweep.FieldWeakening = false(nPoints, 1);
Sweep.Input          = cell(nPoints, 1);
Sweep.Result         = cell(nPoints, 1);
Sweep.Status         = cell(nPoints, 1);
Sweep.ErrorMessage   = cell(nPoints, 1);

row = 0;

for i = 1:nSpeeds

    Speed = SpeedValues(i);

    if ~isfinite(Speed) || Speed <= 0
        error('Cyclo:InvalidSweepSpeed', ...
            '%s speed must be finite and positive (got %g rpm).', ...
            SpeedNames{i}, Speed);
    end

    for j = 1:nVoltages

        row = row + 1;

        [UM_op, IM_op, ~, fieldWeakening] = ...
            derive_cyclo_operating_point_voltage_current(Input, Speed, j);

        PointInput = Input;
        PointInput.n_nom = Speed;
        PointInput.UM = UM_op;
        PointInput.IM = IM_op;
        PointInput.NumberOfPeriods = numberOfPeriods;

        Sweep.Point{row}          = SpeedNames{i};
        Sweep.VoltageCase{row}    = VoltageNames{j};
        Sweep.Speed(row)          = Speed;
        Sweep.f2(row)             = Speed * Input.PolePairs / 60;
        Sweep.UM_op(row)          = UM_op;
        Sweep.IM_op(row)          = IM_op;
        Sweep.FieldWeakening(row) = fieldWeakening;
        Sweep.Input{row}          = PointInput;

        if hasProgressFcn
            progressFcn(struct( ...
                'Phase', 'start', ...
                'Row', row, ...
                'NumberOfPoints', nPoints, ...
                'SpeedName', SpeedNames{i}, ...
                'VoltageName', VoltageNames{j}, ...
                'Sweep', Sweep));
        end

        try
            PointResult = run_detailed_cyclo_simulation(PointInput, R, Thy);
            Sweep.Result{row} = PointResult;
            Sweep.Status{row} = PointResult.Status;
            Sweep.ErrorMessage{row} = '';
        catch ME
            Sweep.Result{row} = [];
            Sweep.Status{row} = 'ERROR';
            Sweep.ErrorMessage{row} = ME.message;
        end

        if hasProgressFcn
            progressFcn(struct( ...
                'Phase', 'done', ...
                'Row', row, ...
                'NumberOfPoints', nPoints, ...
                'SpeedName', SpeedNames{i}, ...
                'VoltageName', VoltageNames{j}, ...
                'Sweep', Sweep));
        end

    end

end

Sweep.SpeedNames   = SpeedNames;
Sweep.VoltageNames = VoltageNames;
Sweep.numberOfPeriods = numberOfPeriods;
Sweep.numberOfPoints  = nPoints;
Sweep.numberOfErrors  = nnz(strcmp(Sweep.Status, 'ERROR'));

end
