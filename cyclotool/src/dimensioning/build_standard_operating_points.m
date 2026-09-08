function Points = ...
    build_standard_operating_points(Input)

Points = struct([]);

%% SCmin

Points(1).Name = "SCmin";
Points(1).SpeedRpm = Input.n_nom;

%% SCmax

Points(2).Name = "SCmax";
Points(2).SpeedRpm = Input.n_nom;

%% Nominal

Points(3).Name = "Nominal";
Points(3).SpeedRpm = Input.n_nom;

%% Maximum Speed

Points(4).Name = "Maximum Speed";
Points(4).SpeedRpm = Input.n_max;

end