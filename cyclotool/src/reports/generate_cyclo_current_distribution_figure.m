function [figPath, fig] = generate_cyclo_current_distribution_figure(Input, outputFolder)
%GENERATE_CYCLO_CURRENT_DISTRIBUTION_FIGURE  Converter current distribution.
%
%   [figPath, fig] = generate_cyclo_current_distribution_figure(Input)
%   [figPath, fig] = generate_cyclo_current_distribution_figure(Input, outputFolder)
%
%   figPath  full path of the exported PNG, or '' when outputFolder is
%            empty. Always a char vector, never a handle.
%   fig      the figure handle. Invalid after export, because the figure
%            is closed.
%
%   Draws the current distribution through one 12-pulse converter phase
%   group. THE TOPOLOGY IS FIXED: the arrangement of thyristors, nodes and
%   wires never changes. Only the five current labels are computed, from
%   Input.IM. Pass outputFolder to export a PNG and close the figure,
%   matching the other generate_cyclo_*_figure functions; omit it (or pass
%   "") to leave the figure open.
%
%   Intended to sit beside the busbar layout drawing (Schienenplan) in the
%   design report: the same three currents drive busbar_check, so the two
%   pages are guaranteed consistent.
%
%   CURRENT LADDER (all derived from the nominal machine current IM)
%
%     I_M      = IM                 = 1.0000 * IM   [A]  motor phase
%     I_line   = IM * sqrt(2/3)     = 0.8165 * IM   [A]  valve-side line
%     I_branch = IM / sqrt(3)       = 0.5774 * IM   [A]  bridge branch
%     I_outer  = IM / sqrt(6)       = 0.4082 * IM   [A]  outer branch
%
%   These reproduce the reference drawing at IM = 2380 A as 2380 / 1943 /
%   1374 / 972 A, and the node balances close:
%       sqrt(I_line^2 + I_branch^2) = IM
%       sqrt(I_outer^2 + I_branch^2) = IM / sqrt(2)
%
%   I_line is R.Iv_used in calculate.m. I_branch is the current used for
%   the 'Stapelverschienung' and 'Wandlerverschienung' sections in
%   busbar_check.m, and is confirmed by the reference drawing.
%
%   STANDARDS
%     No IEC/IEEE requirement found for this item. The factors follow from
%     the conduction pattern of a 6-pulse bridge (120 deg conduction gives
%     a branch RMS of Id/sqrt(3) and a line RMS of Id*sqrt(2/3)); IEC
%     60146-1-1 covers converter ratings but prescribes no such drawing.
%
%   ASSUMPTIONS
%     1. Nominal machine current. Overload and startup are not drawn.
%     2. The geometry is transcribed from the reference schematic. Wire
%        and label positions live in the tables below and are the only
%        thing to edit if the drawing needs correcting.
%
%   NOT EXECUTED: statically reviewed only, no MATLAB runtime was
%   available when this was written.

arguments
    Input        (1,1) struct
    outputFolder (1,:) char = ''
end

if ~isfield(Input, 'IM')
    error('generate_cyclo_current_distribution_figure:MissingIM', ...
        'Input.IM (nominal machine current [A]) is required.');
end
validateattributes(Input.IM, {'double'}, {'scalar','positive','finite'}, ...
    mfilename, 'Input.IM');

IM = Input.IM;

%% ---------------- Current ladder ---------------------------------------
I_M      = IM;                 % motor phase        [A]
I_line   = IM * sqrt(2/3);     % valve-side line    [A]
I_branch = IM / sqrt(3);       % bridge branch      [A]
I_outer  = IM / sqrt(6);       % outer branch       [A]

%% ---------------- Fixed geometry ---------------------------------------
% Column x positions and the seven horizontal node levels.
xTerm = 0.0;    % R / S / T terminals
xOutL = 1.6;    % left  output vertical
xL    = 3.5;    % left  thyristor column
xR    = 6.5;    % right thyristor column
xOutR = 8.2;    % right output vertical (motor phase, IM)

yTop = 7; yBot = 1;                  % node levels, 7 down to 1
phaseLevels = [6 4 2];               % R, S, T
phaseNames  = {'R','S','T'};

% Thyristor orientation, top to bottom. +1 points up, -1 points down.
dirL = [+1 +1 -1 -1 +1 +1];
dirR = [-1 -1 +1 +1 -1 -1];

