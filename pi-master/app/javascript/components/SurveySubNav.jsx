import React from 'react';
import PropTypes from 'prop-types';

import DOMPurify from 'dompurify';

import EditIcon from '../images/pencil.svg';

SurveySubNav.propTypes = {
  selectedTab: PropTypes.string.isRequired,
  subnavLinks: PropTypes.array.isRequired,
  qrveyReportEditLink: PropTypes.object,
};

/**
 * A survey subnavigation bar
 * Link labels may include HTML
 *
 * @param { Object } props
 * @return { JSX.Element }
*/
function SurveySubNav(props) {
  const SubnavLink = ({url, label, name}) => {
    const linkMarkup = {__html: DOMPurify.sanitize(label)};

    return (
      <li className={tabClass(name)}>
        <a href={url} dangerouslySetInnerHTML={linkMarkup}>
        </a>
      </li>
    );
  };

  const SubnavPopupLink = ({name, subNavLabel, popupLinks}) => {
    const [showPopup, setShowPopup] = React.useState(false);

    const subnavLinkMarkup = {__html: DOMPurify.sanitize(subNavLabel)};

    return (
      <li
        className={`report-subnav-link ${tabClass(name)}`}
        onMouseEnter={() => setShowPopup(true)}
        onMouseLeave={() => setShowPopup(false)}
      >
        <span dangerouslySetInnerHTML={subnavLinkMarkup}></span>
        {
          showPopup ?
            <div className='report-subnav-popup'>
              {
                popupLinks.map((link) => {
                  return (
                    <div key={link.label}>
                      <a href={link.url}>
                        {link.label}
                      </a>
                    </div>
                  );
                })
              }
            </div> : null
        }
      </li>
    );
  };

  const tabClass = (tabName) => {
    return props.selectedTab === tabName ? 'selected' : '';
  };

  /**
   * A link to the Qrvey report in edit mode (or view mode), as appropriate
   * @return { JSX.Element }
   **/
  function QrveyReportEditLink() {
    if (props.qrveyReportEditLink) {
      const editMode = props.qrveyReportEditLink.editing;

      return (
        <a
          className={`outlined-link-with-icon ${editMode ? 'inverted' : ''}`}
          href={props.qrveyReportEditLink.url}
        >
          <span
            className='icon'
            style={{
              maskImage: `url(${EditIcon})`,
              WebkitMaskImage: `url(${EditIcon})`,
            }}
          >
          </span>
          <span className='pi-label'>{props.qrveyReportEditLink.label}</span>
        </a>
      );
    } else {
      return null;
    }
  }

  return (
    <div className='survey-subnav-container'>
      <ul className='survey-subnav'>
        {
          props.subnavLinks.map((link) => {
            return (
              // Display links through a popup when there are multiple links
              link.popupLinks ? // E.g report url & page event url
                <SubnavPopupLink
                  key={link.name}
                  name={link.name}
                  subNavLabel={link.subNavLabel}
                  popupLinks={link.popupLinks}
                /> :
                <SubnavLink
                  key={link.name}
                  url={link.url}
                  label={link.label}
                  name={link.name}
                />
            );
          })
        }
      </ul>
      <QrveyReportEditLink />
    </div>
  );
};

export default SurveySubNav;
