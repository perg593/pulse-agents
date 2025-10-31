import React from 'react';
import PropTypes from 'prop-types';

import domtoimage from 'dom-to-image';

import BarChartSettings from './BarChartSettings';

// TODO: DRY off with PageEvent component in general https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2181
const CustomContentLinkClicks = (props) => {
  const [customContentLinkClicksSortingOrder, setCustomContentLinkClicksSortingOrder] = React.useState('position'); // ('content, 'answer_count', 'position'[default])
  const [customContentLinkClicksSortingDirection, setCustomContentLinkClicksSortingDirection] = React.useState('ascending'); // ('ascending', 'descending')

  const [newColors, setNewColors] = React.useState(() => {
    const updatedColors = {};
    props.links.forEach((link) => updatedColors[link.id] = link.color);
    return updatedColors;
  });

  const [fullScreenEnabled, setFullScreenEnabled] = React.useState(false); // NOTE: Not used yet. See React.useEffect that toggles "full-screen" class

  const linkClicksChart = () => document.getElementById(`chart_${props.questionId}`);

  React.useEffect(() => {
    const fullScreenChangeEvents = ['fullscreenchange', 'webkitfullscreenchange', 'mozfullscreenchange', 'MSFullscreenChange'];

    fullScreenChangeEvents.forEach((event) => {
      linkClicksChart().addEventListener(event, function() {
        $(this).toggleClass('full-screen');
        // setFullScreenEnabled(!fullScreenEnabled); // TODO: Make this work
      }, false);
    });
  });

  const viewFullScreen = () => {
    const chart = linkClicksChart();
    if (chart.requestFullscreen) {
      chart.requestFullscreen();
    } else if (chart.mozRequestFullScreen) {
      chart.mozRequestFullScreen();
    } else if (chart.webkitRequestFullscreen) {
      chart.webkitRequestFullscreen();
    } else if (chart.msRequestFullscreen) {
      chart.msRequestFullscreen();
    }
  };

  const downloadImage = () => {
    domtoimage.toPng(linkClicksChart()).then((dataUrl) => {
      const link = document.createElement('a');
      link.download = 'graph.png';
      link.href = dataUrl;
      link.click();
    });
  };

  const sortCustomContentLinks = () => {
    const links = [...props.links];

    switch (customContentLinkClicksSortingOrder) {
      case 'alphabetical':
        links.sort((a, b) => a.text.localeCompare(b.text));
        break;
      case 'link_click_rate':
        links.sort((a, b) => a.clickRate - b.clickRate);
        break;
    }

    if (customContentLinkClicksSortingDirection === 'descending') {
      links.reverse();
    }

    return links;
  };

  const updateColor = (linkId, newColor, colorUpdateUrl) => {
    $.ajax({
      url: colorUpdateUrl,
      data: {
        question_id: props.questionId,
        color: newColor,
      },
      method: 'PATCH',
      success: () => {
        const approvedColors = {...newColors};
        approvedColors[linkId] = newColor;

        setNewColors(approvedColors);
      },
      error: (result) => {
        const errorMessage = result.responseJSON['error'];
        console.error(errorMessage);
      },
    });
  };

  const colorPickerData = props.links.map((link) => {
    return {
      id: link.id,
      name: link.text,
      color: newColors[link.id],
      colorUpdateUrl: link.colorUpdateUrl,
    };
  });

  const CustomContentLinkClicksHeader = () => {
    const sortingOptions = [['position', 'Default'], ['alphabetical', 'Alphabetical'], ['link_click_rate', 'Click Rate']];

    return (
      <div
        id={`question-line-anchor-${props.questionId}`} // For Pipes
        className='custom-content-link-clicks-header'
      >
        <div className='custom-content-question-content'>
          {`${props.questionContent} (${props.entireLinkClickCount} clicks)`}
        </div>
        <BarChartSettings
          chartId={props.questionId}
          viewFullScreen={viewFullScreen}
          downloadImage={downloadImage}
          sortingOptions={sortingOptions}
          sortingOrder={customContentLinkClicksSortingOrder}
          sortingDirection={customContentLinkClicksSortingDirection}
          updateSorting={(newOrder, newDirection) => {
            setCustomContentLinkClicksSortingOrder(newOrder);
            setCustomContentLinkClicksSortingDirection(newDirection);
          }}
          legend={colorPickerData}
          updateColor={updateColor}
        />
      </div>
    );
  };

  const CustomContentLinkClicksChart = () => {
    return (
      // NOTE: fullScreenEnabled is not used yet. See React.useEffect that toggles "full-screen" class
      <div id={`chart_${props.questionId}`} className={`custom-content-link-clicks-chart ${fullScreenEnabled ? 'full-screen' : ''}`}>
        {
          sortCustomContentLinks().map((link) => {
            return (
              <div className='custom-content-link-container' key={link.id}>
                <div className='custom-content-link-labels'>
                  <span className='custom-content-link-content'>{link.text}</span>
                  <span className='custom-content-link-url'>({link.url})</span>
                </div>
                <div className='click-bar-container'>
                  <div className='click-bar' style={{width: `${link.clickRate}%`, backgroundColor: newColors[link.id]}}/>
                  <span className='click-stat'>{link.clickCount} ({link.clickRate}%)</span>
                </div>
              </div>
            );
          })
        }
      </div>
    );
  };

  return (
    <div className='custom-content-link-clicks'>
      <CustomContentLinkClicksHeader/>
      <CustomContentLinkClicksChart/>
    </div>
  );
};

CustomContentLinkClicks.propTypes = {
  questionId: PropTypes.number.isRequired,
  questionContent: PropTypes.string.isRequired,
  entireLinkClickCount: PropTypes.number.isRequired,
  links: PropTypes.array.isRequired,
};

export default CustomContentLinkClicks;
