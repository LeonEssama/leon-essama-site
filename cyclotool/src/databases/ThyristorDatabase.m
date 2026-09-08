function DB = ThyristorDatabase()
%THYRISTORDATABASE  Main-converter thyristor ratings and thermal/switching
%model coefficients (HUEL and ABB devices).
%
%   DB = ThyristorDatabase() returns a struct array, one entry per
%   thyristor type, used throughout calculate.m and cyclo_dimensioning.m
%   for voltage class (UDRM), short-circuit ratings (IKS0/IKS1),
%   conduction loss (UT0, rT), switching-loss curve coefficients
%   (a,b,c,d), thermal derating coefficients (i,j,e,f,g,h,k,l), thermal
%   resistances (Rth_jc/ch/ha), recovery time (tq/tq1) and snubber
%   sizing (Csnub). Several ABB entries intentionally re-use a HUEL
%   entry's switching-loss/thermal-derating coefficients (DB(i)=DB(k))
%   because they share the same silicon; this is preserved unchanged.
%
%   The trailing validation block checks every entry has all required
%   fields and that numeric fields are finite scalars, and now reuses
%   the shared mustHaveFields() helper for the presence check (same
%   pass/fail outcome as the original, just less duplicated code).
%
%   All device data values are unchanged from the original.

i = 1;

%% =====================================================
% HUEL 412328
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412328';

DB(i).UDRM      = 2800;
DB(i).tq        = 400e-6;
DB(i).tq1       = 400e-6;

DB(i).IKS0      = 44000;
DB(i).IKS1      = 75000;

DB(i).Si_mm     = 100;

DB(i).rT        = 7.00e-5;
DB(i).UT0       = 0.86;

DB(i).VT1  = -4.00e-09;
DB(i).VT2  = 1.00e-04;
DB(i).VT3  = 7.84e-01;

DB(i).ON1  = -8.00e-10;
DB(i).ON2  = 4.00e-05;
DB(i).ON3  = 4.20e-03;

DB(i).OFF1 = 2.00e-07;
DB(i).OFF2 = 1.00e-03;
DB(i).OFF3 = 1.18e-01;

DB(i).Rth_jc    = 5.7; % K/kW
DB(i).Rth_ch    = 1.0; % K/kW
DB(i).Rth_ha    = 6.8; % K/kW

DB(i).Tjmax     = 125;

DB(i).a         = 336.00;
DB(i).b         = -72.00;
DB(i).c         = 287.44;
DB(i).d         = -23.44;

DB(i).e         = 0.004350;
DB(i).f         = 0.000023;
DB(i).g         = 0.006830;
DB(i).h         = 0.029230;

DB(i).i         = -5.833530;
DB(i).j         = 6.833530;

DB(i).k         = 0.10;
DB(i).l         = 0.77;

DB(i).Uv0_b     = 1400;
DB(i).PL_ThS_b  = 264;
DB(i).di_dt_b   = 14;
DB(i).f_b       = 60;
DB(i).Tj_b      = 110;

DB(i).Csnub     = 2.5e-6;

i=i+1;

%% =====================================================
% HUEL 412325
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412325';

DB(i).UDRM      = 4200;
DB(i).tq        = 350e-6;
DB(i).tq1        = 350e-6;

DB(i).IKS0      = 33000;
DB(i).IKS1      = 60000;

DB(i).Si_mm     = 100;

DB(i).rT        = 1.30e-4;
DB(i).UT0       = 0.95;
%-------- for simulation -----------
DB(i).VT1  = -7.00e-09;
DB(i).VT2  = 2.00e-04;
DB(i).VT3  = 8.50e-01;

DB(i).ON1  = -2.00e-09;
DB(i).ON2  = 4.00e-05;
DB(i).ON3  = -2.80e-03;

