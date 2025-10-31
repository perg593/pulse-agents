import React from 'react';
import PropTypes from 'prop-types';

ZoomPanel.propTypes = {
  diagramEngine: PropTypes.object.isRequired,
};

/**
 * A wrapper component for the survey editors zoom controls
 * @param { Object } props
 * @return { JSX.Element } ZoomPanel
*/
function ZoomPanel(props) {
  const zoomIncrement = 10;
  const minZoomLevel = 0;
  const maxZoomLevel = 500; // sort of arbitrary

  /**
   * Determine whether zoom level is valid
   * @param { number } zoomLevel - a zoom level
   * @return { bool } - whether or not the zoom level is valid
   */
  function validZoomLevel(zoomLevel) {
    return zoomLevel >= minZoomLevel && zoomLevel <= maxZoomLevel;
  };

  /**
   * Determine whether zoom level is valid
   * @param { number } zoomLevel - new zoom level
   */
  function setZoomLevel(zoomLevel) {
    if (!validZoomLevel(zoomLevel)) {
      return;
    }

    const model = props.diagramEngine.getModel();

    model.setZoomLevel(zoomLevel);
    props.diagramEngine.repaintCanvas();
  };

  /**
   * Add to the zoom level
   * @param { number } increment - amount to change the zoom level by
   */
  function incrementZoom(increment) {
    const oldZoomLevel = props.diagramEngine.getModel().getDisplayZoomLevel();
    const newZoomLevel = Math.round(((oldZoomLevel + increment) / 10)) * 10;

    setZoomLevel(newZoomLevel);
  };

  /**
   * Add zoomIncrement to the zoom level
   */
  function increaseZoom() {
    incrementZoom(zoomIncrement);
  };

  /**
   * Subtract zoomIncrement from the zoom level
   */
  function decreaseZoom() {
    incrementZoom(-zoomIncrement);
  };

  return (
    <div className='zoom-control-container'>
      <a
        className='zoom-control decrease-zoom-button'
        href='#'
        onClick={decreaseZoom}
      >
        -
      </a>
      <input
        id='zoom_level_indicator'
        className='zoom-indicator'
        onChange={(e) => {
          let zoomLevel = e.target.value;
          zoomLevel = zoomLevel.replace(/\D/g, '');
          setZoomLevel(parseInt(zoomLevel));
        }}
        defaultValue={`${props.diagramEngine.getModel().getDisplayZoomLevel()}%`}
      />
      <a
        className='zoom-control increase-zoom-button'
        href='#'
        onClick={increaseZoom}
      >
        +
      </a>
    </div>
  );
};

export default ZoomPanel;
