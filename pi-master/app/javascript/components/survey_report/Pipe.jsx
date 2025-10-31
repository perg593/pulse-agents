import React from 'react';
import PropTypes from 'prop-types';

const Line = (props) => {
  return (
    <path
      strokeWidth="1px"
      stroke={props.color}
      d={props.path}
      fill='none'
      strokeLinejoin='round'
    />
  );
};

Line.propTypes = {
  color: PropTypes.string.isRequired,
  path: PropTypes.string.isRequired,
};

// Draws the line and cap joining a possible answer to its next question
//
// Rendering is complicated by the need to wait for other things to be rendered.
const Pipe = (props) => {
  const [startCapOrigin, setStartCapOrigin] = React.useState({x: 0, y: 0});
  const [endCapOrigin, setEndCapOrigin] = React.useState({x: 0, y: 0});
  const [path, setPath] = React.useState('M10,10 L100,10 L100,100 L10,100');
  const [svgOffset, setSVGOffset] = React.useState([0, 0]);
  const [readyToRender, setReadyToRender] = React.useState(false);

  // legacy colour
  const [strokeColour, _setStrokeColour] = React.useState('#4c5965');

  // Used only to prompt rerendering on screen size changes
  const [_size, setSize] = React.useState([0, 0]);

  // Used only to prompt rerendering on container size changes
  const [containerWidth, setContainerWidth] = React.useState(() => {
    return $('.survey-report-container').innerWidth();
  });

  const endCapRadius = 10;

  const sourceBox = () => {
    return document.getElementById(props.sourceId);
  };

  const targetBox = () => {
    return document.getElementById(props.targetId);
  };

  const offsetY = () => {
    return sourceBox().offsetTop + (sourceBox().offsetHeight / 2);
  };

  const targetY = () => {
    return targetBox().offsetTop - offsetY() + (targetBox().offsetHeight / 2);
  };

  // Special thanks to https://stackoverflow.com/questions/19014250/rerender-view-on-browser-resize-with-react
  // Generates a hook that changes on window resize, which prompts a rendering
  React.useLayoutEffect(() => {
    /**
     * Updates our hook
     **/
    function updateSize() {
      setSize([window.innerWidth, window.innerHeight]);
    }

    window.addEventListener('resize', updateSize);

    updateSize();

    return () => window.removeEventListener('resize', updateSize);
  }, []);

  // Poll the size of the container to decide whether we should redraw
  // Ideally this would be done with React, but since these components have
  // no shared ancestor, we have to get creative.
  React.useLayoutEffect(() => {
    const interval = setInterval((() => {
      setContainerWidth($('.survey-report-container').innerWidth());
    }), 100);

    return () => clearInterval(interval);
  }, []);

  // Just a rough check to tell whether the source element has moved
  // so that we know to reposition ourselves
  const sourcePos = () => {
    return sourceBox()?.offsetTop;
  };

  const elbowWidth = endCapRadius + 10 * (props.laneIndex + 1);

  /**
   * Redraw the pipe when we know the source and target positions
   **/
  function redraw() {
    const offsetX = `${sourceBox().offsetLeft + sourceBox().offsetWidth + 20}px`;

    setSVGOffset([offsetX, `${offsetY()}px`]);

    setStartCapOrigin({x: 0, y: 0});
    setEndCapOrigin({x: 0, y: targetY() - endCapRadius});

    // ---\
    //    |
    //    |
    // <--/

    let linePath = '';

    // The initial --
    linePath = `${linePath} M0,${endCapRadius} L${elbowWidth-4},${endCapRadius}`;

    // The bend downwards \
    linePath = `${linePath} M${elbowWidth-4},${endCapRadius} A4 4 0 0 1 ${elbowWidth},12 `;

    // The drop |
    linePath = `${linePath} L${elbowWidth},${targetY()-4}`;

    // The bend leftwards /
    linePath = `${linePath} M${elbowWidth},${targetY()-4} A4 4 0 0 1 ${elbowWidth-4},${targetY()}`;

    // the final tail --
    linePath = `${linePath} L5,${targetY()}`;

    setPath(linePath);

    setReadyToRender(true);
  }

  // The pipe needs coordinates that cannot be known before the
  // source and target elements have been rendered.
  React.useEffect(() => {
    setTimeout(() => {
      redraw();
    }, 100);
  }, [props.force || sourcePos(), containerWidth]);

  // TODO: Only draw as many caps as you need, don't draw one per line
  // Draws a semicircle
  // |\
  // | |
  // |/
  const Cap = ({origin}) => {
    return (
      <path
        d={`M0,0 A${endCapRadius},${endCapRadius} 0 0,1 0,20`}

        stroke={props.colorOverride || strokeColour}
        fill={props.colorOverride || strokeColour}
        transform={`translate(${origin.x}, ${origin.y})`}
      />
    );
  };

  if (readyToRender) {
    return (
      <svg
        style={{
          display: 'block',
          position: 'absolute',
          height: `${targetY() + endCapRadius}px`,
          left: svgOffset[0],
          top: svgOffset[1],
          width: `${elbowWidth + 2}px`,
        }}
      >
        <Cap origin={startCapOrigin} />
        <Line path={path} color={props.colorOverride || strokeColour} />
        <Cap origin={endCapOrigin} />
      </svg>
    );
  } else {
    return null;
  }
};

Pipe.propTypes = {
  sourceId: PropTypes.string.isRequired,
  targetId: PropTypes.string.isRequired,
  laneIndex: PropTypes.number.isRequired,
  colorOverride: PropTypes.string,
  force: PropTypes.bool,
};

export default Pipe;