DB(i).OFF1 = 2.00e-07;
DB(i).OFF2 = 9.00e-04;
DB(i).OFF3 = 1.18e-01;
%------------------------------------
DB(i).Rth_jc    = 5.7;
DB(i).Rth_ch    = 1.0;
DB(i).Rth_ha    = 6.8;

DB(i).Tjmax     = 125;

DB(i).a         = 717.00;
DB(i).b         = 26.00;
DB(i).c         = 424.16;
DB(i).d         = 318.84;

DB(i).e         = 0.004350;
DB(i).f         = 0.000023;
DB(i).g         = 0.011190;
DB(i).h         = 0.023060;

DB(i).i         = -2.918450;
DB(i).j         = 3.918450;

DB(i).k         = 0.10;
DB(i).l         = 0.97;

DB(i).Uv0_b     = 2100;
DB(i).PL_ThS_b  = 743;
DB(i).di_dt_b   = 14;
DB(i).f_b       = 60;
DB(i).Tj_b      = 110;

DB(i).Csnub     = 2e-6;

i=i+1;

%% =====================================================
% HUEL 412315
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412315';

DB(i).UDRM      = 5200;
DB(i).tq        = 400e-6;
DB(i).tq1        = 400e-6;

DB(i).IKS0      = 32000;
DB(i).IKS1      = 55000;

DB(i).Si_mm     = 100;

DB(i).rT        = 1.70e-4;
DB(i).UT0       = 1.03;

DB(i).VT1  = -3.00e-09;
DB(i).VT2  = 2.00e-04;
DB(i).VT3  = 1.0195;

DB(i).ON1  = -4.00e-09;
DB(i).ON2  = 6.00e-05;
DB(i).ON3  = 1.40e-02;

DB(i).OFF1 = 3.00e-07;
DB(i).OFF2 = 1.30e-03;
DB(i).OFF3 = 9.17e-02;

DB(i).Rth_jc    = 5.7;
DB(i).Rth_ch    = 1.0;
DB(i).Rth_ha    = 6.8;

DB(i).Tjmax     = 110;

DB(i).a         = 429.79;
DB(i).b         = 302.21;
DB(i).c         = 28.19;
DB(i).d         = 703.82;

DB(i).e         = 0.003000;
DB(i).f         = 0.000049;
DB(i).g         = 0.003000;
DB(i).h         = 0.053000;

DB(i).i         = -1.276000;
DB(i).j         = 2.276000;

DB(i).k         = 0.10;
DB(i).l         = 0.85;

DB(i).Uv0_b     = 2600;
DB(i).PL_ThS_b  = 732;
DB(i).di_dt_b   = 10;
DB(i).f_b       = 60;
DB(i).Tj_b      = 90;

DB(i).Csnub     = 2e-6;

i=i+1;

%% =====================================================
% HUEL 412323
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412323';

DB(i).UDRM      = 6500;
DB(i).tq        = 450e-6;
DB(i).tq1        = 450e-6;

DB(i).IKS0      = 26000;
DB(i).IKS1      = 45000;

DB(i).Si_mm     = 100;

DB(i).rT        = 2.90e-4;
DB(i).UT0       = 1.02;

DB(i).VT1  = -2.00e-09;
DB(i).VT2  = 3.00e-04;
DB(i).VT3  = 1.095;

DB(i).ON1  = -6.00e-09;
DB(i).ON2  = 3.00e-04;
DB(i).ON3  = 5.60e-02;

DB(i).OFF1 = -7.00e-07;
DB(i).OFF2 = 6.10e-03;
DB(i).OFF3 = 8.33e-02;

DB(i).Rth_jc    = 5.7;
DB(i).Rth_ch    = 1.0;
DB(i).Rth_ha    = 6.8;

DB(i).Tjmax     = 110;

DB(i).a         = 621.00;
DB(i).b         = 498.00;
DB(i).c         = 6.05;
DB(i).d         = 1113.00;

