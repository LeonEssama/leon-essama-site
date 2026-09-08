function DB = ...
    cyclo_cooling_component_database()

% Aktogay cooling workbook component database

DB = struct();

%% Cooling can

DB.CoolingCan.Name = ...
    "Cooling Can";

DB.CoolingCan.a = ...
    1.891;

DB.CoolingCan.c = ...
    15.0;

%% Resistor

DB.Resistor.Name = ...
    "Resistor";

DB.Resistor.a = ...
    1.867;

DB.Resistor.c = ...
    0.7;

%% Hose 4 mm 1 m

DB.Hose4mm1m.Name = ...
    "Hose 4 mm 1 m";

DB.Hose4mm1m.a = ...
    1.802;

DB.Hose4mm1m.c = ...
    8.493;

%% Hose 4 mm 0.4 m

DB.Hose4mm04m.Name = ...
    "Hose 4 mm 0.4 m";

DB.Hose4mm04m.a = ...
    1.802;

DB.Hose4mm04m.c = ...
    2.12325;

%% Pipe 56.3 mm 1 m

DB.Pipe56mm1m.Name = ...
    "Pipe 56.3 mm 1 m";

DB.Pipe56mm1m.a = ...
    1.55;

DB.Pipe56mm1m.c = ...
    0.0004;

%% Pipe 56.3 mm 2.1 m

DB.Pipe56mm21m.Name = ...
    "Pipe 56.3 mm 2.1 m";

DB.Pipe56mm21m.a = ...
    1.55;

DB.Pipe56mm21m.c = ...
    0.00048;

%% Collector pipe 10 m

DB.Collector10m.Name = ...
    "Collector Pipe 10 m";

DB.Collector10m.a = ...
    1.55;

DB.Collector10m.c = ...
    0.004;

%% Two resistors + hose

DB.TwoResistors.Name = ...
    "2 Resistors + 1.5 m Hose";

DB.TwoResistors.a = ...
    1.808;

DB.TwoResistors.c = ...
    14.15;

end