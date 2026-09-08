function enableResponsiveScaling(container, varargin)
%ENABLERESPONSIVESCALING  Make a uipanel/uitab's direct pixel-positioned
%children scale proportionally whenever the container itself is resized.
%
%   enableResponsiveScaling(container)
%   enableResponsiveScaling(container, 'MinScale', 1.0, 'MaxScale', Inf)
%
%   WHAT PROBLEM THIS SOLVES
%   -------------------------------------------------------------------
%   A uifigure-based app whose controls are placed with fixed pixel
%   Position values (the standard uipanel/uitable/uiaxes/uieditfield
%   pattern) looks correct only at the screen resolution it was
%   designed on. On any other monitor, content is either clipped (too
%   small a window) or stranded in a small corner with wasted empty
%   space (too large a window). This function is a generic, reusable
%   retrofit for that problem: it does not require recomputing any
%   control's position by hand.
%
%   HOW IT WORKS
%   -------------------------------------------------------------------
%   Call it once, AFTER all of CONTAINER's children have been created,
%   on every uipanel or uitab whose direct children use pixel Units.
%   It records each such child's current Position (its "design"
%   geometry) together with CONTAINER's current size (its "design"
%   size), then installs CONTAINER.SizeChangedFcn so that on every
%   subsequent resize:
%
%       sx = clamp(currentWidth  / designWidth,  MinScale, MaxScale)
%       sy = clamp(currentHeight / designHeight, MinScale, MaxScale)
%       child.Position = designPosition .* [sx sy sx sy]
%
%   Width and height scale independently, so content fills the
%   available area rather than only the smaller of the two dimensions.
%   Only Position is touched (not FontSize): some component types
%   raise "Functionality not supported with figures created with the
%   uifigure function" when FontSize is set programmatically from a
%   callback, so this utility deliberately leaves fonts at their
%   designed size to avoid that failure mode.
%
%   Children already using normalized (or other non-pixel) Units are
%   left completely alone -- they are assumed to already manage their
%   own resizing (as, e.g., a normalized-Units uitable already does).
%
%   This composes across nesting levels with no extra code: if CONTAINER
%   is itself one of the pixel-positioned children of an outer
%   container that also has enableResponsiveScaling applied, resizing
%   the outer container rescales CONTAINER's Position, which (because
%   changing Position fires SizeChangedFcn) automatically triggers
%   CONTAINER's own rescale of ITS children, and so on.
%
%   NAME-VALUE ARGUMENTS
%   -------------------------------------------------------------------
%     MinScale (default 0.6) - never shrink a child below this fraction
%                               of its designed size. Pass 1.0 for a
%                               "grow-only" container: it fills extra
%                               space on a larger screen but never
%                               shrinks below its designed size on a
%                               smaller one. Grow-only containers should
%                               be paired with Scrollable = 'on' on
%                               their parent uitab, so nothing is ever
%                               lost below the MinScale floor -- the
%                               user scrolls to it instead.
%     MaxScale (default Inf) - cap on growth, if unbounded growth would
%                               look wrong (e.g. absurdly large fonts on
%                               an ultrawide monitor).
%
%   LIMITATION
%   -------------------------------------------------------------------
%   This is a uniform linear rescale of an already-tuned pixel layout,
%   not a true constraint-based/flow layout -- it reproduces the
%   original design's proportions at other sizes, it does not redesign
%   them. For new development, MATLAB's uigridlayout is the more
%   robust, natively responsive container and should be preferred; this
%   function exists for retrofitting an existing fixed-pixel-position
%   uifigure app without rewriting every control's construction call.

p = inputParser;
addParameter(p, 'MinScale', 0.6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxScale', Inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, varargin{:});
minScale = p.Results.MinScale;
maxScale = p.Results.MaxScale;

if ~(isprop(container,'Position') && isprop(container,'Children'))
    error('enableResponsiveScaling:InvalidContainer', ...
        'container must be a graphics object with Position and Children (e.g. a uipanel or uitab).');
end

% uipanel/uitab default to AutoResizeChildren = 'on', which runs
% MATLAB's own basic built-in child-resize behavior AND explicitly
% suppresses SizeChangedFcn while it is on (MATLAB emits a warning to
% that effect). Our custom rescale logic below is what should run
% instead, so it must be turned off here, on every container we take
% over.
if isprop(container,'AutoResizeChildren')
    container.AutoResizeChildren = 'off';
end

recordDesignGeometry(container);
container.SizeChangedFcn = @(src,~) rescaleResponsiveChildren(src, minScale, maxScale);

end

function recordDesignGeometry(container)
% NOTE: this deliberately does NOT record/scale FontSize. Some
% component types in a uifigure app throw "Functionality not
% supported with figures created with the uifigure function" when
% FontSize is set programmatically from a callback in certain MATLAB
% configurations -- Position is the only property this utility
% touches, which is both sufficient to fix visibility/clipping and
% avoids that failure mode entirely.
designSize = container.Position(3:4);
children = container.Children;
for k = 1:numel(children)
    c = children(k);
    if ~(isprop(c,'Position') && isprop(c,'Units'))
        continue
    end
    if ~strcmpi(c.Units,'pixels')
        continue   % normalized/self-managing child -- leave it alone
    end
    setappdata(c,'RespDesignPosition',c.Position);
    setappdata(c,'RespDesignContainerSize',designSize);
end
end

function rescaleResponsiveChildren(container, minScale, maxScale)
curSize = container.Position(3:4);
children = container.Children;
for k = 1:numel(children)
    c = children(k);
    if ~isappdata(c,'RespDesignPosition')
        continue
    end
    designPos  = getappdata(c,'RespDesignPosition');
    designSize = getappdata(c,'RespDesignContainerSize');
    if any(designSize <= 0)
        continue
    end
    sx = curSize(1)/designSize(1);
    sy = curSize(2)/designSize(2);
    sx = min(max(sx,minScale),maxScale);
    sy = min(max(sy,minScale),maxScale);
    try
        c.Position = designPos .* [sx sy sx sy];
    catch
        % Defensive: skip a component type that rejects a
        % programmatic Position change in this MATLAB/figure
        % configuration, rather than aborting the resize of every
        % other child in this container.
    end
end
end