DB(i).e         = 0.003000;
DB(i).f         = 0.000049;
DB(i).g         = 0.006000;
DB(i).h         = 0.048000;

DB(i).i         = -0.927000;
DB(i).j         = 1.927000;

DB(i).k         = 0.10;
DB(i).l         = 0.95;

DB(i).Uv0_b     = 3200;
DB(i).PL_ThS_b  = 1119;
DB(i).di_dt_b   = 12;
DB(i).f_b       = 60;
DB(i).Tj_b      = 95;

DB(i).Csnub     = 1.5e-6;

i=i+1;

%% =====================================================
% HUEL 412321
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412321';

DB(i).UDRM      = 2800;
DB(i).tq        = 400e-6;
DB(i).tq1       = DB(i).tq;

DB(i).IKS0      = 25000;
DB(i).IKS1      = 43000;

DB(i).Si_mm     = 70;

DB(i).rT        = 1.60e-4;
DB(i).UT0       = 0.85;

DB(i).VT1  = DB(1).VT1;
DB(i).VT2  = DB(1).VT2;
DB(i).VT3  = DB(1).VT3;

DB(i).ON1  = DB(1).ON1;
DB(i).ON2  = DB(1).ON2;
DB(i).ON3  = DB(1).ON3;

DB(i).OFF1 = DB(1).OFF1;
DB(i).OFF2 = DB(1).OFF2;
DB(i).OFF3 = DB(1).OFF3;

DB(i).Rth_jc    = 12;
DB(i).Rth_ch    = 5;
DB(i).Rth_ha    = 6.8;

DB(i).a = DB(1).a;
DB(i).b = DB(1).b;
DB(i).c = DB(1).c;
DB(i).d = DB(1).d;
DB(i).e = DB(1).e;
DB(i).f = DB(1).f;
DB(i).g = DB(1).g;
DB(i).h = DB(1).h;
DB(i).i = DB(1).i;
DB(i).j = DB(1).j;
DB(i).k = DB(1).k;
DB(i).l = DB(1).l;
DB(i).f_b = 60;
DB(i).PL_ThS_b = 264;

DB(i).Tjmax     = 125;

DB(i).di_dt_b   = 14;
DB(i).Uv0_b     = 1400;
DB(i).Tj_b      = 110;

DB(i).Csnub     = 1e-6;

i=i+1;

%% =====================================================
% HUEL 412312
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412312';

DB(i).UDRM      = 4400;
DB(i).tq        = 450e-6;
DB(i).tq1       = DB(i).tq;


DB(i).IKS0      = 30000;
DB(i).IKS1      = 52000;

DB(i).Si_mm     = 80;

DB(i).rT        = 1.60e-4;
DB(i).UT0       = 0.97;

DB(i).VT1  = DB(2).VT1;
DB(i).VT2  = DB(2).VT2;
DB(i).VT3  = DB(2).VT3;

DB(i).ON1  = DB(2).ON1;
DB(i).ON2  = DB(2).ON2;
DB(i).ON3  = DB(2).ON3;

DB(i).OFF1 = DB(2).OFF1;
DB(i).OFF2 = DB(2).OFF2;
DB(i).OFF3 = DB(2).OFF3;

DB(i).Rth_jc    = 9;
DB(i).Rth_ch    = 3;
DB(i).Rth_ha    = 6.8;

DB(i).Tjmax     = 120;

DB(i).a = DB(2).a;
DB(i).b = DB(2).b;
DB(i).c = DB(2).c;
DB(i).d = DB(2).d;

DB(i).e = DB(2).e;
DB(i).f = DB(2).f;
DB(i).g = DB(2).g;
DB(i).h = DB(2).h;

DB(i).i = DB(2).i;
DB(i).j = DB(2).j;

DB(i).k = DB(2).k;
DB(i).l = DB(2).l;

DB(i).f_b = 60;

