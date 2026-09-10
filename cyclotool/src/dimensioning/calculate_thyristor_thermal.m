function [Uv, didtv, Tj, PVS, PLTh, PLR, Taus_KD, Tein, Tav_KD, red, TjHist] = ...
    calculate_thyristor_thermal(uL_used, I1S_used, dxN, Uv0N, N_SerieN, ...
    fL, IM, IM_used, Mode, PulseNumber, Cooling, CB, Taus_max, Qw, Tamb, Thy)
%CALCULATE_THYRISTOR_THERMAL  Thyristor voltage/di-dt and iterative
%junction-temperature/switching-loss (PVS) solve for one operating point.
%
%   [Uv, didtv, Tj, PVS, PLTh, PLR, Taus_KD, Tein, Tav_KD, red, TjHist] = ...
%       calculate_thyristor_thermal(uL_used, I1S_used, dxN, Uv0N, ...
%       N_SerieN, fL, IM, IM_used, Mode, PulseNumber, Cooling, CB, ...
%       Taus_max, Qw, Tamb, Thy)
%
%   Extracted from calculate.m without changing any formula, so it can
%   be called a second time per Netz operating-point row (runLosses)
%   with that row's uL_used/IM instead of the nominal dimensioning
%   values, while I1S_used/dxN/Uv0N/N_SerieN (fixed characteristics of
%   the built converter, not of the instantaneous operating point) stay
%   at their dimensioning-time values. PVS ("Einzelverluste" switching
%   loss) depends on Uv and didtv, both of which scale with uL_used --
%   using a single nominal-point PVS for every operating point (as
%   before this function existed) understates switching loss at
%   uL>1 points and overstates it at uL<1 points.
%
%   aN_therm = pi/2 (fixed converter-thermal reference firing angle,
%   matching calculate.m) is not a parameter -- it is not a design or
%   operating-point variable.

aN_therm = pi/2;

Uv    = uL_used * sqrt(2) * Uv0N / N_SerieN * sin(aN_therm);
didtv = pi*fL*sqrt(3/2) * I1S_used/dxN * uL_used * sin(aN_therm) / 1e6;

Rthjc = Thy.Rth_jc / 1000;
Rthch = Thy.Rth_ch / 1000;
Rthha = Thy.Rth_ha / 1000;
Rthtot = Rthjc + Rthch + Rthha;

Tj = 1;
TjHist = [];
for iter = 1:200
    if Thy.i + Thy.j*Tj/Thy.Tj_b > 1
        f_Tj = Thy.i + Thy.j*Tj/Thy.Tj_b;
    else
        f_Tj = 1;
    end

    PVS = 1.05/Thy.PL_ThS_b ...
        * (Thy.a*(Uv/Thy.Uv0_b) + Thy.b*(Uv/Thy.Uv0_b)^2) ...
        * (Thy.c*(didtv/Thy.di_dt_b) + Thy.d*sqrt(didtv/Thy.di_dt_b)) ...
        * fL/Thy.f_b * f_Tj;

    if strcmpi(Mode, 'rms')
        PLTh = ((2*sqrt(2)/pi)*Thy.UT0*IM + Thy.rT*IM^2)/6 + PVS;
    else
        PLTh = (sqrt(2)*IM_used/3)*Thy.UT0 + 3*Thy.rT*(sqrt(2)*IM_used/3)^2 + PVS;
    end

    PLR = NaN;
    Taus_KD = NaN;
    Tein = NaN;
    Tav_KD = NaN;
    red = 0;

    if strcmpi(Cooling, 'Water')
        if PulseNumber == 6*N_SerieN
            red = 1;
        else
            red = 0.85;
        end
        PLR     = 1.75*fL*CB*(Uv/red)^2;
        Taus_KD = Taus_max - PLR/1000*60/Qw/4.187;
        Tein    = Taus_KD - 0.5*PLTh/1000*60/Qw/4.187;
        Tav_KD  = Tein;
        TjNew   = PLTh*Rthtot + Tav_KD;
    else
        TjNew = Tamb + PLTh*Rthtot;
    end

    TjHist(end+1) = TjNew; %#ok<AGROW>
    if abs(1 - TjNew/Tj) < 1e-5
        break
    end
    Tj = TjNew;
end

Tj = TjNew;

end
