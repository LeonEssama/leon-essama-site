function Envelope = cyclo_operating_envelope(Input)
%CYCLO_OPERATING_ENVELOPE
% Create speed-dependent operating envelope.

%% Speed vector

Envelope.SpeedRpm = ...
    unique([ ...
    Input.n_min ...
    linspace(Input.n_min, Input.n_nom, 10) ...
    linspace(Input.n_nom, Input.n_max, 10)]);

nPoints = ...
    numel(Envelope.SpeedRpm);

%% Preallocate

Envelope.FrequencyHz = ...
    zeros(nPoints,1);

Envelope.PowerMW = ...
    zeros(nPoints,1);

Envelope.PowerW = ...
    zeros(nPoints,1);

Envelope.TorqueMNm = ...
    zeros(nPoints,1);

Envelope.TorqueNm = ...
    zeros(nPoints,1);

Envelope.TorquePU = ...
    zeros(nPoints,1);

Envelope.Region = ...
    strings(nPoints,1);

Envelope.Status = ...
    strings(nPoints,1);

Envelope.ExcitationCurrentA = ...
    zeros(nPoints,1);

Envelope.VoltageV = ...
    zeros(nPoints,1);

Envelope.CurrentA = ...
    zeros(nPoints,1);

%% Reference values

Pn = ...
    Input.Psh_nominal;     % W

nNom = ...
    Input.n_nom;

omegaNom = ...
    2*pi*nNom/60;

Tnom = ...
    Pn/omegaNom;

if isfield(Input,'If_nom')

    IfNom = ...
        Input.If_nom;

else

    warning( ...
        'CycloTool:MissingIfNom', ...
        ['Input.If_nom not provided. ', ...
         'Using 0 A excitation current.']);

    IfNom = 0;

end

UMnom = ...
    Input.UM;

IMnom = ...
    Input.IM;

%% Sweep

for k = 1:nPoints

    n = Envelope.SpeedRpm(k);

    Envelope.FrequencyHz(k) = ...
        Input.PolePairs * n / 60;

    omega = ...
        2*pi*n/60;

    if n <= nNom

        Envelope.Region(k) = ...
            "Constant Torque";

        Torque = ...
            Tnom;

        Envelope.ExcitationCurrentA(k) = ...
            IfNom;

        Power = ...
            Torque * omega;

        Envelope.VoltageV(k) = ...
            UMnom * n / nNom;

    else

        Envelope.Region(k) = ...
            "Field Weakening";

        Power = ...
            Pn;

        Torque = ...
            Power / omega;

        Envelope.ExcitationCurrentA(k) = ...
            IfNom * nNom / n;

        Envelope.VoltageV(k) = ...
            UMnom;

    end

    Envelope.PowerMW(k) = ...
        Power / 1e6;

    Envelope.PowerW(k) = ...
        Power;

    Envelope.TorqueMNm(k) = ...
    Torque / 1e6;

    Envelope.TorqueNm(k) = ...
        Torque;

    Envelope.TorquePU(k) = ...
        Torque/Tnom;

    Envelope.CurrentA(k) = ...
        IMnom;

    Envelope.Status(k) = ...
    "PASS";

end

%% Engineering checks

assert( ...
    all(diff(Envelope.SpeedRpm) > 0), ...
    'Speed vector must be strictly increasing.');

assert( ...
    min(Envelope.TorquePU) > 0, ...
    'Invalid torque values.');

assert( ...
    abs(max(Envelope.TorquePU)-1) < 1e-6, ...
    'Unexpected torque normalization.');

%% Metadata

Envelope.Metadata = struct();

caseSignature = ...
    cyclo_case_signature(Input);

Envelope.Metadata.CaseID = ...
    caseSignature.ID;

Envelope.Metadata.InputHash = ...
    caseSignature.FullHash;

Envelope.Metadata.Module = ...
    "Operating Envelope";

Envelope.Metadata.ToolVersion = ...
    "1.2 Development";

Envelope.Metadata.CreatedAt = ...
    datetime('now');

Envelope.Metadata.PolePairs = ...
    Input.PolePairs;

end