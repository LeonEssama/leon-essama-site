function Record = prepare_cyclo_fft_record(P, Voltage)
%PREPARE_CYCLO_FFT_RECORD
% Resample the synthesized cycloconverter voltages onto a
% uniform time grid spanning exactly one motor period.
%
% The Stage 2 ABB-compatible synthesis stores converter
% segments separated by time gaps. MATLAB fft() requires
% uniformly spaced samples. This function creates the
% required uniform periodic record.

arguments
    P       (1,1) struct
    Voltage (1,1) struct
end

%% =========================================================
% Validate original record
%% =========================================================

tOriginal = Voltage.t(:);

if numel(tOriginal) < 2

    error( ...
        'Cyclo:InsufficientVoltageSamples', ...
        'The voltage record contains too few samples.');

end

if any(diff(tOriginal) <= 0)

    error( ...
        'Cyclo:InvalidVoltageTimeVector', ...
        'The original voltage time vector must be increasing.');

end

%% =========================================================
% Exact one-period FFT grid
%% =========================================================

motorPeriod = 1/P.f2;

numberOfSamples = round( ...
    motorPeriod/P.dt);

if numberOfSamples < 16

    error( ...
        'Cyclo:InsufficientFFTRecord', ...
        'The FFT record contains too few samples.');

end

sampleTime = ...
    motorPeriod/numberOfSamples;

time = ...
    (0:numberOfSamples-1)' ...
    * sampleTime;

%% =========================================================
% Add periodic endpoint
%% =========================================================
%
% The original record is almost one complete motor period.
% Append the first sample at t = motorPeriod so that
% interpolation near the period boundary is well defined.

tPeriodic = [
    tOriginal
    motorPeriod
    ];

uuPeriodic = [
    Voltage.uu(:)
    Voltage.uu(1)
    ];

uvPeriodic = [
    Voltage.uv(:)
    Voltage.uv(1)
    ];

uwPeriodic = [
    Voltage.uw(:)
    Voltage.uw(1)
    ];

%% Remove any sample beyond one motor period

validIndex = ...
    tPeriodic >= 0 ...
    & tPeriodic <= motorPeriod;

tPeriodic = ...
    tPeriodic(validIndex);

uuPeriodic = ...
    uuPeriodic(validIndex);

uvPeriodic = ...
    uvPeriodic(validIndex);

uwPeriodic = ...
    uwPeriodic(validIndex);

%% Ensure unique interpolation points

[tPeriodic, uniqueIndex] = ...
    unique( ...
        tPeriodic, ...
        'stable');

uuPeriodic = ...
    uuPeriodic(uniqueIndex);

uvPeriodic = ...
    uvPeriodic(uniqueIndex);

uwPeriodic = ...
    uwPeriodic(uniqueIndex);

%% =========================================================
% Zero-order-hold interpolation
%% =========================================================
%
% 'previous' preserves the switching waveform better than
% linear interpolation. Linear interpolation would create
% artificial voltage ramps at thyristor switching events.

Record.uu = ...
    interp1( ...
        tPeriodic, ...
        uuPeriodic, ...
        time, ...
        'previous', ...
        'extrap');

Record.uv = ...
    interp1( ...
        tPeriodic, ...
        uvPeriodic, ...
        time, ...
        'previous', ...
        'extrap');

Record.uw = ...
    interp1( ...
        tPeriodic, ...
        uwPeriodic, ...
        time, ...
        'previous', ...
        'extrap');

%% =========================================================
% Derived motor voltages
%% =========================================================

Record.starPoint = ...
    (Record.uu ...
    + Record.uv ...
    + Record.uw) ...
    / 3;

Record.motorPhaseU = ...
    Record.uu ...
    - Record.starPoint;

Record.motorPhaseV = ...
    Record.uv ...
    - Record.starPoint;

Record.motorPhaseW = ...
    Record.uw ...
    - Record.starPoint;

Record.lineUV = ...
    Record.uu ...
    - Record.uv;

Record.lineVW = ...
    Record.uv ...
    - Record.uw;

Record.lineWU = ...
    Record.uw ...
    - Record.uu;

%% =========================================================
% Exact FFT frequency axis
%% =========================================================

Record.t = time;

Record.numberOfSamples = ...
    numberOfSamples;

Record.sampleTime = ...
    sampleTime;

Record.sampleFrequency = ...
    1/sampleTime;

Record.recordDuration = ...
    motorPeriod;

Record.frequencyResolution = ...
    1/motorPeriod;

%% =========================================================
% Validation
%% =========================================================

if any(~isfinite(Record.uu)) || ...
        any(~isfinite(Record.uv)) || ...
        any(~isfinite(Record.uw))

    error( ...
        'Cyclo:InvalidResampledVoltage', ...
        'The resampled voltage contains invalid values.');

end

if abs( ...
        Record.frequencyResolution ...
        - P.f2) ...
        > 1e-10*max(1, P.f2)

    error( ...
        'Cyclo:IncorrectFFTResolution', ...
        ['A one-motor-period record must have a frequency ', ...
         'resolution equal to the motor frequency.']);

end

end