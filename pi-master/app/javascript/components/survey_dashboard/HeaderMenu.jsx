import React from 'react';
import PropTypes from 'prop-types';

import OutsideClickHandler from 'react-outside-click-handler';
import {Droppable, Draggable} from '@hello-pangea/dnd';

/**
 * The context menu that appears on the header row
 */
class HeaderMenu extends React.Component {
  /**
   * Initializes the HeaderMenu
   * @param {Object} props
   */
  constructor(props) {
    super(props);
  }

  /**
   * Returns styling for individual list items
   * @param {boolean} isDragging - whether or not the item is being dragged
   * @param {boolean} draggableStyle - any overriding styles
   * @return {Object} the styles object
   */
  getItemStyle(isDragging, draggableStyle) {
    return {
      boxShadow: isDragging ? '0px 2px 11px 0px rgba(0, 0, 0, 0.2)' : '',
      ...draggableStyle,
    };
  }

  /**
   * @return {JSX.Element} the HeaderMenu
   */
  render() {
    if (this.props.isHidden) {
      return null;
    } else {
      return (
        <OutsideClickHandler
          onOutsideClick={() => this.props.outsideClickHandler()}
        >
          <div
            className="popup-menu header-menu"
            style={{
              left: this.props.position[0],
              top: this.props.position[1],
            }}
          >
            <Droppable droppableId="headerMenuDroppable" direction="vertical">
              {(provided, snapshot) => (
                <ul
                  {...provided.droppableProps}
                  ref={provided.innerRef}
                >
                  {
                    this.props.allColumns.map((column, index) => {
                      return (column.visible === false || column.id === 'nameID') ?
                        null :
                          <Draggable
                            key={column.id}
                            draggableId={column.id + '_context_menu'}
                            index={index}
                            isDragDisabled={!column.accessor}
                          >
                            {(provided, snapshot) => {
                              return (
                                <li
                                  ref={provided.innerRef}
                                  {...provided.draggableProps}
                                  {...provided.dragHandleProps}
                                  style={this.getItemStyle(
                                      snapshot.isDragging,
                                      provided.draggableProps.style,
                                  )}
                                >
                                  <input
                                    type="checkbox" {...column.getToggleHiddenProps() }
                                    className="survey-filter-checkbox"
                                  />
                                  {column.Header}
                                </li>
                              );
                            }}
                          </Draggable>;
                    })
                  }
                  {provided.placeholder}
                </ul>
              )}
            </Droppable>
            <br />
          </div>
        </OutsideClickHandler>
      );
    }
  }
}

HeaderMenu.propTypes = {
  isHidden: PropTypes.bool.isRequired,
  outsideClickHandler: PropTypes.func.isRequired,
  position: PropTypes.array.isRequired,
  allColumns: PropTypes.array.isRequired,
};

export default HeaderMenu;
