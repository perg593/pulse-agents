import React from 'react';
import PropTypes from 'prop-types';

import {
  contextMenu as reactContexifyContextMenu,
  Item,
  Menu,
  Separator,
} from 'react-contexify';

import 'react-contexify/ReactContexify.css';

import HoverEllipses from '../../../images/survey_dashboard/three_dots.svg';
import AuthenticityTokenContext from './AuthenticityTokenContext';

ContextMenu.propTypes = {
  id: PropTypes.string.isRequired,
  dashboardId: PropTypes.string,

  canDelete: PropTypes.bool,
  deleteDashboardLink: PropTypes.func,

  canShare: PropTypes.bool,
  showShareModal: PropTypes.func,

  canCopy: PropTypes.bool,
  showCopyModal: PropTypes.func,

  canEdit: PropTypes.bool,
  editModeUrl: PropTypes.string,
};

/**
 * The context menu available to (most) sidebar items
 * @param { Object } props
 * @return { ContextMenu }
 **/
function ContextMenu(props) {
  const authenticityToken = React.useContext(AuthenticityTokenContext);

  /**
   * Deletes a dashboard. Reloads the page if successful
   * TODO: Don't require page reload
   * @param {string} dashboardId - The ID of the dashboard on Qrvey
   **/
  function deleteDashboard(dashboardId) {
    fetch(
        `/qrvey/delete_dashboard?qrvey_dashboard_id=${props.dashboardId}&authenticity_token=${authenticityToken}`,
        {
          method: 'DELETE',
          headers: {
            'Accept': 'application/json',
          },
        },
    ).then((response) => {
      if (response.ok) {
        console.debug("Yay! Deleted");
        props.deleteDashboardLink(dashboardId);
      } else {
        console.debug("Something went wrong", response);
      }
    }).catch((response) => {
      console.debug(response);
    });
  }

  /**
   * Visit this dashboard in edit mode
   */
  function visitEditPage() {
    window.location = props.editModeUrl;
  }

  return (
    <Menu id={props.id}>
      {
        props.canCopy ?
          <Item onClick={props.showCopyModal}>
            Copy
          </Item> : null
      }
      {
        props.canEdit ?
          <Item onClick={visitEditPage}>
            Edit
          </Item> : null
      }
      {
        props.canShare ?
          <Item onClick={props.showShareModal}>
            Share
          </Item> : null
      }
      {
        props.canDelete ?
          <>
            <Separator />
            <Item
              className='dangerous-option'
              onClick={(e) => {
                if (window.confirm('Delete the dashboard?')) {
                  deleteDashboard(props.dashboardId);
                }
              }}
            >
              Delete
            </Item>
          </> : null
      }
    </Menu>
  );
}

ContextMenuTrigger.propTypes = {
  render: PropTypes.bool.isRequired,
  contextMenuId: PropTypes.string.isRequired,
};

/**
 * A control to activate a context menu
 *
 * @param { Object } props
 * @return { ContextMenuTrigger }
 **/
function ContextMenuTrigger(props) {
  if (!props.render) {
    return null;
  }

  return (
    <>
      <button
        onClick={(e) => {
          reactContexifyContextMenu.show({id: props.contextMenuId, event: e});
        }}
        className='icon-button'
        title='Dashboard Menu'
        style={{
          maskImage: `url(${HoverEllipses})`,
          WebkitMaskImage: `url(${HoverEllipses})`,
        }}
      >
      </button>
    </>
  );
};

ContextMenuContainer.propTypes = {
  dashboardId: PropTypes.string,
  dashboardName: PropTypes.string.isRequired,

  renderContextMenuTrigger: PropTypes.bool.isRequired,
  deleteDashboardLink: PropTypes.func,
  canDelete: PropTypes.bool,
  canShare: PropTypes.bool,
  canCopy: PropTypes.bool,
  canEdit: PropTypes.bool,
  showCopyModal: PropTypes.func,
  showShareModal: PropTypes.func,
};

/**
 * A container for the context menu and its trigger
 * @param { Object } props
 * @return {ContextMenuContainer}
 **/
function ContextMenuContainer(props) {
  const contextMenuId = `dashboard_context_menu_${props.dashboardName}`;
  const authenticityToken = React.useContext(AuthenticityTokenContext);

  return (
    <>
      <ContextMenuTrigger
        render={props.renderContextMenuTrigger}
        contextMenuId={contextMenuId}
      />
      <ContextMenu
        id={contextMenuId}
        dashboardId={props.dashboardId}
        canDelete={props.canDelete}
        canShare={props.canShare}
        canCopy={props.canCopy}
        deleteDashboardLink={props.deleteDashboardLink}
        showCopyModal={props.showCopyModal}
        showShareModal={props.showShareModal}
        canEdit={props.canEdit}
        editModeUrl={props.editModeUrl}
        authenticityToken={authenticityToken}
      />
    </>
  );
};

export default ContextMenuContainer;