DB(i).di_dt_b   = 11;
DB(i).Uv0_b     = 2200;
DB(i).PL_ThS_b  = 530;
DB(i).Tj_b      = 110;

DB(i).Csnub     = 1.5e-6;

i=i+1;

%% =====================================================
% HUEL 412327
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412327';

DB(i).UDRM      = 5200;
DB(i).tq        = 400e-6;
DB(i).tq1       = DB(i).tq;

DB(i).IKS0      = 24000;
DB(i).IKS1      = 42000;

DB(i).Si_mm     = 80;

DB(i).rT        = 2.30e-4;
DB(i).UT0       = 1.00;

DB(i).VT1  = DB(3).VT1;
DB(i).VT2  = DB(3).VT2;
DB(i).VT3  = DB(3).VT3;

DB(i).ON1  = DB(3).ON1;
DB(i).ON2  = DB(3).ON2;
DB(i).ON3  = DB(3).ON3;

DB(i).OFF1 = DB(3).OFF1;
DB(i).OFF2 = DB(3).OFF2;
DB(i).OFF3 = DB(3).OFF3;

DB(i).Rth_jc    = 9;
DB(i).Rth_ch    = 3;

DB(i).Tjmax     = 110;

DB(i).di_dt_b   = 10;
DB(i).Uv0_b     = 2600;
DB(i).PL_ThS_b  = 770;

DB(i).Rth_ha = 6.8;
DB(i).Tj_b   = 90;

DB(i).a = DB(3).a;
DB(i).b = DB(3).b;
DB(i).c = DB(3).c;
DB(i).d = DB(3).d;

DB(i).e = DB(3).e;
DB(i).f = DB(3).f;
DB(i).g = DB(3).g;
DB(i).h = DB(3).h;

DB(i).i = DB(3).i;
DB(i).j = DB(3).j;

DB(i).k = DB(3).k;
DB(i).l = DB(3).l;

DB(i).f_b = 60;

DB(i).Csnub     = 1.5e-6;

i=i+1;

%% =====================================================
% HUEL 412326
%% =====================================================

DB(i).Maker     = 'HUEL';
DB(i).Type      = '412326';

DB(i).UDRM      = 6500;
DB(i).tq        = 450e-6;

DB(i).IKS0      = 18000;
DB(i).IKS1      = 32000;

DB(i).Si_mm     = 80;

DB(i).rT        = 4.30e-4;
DB(i).UT0       = 1.20;

DB(i).VT1  = DB(4).VT1;
DB(i).VT2  = DB(4).VT2;
DB(i).VT3  = DB(4).VT3;

DB(i).ON1  = DB(4).ON1;
DB(i).ON2  = DB(4).ON2;
DB(i).ON3  = DB(4).ON3;

DB(i).OFF1 = DB(4).OFF1;
DB(i).OFF2 = DB(4).OFF2;
DB(i).OFF3 = DB(4).OFF3;

DB(i).Rth_jc    = 9;
DB(i).Rth_ch    = 3;

DB(i).Tjmax     = 110;

DB(i).di_dt_b   = 12;
DB(i).Uv0_b     = 3200;
DB(i).PL_ThS_b  = 964;

DB(i).tq1    = DB(i).tq;
DB(i).Rth_ha = 6.8;
DB(i).Tj_b   = 95;

DB(i).a = DB(4).a;
DB(i).b = DB(4).b;
DB(i).c = DB(4).c;
DB(i).d = DB(4).d;

DB(i).e = DB(4).e;
DB(i).f = DB(4).f;
DB(i).g = DB(4).g;
DB(i).h = DB(4).h;

DB(i).i = DB(4).i;
DB(i).j = DB(4).j;

DB(i).k = DB(4).k;
DB(i).l = DB(4).l;

DB(i).f_b = 60;

DB(i).Csnub     = 1e-6;

i=i+1;

%% =====================================================
% ABB 3BHB10084
%% =====================================================

