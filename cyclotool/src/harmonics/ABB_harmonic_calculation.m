function H = ABB_harmonic_calculation(Case)

R = Case.Result;

H = struct();

H.CaseName = Case.Name;

H.Speed = Case.Speed;

H.fM = Case.fM;

H.uL = Case.uL;

H.UL = Case.UL;

H.SC = Case.SC;

H.I1S = R.I1S;

H.dxN = R.dxN;

H.Uv0N = R.Uv0N;

H.STN = R.STN;

H.Order = [
     5
     7
    11
    13
    17
    19
    23
    25
    29
    31
    35
    37
    41
    43
    47
    49];

end