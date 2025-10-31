import React, {ReactNode} from 'react';

import OutsideClickHandler from 'react-outside-click-handler';

interface PopupProps {
  additionalClasses?: string,
  buttonText: string,
  children: ReactNode,
  triggerElement?: ReactNode,
}

/**
 * A generic popup menu
 *
 * @param {PopupProps} props
 * @return {JSX.Element}
 **/
function Popup(props: PopupProps) {
  const [showPanel, setShowPanel] = React.useState(false);
  const [panelPosition, setPanelPosition] = React.useState([0, 0]);

  const activatePanel = (e) => {
    setShowPanel(true);
    setPanelPosition([e.clientX, e.clientY]);
  };

  /**
   * The element which will trigger the appearance of
   * the popup when clicked
   *
   * @return {JSX.Element}
   **/
  function TriggerElement() {
    if (props.triggerElement) {
      return (
        <a className='popup-trigger' href='#' onClick={(e) => activatePanel(e)}>
          { props.triggerElement }
        </a>
      );
    }

    return (
      <button onClick={(e) => activatePanel(e)}>
        { props.buttonText }
      </button>
    );
  }

  return (
    <>
      <TriggerElement />

      {
        showPanel ?
          <div className='outside-click-handler-wrapper'>
            <OutsideClickHandler onOutsideClick={() => setShowPanel(false)} >
              <div className={`popup-menu ${props.additionalClasses ?? ''}`}
                style={{
                  left: `${panelPosition[0]}px`,
                  top: `${panelPosition[1]}px`,
                }}
              >
                {props.children}
              </div>
            </OutsideClickHandler>
          </div> : null
      }
    </>
  );
}

export default Popup;