% Wire segments: x1, x2, y, current [A], label side ('c' centred).
%   Only the five distinct current values appear.
seg = [ ...
    xL,    xR,    7,  I_outer
    xR,    xOutR, 7,  I_branch
    xTerm, xL,    6,  I_line
    xL,    xR,    6,  I_branch
    xOutL, xL,    5,  I_line
    xL,    xR,    5,  I_branch
    xTerm, xL,    4,  I_line
    xL,    xR,    4,  I_branch
    xL,    xR,    3,  I_branch
    xR,    xOutR, 3,  I_line
    xTerm, xL,    2,  I_line
    xL,    xR,    2,  I_branch
    xOutL, xL,    1,  I_branch
    xL,    xR,    1,  I_outer ];

%% ---------------- Figure -----------------------------------------------
fig = figure('Color','w','Position',[100 100 760 900],'Visible','on');
ax  = axes(fig); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');

LW = 1.6;   FS = 9;

% Output verticals
plot(ax, [xOutL xOutL], [5 0.1], 'k-', 'LineWidth', LW);
plot(ax, [xOutR xOutR], [7 0.1], 'k-', 'LineWidth', LW);

% Thyristor columns
for k = 1:6
    yA = yTop - k + 1;  yB = yA - 1;
    plot(ax, [xL xL], [yA yB], 'k-', 'LineWidth', LW);
    plot(ax, [xR xR], [yA yB], 'k-', 'LineWidth', LW);
    drawThyristor(ax, xL, (yA+yB)/2, dirL(k), LW);
    drawThyristor(ax, xR, (yA+yB)/2, dirR(k), LW);
end

% Horizontal segments and their labels
for k = 1:size(seg,1)
    x1 = seg(k,1); x2 = seg(k,2); y = seg(k,3); I = seg(k,4);
    plot(ax, [x1 x2], [y y], 'k-', 'LineWidth', LW);
    text(ax, (x1+x2)/2, y+0.22, sprintf('%.0f A', I), ...
        'HorizontalAlignment','center', 'FontSize', FS);
end

% Nodes
for y = yBot:yTop
    plotNode(ax, xL, y); plotNode(ax, xR, y);
end
plotNode(ax, xOutL, 5); plotNode(ax, xOutL, 1);
plotNode(ax, xOutR, 7); plotNode(ax, xOutR, 3);

% Phase terminals
for k = 1:numel(phaseLevels)
    y = phaseLevels(k);
    plot(ax, xTerm, y, 'ko', 'MarkerFaceColor','w', 'MarkerSize', 6);
    text(ax, xTerm-0.35, y, phaseNames{k}, 'FontWeight','bold', ...
        'FontSize', FS+2, 'HorizontalAlignment','center');
end

% Output labels
text(ax, xOutL, -0.15, sprintf('%.0f A', I_M), ...
    'HorizontalAlignment','center', 'FontSize', FS);
text(ax, xOutR, -0.15, sprintf('%.0f A', I_M), ...
    'HorizontalAlignment','center', 'FontSize', FS, ...
    'FontWeight','bold', 'BackgroundColor',[0.9 0.9 0.9]);
text(ax, xOutR+0.9, 0.6, 'I_M', 'Color',[0.8 0 0], ...
    'FontWeight','bold', 'FontSize', FS+3);

title(ax, sprintf( ...
    'Current distribution, 12-pulse MEGADRIVE CYCLO   (I_M = %.0f A)', I_M), ...
    'FontWeight','bold');

xlim(ax, [xTerm-1.0, xOutR+1.6]);
ylim(ax, [-0.8, yTop+1.0]);

%% ---------------- Export -----------------------------------------------
% figPath is always a char vector and fig is always a handle. An earlier
% version reassigned fig to the file path after export, making the return
% type depend on the arguments, which breaks any caller that does not know
% in advance whether outputFolder was supplied.
figPath = '';
if ~isempty(outputFolder)
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    figPath = fullfile(outputFolder, 'cyclo_current_distribution.png');
    exportgraphics(fig, figPath, 'Resolution', 200);
    close(fig);
end

end

%% ========================================================================
function drawThyristor(ax, x, y, dir, LW)
%DRAWTHYRISTOR  Filled triangle plus cathode bar, pointing up (+1) or down.
w = 0.42;   % half width
h = 0.42;   % height

if dir > 0
    tri = [x-w, y-h/2; x+w, y-h/2; x, y+h/2];
    yBar = y + h/2;
else
    tri = [x-w, y+h/2; x+w, y+h/2; x, y-h/2];
    yBar = y - h/2;
end

patch(ax, 'XData', tri(:,1), 'YData', tri(:,2), ...
    'FaceColor','k', 'EdgeColor','k');
plot(ax, [x-w x+w], [yBar yBar], 'k-', 'LineWidth', LW);
end

%% ========================================================================
function plotNode(ax, x, y)
%PLOTNODE  Small open circle marking a connection point.
plot(ax, x, y, 'ko', 'MarkerFaceColor','w', 'MarkerSize', 5);
end
