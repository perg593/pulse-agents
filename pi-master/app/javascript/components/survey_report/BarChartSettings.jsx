import React from 'react';
import PropTypes from 'prop-types';

import {contextMenu, Item, Menu, Separator} from 'react-contexify';
import 'react-contexify/ReactContexify.css';

import SortingPopup from './SortingPopup';
import ColorPickerPopup from './ColorPickerPopup';
import SettingsIcon from './SettingsIcon';

import SortingIcon from '../../images/sorting.svg';
import PaintbrushIcon from '../../images/paintbrush.svg';
import CogIcon from '../../images/cog.svg';

const BarChartSettings = (props) => {
  const [showColorPicker, setShowColorPicker] = React.useState(false);
  const [showSortingPopup, setShowSortingPopup] = React.useState(false);

  const contextMenuId = `context_menu_${props.chartId}`;

  return (
    <>
      <Menu id={contextMenuId}>
        <Item onClick={props.viewFullScreen}> View Full Screen </Item>
        <Separator />
        <Item onClick={props.downloadImage}> Download Image </Item>
      </Menu>

      {
                showSortingPopup ?
                    <SortingPopup
                      chartId={props.chartId}
                      sortingOptions={props.sortingOptions}
                      sortingOrder={props.sortingOrder}
                      sortingDirection={props.sortingDirection}
                      updateSorting={(newOrder, newDirection) => {
                        setShowSortingPopup(false); // TODO: Manage this state in a component higher in the hierarchy
                        props.updateSorting(newOrder, newDirection);
                      }}
                    /> : null
      }
      {
                showColorPicker ?
                    <ColorPickerPopup
                      legend={props.legend}
                      updateColor={(selectedLegendId, previewColor, colorUpdateUrl) => {
                        setShowColorPicker(false); // TODO: Manage this state in a component higher in the hierarchy
                        props.updateColor(selectedLegendId, previewColor, colorUpdateUrl);
                      }}
                      hideColorPicker={() => {
                        setShowColorPicker(false);
                      }}
                    /> : null
      }
      <div className='settings-control-container'>
        <button
          className='settings-control'
          onClick={(e) => {
            setShowSortingPopup(true);
          }}
          title='Sort possible answers'
        >
          <SettingsIcon icon={SortingIcon} />
        </button>
        <button
          className='settings-control'
          onClick={(e) => {
            setShowColorPicker(true);
          }}
          title='Change colors'
        >
          <SettingsIcon icon={PaintbrushIcon} />
        </button>
        <button
          className='settings-control'
          onClick={(e) => {
            contextMenu.show({id: contextMenuId, event: e});
          }}
        >
          <SettingsIcon icon={CogIcon} />
        </button>
      </div>
    </>
  );
};

BarChartSettings.propTypes = {
  viewFullScreen: PropTypes.func.isRequired,
  downloadImage: PropTypes.func.isRequired,

  chartId: PropTypes.number,
  sortingOptions: PropTypes.array.isRequired, //  [['position', 'Default'], ['alphabetical', 'Alphabetical']]
  sortingOrder: PropTypes.string.isRequired,
  sortingDirection: PropTypes.string.isRequired,
  updateSorting: PropTypes.func.isRequired,

  legend: PropTypes.array.isRequired,
  updateColor: PropTypes.func.isRequired,
};

export default BarChartSettings;