DB(i)=DB(2);
DB(i).Maker='ABB';
DB(i).Type='10084';
DB(i).tq1 = DB(i).tq;
DB(i).Rth_ha = 6.8;

DB(i).VT1  = DB(2).VT1;
DB(i).VT2  = DB(2).VT2;
DB(i).VT3  = DB(2).VT3;

DB(i).ON1  = DB(2).ON1;
DB(i).ON2  = DB(2).ON2;
DB(i).ON3  = DB(2).ON3;

DB(i).OFF1 = DB(2).OFF1;
DB(i).OFF2 = DB(2).OFF2;
DB(i).OFF3 = DB(2).OFF3;
i=i+1;

%% =====================================================
% ABB 3BHB10085
%% =====================================================

DB(i)=DB(3);
DB(i).Maker='ABB';
DB(i).Type='10085';
DB(i).tq1 = DB(i).tq;
DB(i).Rth_ha = 6.8;

DB(i).VT1  = DB(3).VT1;
DB(i).VT2  = DB(3).VT2;
DB(i).VT3  = DB(3).VT3;

DB(i).ON1  = DB(3).ON1;
DB(i).ON2  = DB(3).ON2;
DB(i).ON3  = DB(3).ON3;

DB(i).OFF1 = DB(3).OFF1;
DB(i).OFF2 = DB(3).OFF2;
DB(i).OFF3 = DB(3).OFF3;
i=i+1;

%% =====================================================
% ABB 3BHB10088
%% =====================================================

DB(i)=DB(4);
DB(i).Maker='ABB';
DB(i).Type='10088';
DB(i).tq1 = DB(i).tq;
DB(i).Rth_ha = 6.8;

DB(i).VT1  = DB(4).VT1;
DB(i).VT2  = DB(4).VT2;
DB(i).VT3  = DB(4).VT3;

DB(i).ON1  = DB(4).ON1;
DB(i).ON2  = DB(4).ON2;
DB(i).ON3  = DB(4).ON3;

DB(i).OFF1 = DB(4).OFF1;
DB(i).OFF2 = DB(4).OFF2;
DB(i).OFF3 = DB(4).OFF3;

%% =====================================================
% DATABASE VALIDATION
%% =====================================================

requiredFields = { ...
    'Maker', ...
    'Type', ...
    'UDRM', ...
    'IKS0', ...
    'IKS1', ...
    'UT0', ...
    'rT', ...
    'VT1', ...
    'VT2', ...
    'VT3', ...
    'ON1', ...
    'ON2', ...
    'ON3', ...
    'OFF1', ...
    'OFF2', ...
    'OFF3', ...
    'Tjmax', ...
    'Rth_jc', ...
    'Rth_ch', ...
    'Rth_ha', ...
    'tq', ...
    'tq1', ...
    'a', ...
    'b', ...
    'c', ...
    'd', ...
    'e', ...
    'f', ...
    'g', ...
    'h', ...
    'i', ...
    'j', ...
    'k', ...
    'l', ...
    'Uv0_b', ...
    'PL_ThS_b', ...
    'di_dt_b', ...
    'f_b', ...
    'Tj_b', ...
    'Csnub'};
for deviceIndex = 1:numel(DB)
    mustHaveFields(DB(deviceIndex), requiredFields, ...
        sprintf('ThyristorDatabase (device %s)', DB(deviceIndex).Type));
    for fieldIndex = 1:numel(requiredFields)
        fieldName = requiredFields{fieldIndex};
        fieldValue = DB(deviceIndex).(fieldName);
        if isnumeric(fieldValue) && ...
                (~isscalar(fieldValue) || ~isfinite(fieldValue))
            error( ...
                'Cyclo:InvalidThyristorField', ...
                ['Device %s has an invalid value ', ...
                 'for field %s.'], ...
                DB(deviceIndex).Type, ...
                fieldName);
        end
    end
end
end