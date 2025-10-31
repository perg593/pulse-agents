import React from 'react';
import PropTypes from 'prop-types';

import PiModal from '../modal_dialog/PiModal';

import ExpandSidebarIcon from '../../images/survey_dashboard/expand.svg';
import CollapseSidebarIcon from '../../images/survey_dashboard/collapse.svg';
import AddIcon from '../../images/add.png';

import DashboardItem from './qrvey_sidebar/DashboardItem';
import AuthenticityTokenContext from './qrvey_sidebar/AuthenticityTokenContext';

QrveySidebar.propTypes = {
  links: PropTypes.object.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  shareOptions: PropTypes.object.isRequired,
  surveyId: PropTypes.number.isRequired,
  authorization: PropTypes.object.isRequired,
  usingHardcodedDefaults: PropTypes.bool.isRequired,
};

/**
 * A wrapper component for the qrvey dashboard sidebar
 * @param { Object } props
 * @return { QrveySidebar }
*/
function QrveySidebar(props) {
  const [sidebarPanelExpanded, setSidebarPanelExpanded] = React.useState(true);
  const expansionClass = sidebarPanelExpanded ? 'expanded' : 'collapsed';
  const [dashboardLinks, setDashboardLinks] = React.useState(props.links);

  const authenticityToken = props.authenticityToken;

  const deleteDashboardLink = (dashboardId) => {
    const newDashboardLinks = {...dashboardLinks};

    const indexToRemove = newDashboardLinks.myReports.indexOf((myReport) => {
      return myReport.dashboardId === dashboardId;
    });
    newDashboardLinks.myReports.splice(indexToRemove, 1);

    setDashboardLinks(newDashboardLinks);
  };

  const newDashboardDialogRef = React.useRef(null);

  const openNewDashboardDialog = () => {
    if (newDashboardDialogRef.current) {
      newDashboardDialogRef.current.showModal();
    }
  };

  /**
   * A modal dialogue for creating a new dashboard
   * @return { Modal }
   **/
  function NewDashboardModal() {
    return (
      <PiModal
        ref={newDashboardDialogRef}
        modalClassName='qrvey-modal'
      >
        <PiModal.Header title='New Report' />

        <PiModal.Body>
          <form
            id='qrvey_dashboard_new_form'
            className='qrvey-dashboard-new-form'
            action='/qrvey/create_dashboard'
            method='POST'
          >
            <input
              type='hidden'
              name='authenticity_token'
              value={authenticityToken}
            />
            {
              props.surveyId ?
                <input
                  type='hidden'
                  name='survey_id'
                  value={props.surveyId}
                /> : null
            }
            <label htmlFor='dashboard_name'>Name:</label>
            <input
              id='dashboard_name'
              name='dashboard_name'
              defaultValue='A new report'
              required={true}
            />
            <label htmlFor='dashboard_description'>
              Description:
            </label>
            <input
              id='dashboard_description'
              name='dashboard_description'
              required={true}
            />
          </form>
        </PiModal.Body>
        <PiModal.Footer>
          <button
            className='pi-primary-button'
            type='submit'
            form='qrvey_dashboard_new_form'
          >
            Create
          </button>
        </PiModal.Footer>
      </PiModal>
    );
  }

  /**
   * List out the built in dashboards
   * i.e. the ones that come with every account
   *
   * @return {JSX.Element}
   **/
  function BuiltInDashboards() {
    return dashboardLinks.builtIn.map((link) => {
      return (
        <DashboardItem
          key={link.url}
          link={link}
          canCopy={props.authorization[link.dashboardId]?.canCopy}
          surveyId={props.surveyId}
        />
      );
    });
  }

  /**
   * List out the dashboards that have been shared with the current user
   *
   * @return {JSX.Element}
   **/
  function SharedDashboards() {
    if (!dashboardLinks.sharedWithMe) {
      return null;
    }

    return (
      <>
        <h2 className='sidebar-header'>Shared With Me</h2>
        {
          dashboardLinks.sharedWithMe.map((link) => {
            return (
              <DashboardItem
                key={link.url}
                link={link}
                canCopy
                canShare
                shareOptions={props.shareOptions[link.dashboardId]}
                canEdit={props.authorization[link.dashboardId]?.canEdit}
                editModeUrl={link.editModeUrl}
                surveyId={props.surveyId}
              />
            );
          })
        }
      </>
    );
  }

  /**
   * List out the dashboards that were created by the current user
   *
   * @return {JSX.Element}
   **/
  function MyDashboards() {
    if (!dashboardLinks.myReports) {
      return null;
    }

    return (
      <>
        <h2 className='sidebar-header'>My Reports</h2>
        {
          dashboardLinks.myReports.map((link) => {
            return (
              <DashboardItem
                key={link.url}
                link={link}
                canCopy
                canShare
                canRevokeAccess
                shareOptions={props.shareOptions[link.dashboardId]}
                canDelete
                deleteDashboardLink={(dashboardId) => {
                  deleteDashboardLink(dashboardId);
                }}
                canEdit
                editModeUrl={link.editModeUrl}
                surveyId={props.surveyId}
              />
            );
          })
        }
      </>
    );
  }

  /**
   * Reloads the dashboard in view mode
   **/
  function reloadInViewMode() {
    const url = new URL(window.location);

    url.searchParams.delete('mode');
    url.searchParams.append('mode', 'view');

    window.location = url;
  }

  /**
   * Be prepared for this to break if/when Qrvey changes their markup
   *
   * @return {bool} whether we found the button
   **/
  function findQrveyPublishButton() {
    return document.querySelector('qpb-root')?.shadowRoot?.querySelector('.qpb-publish-page-container');
  }

  React.useEffect(() => {
    const interval = setInterval(() => {
      const buttonElement = findQrveyPublishButton();

      if (buttonElement) {
        const buttonText = buttonElement.getElementsByTagName('qui-button')[0].shadowRoot.querySelector('qui-truncate-text').shadowRoot.querySelector('li').innerText;

        if (buttonText === 'Publish Dashboard') {
          buttonElement.addEventListener('click', reloadInViewMode);
          clearInterval(interval);
        }
      }
    }, 100);

    return () => clearInterval(interval);
  }, []);

  return (
    <AuthenticityTokenContext.Provider value={authenticityToken}>
      <div className={`survey-list-sidebar qrvey-sidebar ${expansionClass}`}>
        <div
          className={`sidebar-tab ${expansionClass} left-side`}
          onClick={() => {
            setSidebarPanelExpanded(!sidebarPanelExpanded);
          }}
        >
          <img
            className="folding-arrow-icon"
            src={sidebarPanelExpanded ? CollapseSidebarIcon : ExpandSidebarIcon}>
          </img>
        </div>

        <div className='sidebar-body'>
          <ul className='sidebar-list'>
            <BuiltInDashboards />
            {
              props.usingHardcodedDefaults ?
                <>
                  <SharedDashboards />
                  <MyDashboards />
                </> : null
            }
          </ul>
          {
            props.usingHardcodedDefaults ?
              <>
                <button
                  type='button'
                  className='pi-secondary-button new-dashboard-button'
                  onClick={openNewDashboardDialog}
                >
                  <img className='button-icon' src={AddIcon} />
                  <span>New Report</span>
                </button>
                <NewDashboardModal />
              </> : null
          }
        </div>
      </div>
    </AuthenticityTokenContext.Provider>
  );
}

export default QrveySidebar;
