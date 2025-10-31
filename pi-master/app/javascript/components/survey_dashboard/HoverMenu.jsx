import React from 'react';
import PropTypes from 'prop-types';

import OutsideClickHandler from 'react-outside-click-handler';

import HoverEllipses from '../../images/survey_dashboard/three_dots.svg';
import {popupPosition} from '../PopupPositioning.ts';

/**
 * The menus that appear on individual rows
 * If visible, render a popup, otherwise render nothing
 */
class HoverMenu extends React.Component {
  /**
   * Initializes the HoverMenu
   * @param {Object} props
   */
  constructor(props) {
    super(props);

    this.state = {
      showingPopup: false,
      popupLocation: [0, 0],
    };

    this.onKeydown = this.onKeydown.bind(this);
    this.onClick = this.onClick.bind(this);
  }

  /**
   * Register keydown listener
   */
  componentDidMount() {
    document.addEventListener('keydown', this.onKeydown, false);
  }

  /**
   * Unregister keydown listener
   */
  componentWillUnmount() {
    document.removeEventListener('keydown', this.onKeydown);
  }

  /**
   * Keydown handler
   * @param {KeyboardEvent} event
   */
  onKeydown(event) {
    if (event.key === 'Escape') {
      this.hidePopup();
    }
  }

  /**
   * Position the hover menu
   * @param {MouseEvent} e
   */
  onClick(e) {
    if (!this.state.showingPopup) {
      this.setState(
          {
            showingPopup: true,
            popupLocation: popupPosition(e, 200),
          },
      );
    }
  }

  /**
   * Hide the hover menu
   */
  hidePopup() {
    this.setState({showingPopup: false});
  }

  /**
   * Show the hover menu
   * @param {MouseEvent} e
   */
  invokePopup(e) {
    const modalId = e.target.dataset.modalId;

    const addRowFunction = this.props.addRow;
    const removeRowFunction = this.props.removeRow;

    const surveyId = this.props.surveyId;
    const action = e.target.dataset.action;

    if (modalId) {
      e.preventDefault();

      const placeholder = $(`#${modalId}_placeholder`);
      if (placeholder.length > 0) {
        // request modal from server
        $.ajax({
          url: e.target.href,
        }).done(function(responseData) {
          placeholder.html(responseData);

          ReactRailsUJS.mountComponents(`#${modalId}_placeholder`);

          const modal = $(`#${modalId}`);
          modal.modal();
        }).fail(function(jqXHR, textStatus, errorThrown) {
          console.debug('failed to load modal', jqXHR, textStatus, errorThrown);
        });
      } else {
        const modal = $(`#${modalId}`);
        modal.modal();
      }
    } else if (action === 'duplicate' || action === 'delete') {
      e.preventDefault();

      $.ajax({
        url: e.target.href,
        method: e.target.attributes.method.value,
      }).done(function(responseData) {
        switch (action) {
          case 'duplicate':
            addRowFunction(responseData.newSurvey, surveyId);
            break;
          case 'delete':
            removeRowFunction(surveyId);
            break;
        }
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.debug('error making request', jqXHR, textStatus, errorThrown);
        alert(jqXHR.responseJSON.error);
      });
    }
  }

  /**
   * Returns the hover menu popup
   * @return {JSX.Element}
   */
  renderPopup() {
    if (this.state.showingPopup) {
      return (
        <OutsideClickHandler onOutsideClick={() => this.hidePopup()} >
          <div className="popup-menu hover-menu" style={{
            left: this.state.popupLocation[0],
            top: this.state.popupLocation[1],
          }}
          >
            <ul>
              { this.props.rowLinks.map((linkData) => {
                return (
                  <li key={linkData.label}>
                    <a href={linkData.url} className={linkData.class}
                      data-modal-id={linkData.data_modal_id}
                      data-confirm={linkData.confirmation_message}
                      data-action={linkData.action}
                      method={linkData.method || 'get'}
                      onClick={(e) => this.invokePopup(e)}
                    >
                      {linkData.label}
                    </a>
                  </li>
                );
              })}
            </ul>
          </div>
        </OutsideClickHandler>
      );
    } else {
      return null;
    }
  }

  /**
   * Ensures popup is hidden when visibility changes
   * @param {Object} nextProps the props for the next potential rendering
   */
  componentWillReceiveProps(nextProps) {
    if (nextProps.isVisible !== this.props.isVisible) {
      this.setState({showingPopup: false});
    }
  }

  /**
   * If visible, render a popup, otherwise render nothing
   * @return {JSX.Element}
   */
  render() {
    if (this.props.isVisible) {
      return (
        <>
          <img
            onClick={this.onClick}
            src={HoverEllipses}
            className="hover-ellipses"
          />
          { this.renderPopup() }
        </>
      );
    } else {
      return null;
    }
  }
}

HoverMenu.propTypes = {
  addRow: PropTypes.func.isRequired,
  removeRow: PropTypes.func.isRequired,
  surveyId: PropTypes.number,
  isVisible: PropTypes.bool.isRequired,
  rowLinks: PropTypes.array.isRequired,
};

export default HoverMenu;
