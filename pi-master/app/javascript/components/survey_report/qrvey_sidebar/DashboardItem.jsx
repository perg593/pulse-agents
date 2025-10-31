import React from 'react';
import PropTypes from 'prop-types';

import Select from 'react-select';
import classNames from 'classnames';

import PiModal from '../../modal_dialog/PiModal';

import OptionsForSelect from '../../OptionsForSelect';
import ContextMenuContainer from './ContextMenuContainer';
import AuthenticityTokenContext from './AuthenticityTokenContext';

import DeleteButton from '../../DeleteButton';

DashboardItem.propTypes = {
  link: PropTypes.object.isRequired,

  shareOptions: PropTypes.array,
  canDelete: PropTypes.bool,
  canShare: PropTypes.bool,
  canCopy: PropTypes.bool,
  canRevokeAccess: PropTypes.bool,
  deleteDashboardLink: PropTypes.func,
  canEdit: PropTypes.bool,
  surveyId: PropTypes.number,
  editModeUrl: PropTypes.string,
};

/**
 * One item (row) on the sidebar list
 * @param { Object } props
 * @return { DashboardItem }
 **/
function DashboardItem(props) {
  const dashboardId = props.link.dashboardId;
  const authenticityToken = React.useContext(AuthenticityTokenContext);

  const copyDashboardDialogRef = React.useRef(null);

  const openCopyDashboardDialog = () => {
    if (copyDashboardDialogRef.current) {
      copyDashboardDialogRef.current.showModal();
    }
  };

  /**
   * A modal dialogue for specifying users to share a report with
   * @return { Modal }
   **/
  function CopyModal() {
    return (
      <PiModal
        ref={copyDashboardDialogRef}
        modalClassName='qrvey-modal'
      >
        <PiModal.Header title={`Copy "${props.link.text}"`} />

        <PiModal.Body>
          <form
            id={`qrvey_dashboard_clone_form_${dashboardId}`}
            action='/qrvey/clone_dashboard'
            method='POST'
            className='qrvey-dashboard-clone-form'
          >
            <input
              type='hidden'
              name='authenticity_token'
              value={authenticityToken}
            />
            <input
              type='hidden'
              name='qrvey_dashboard_id'
              value={dashboardId}
            />
            {
              props.surveyId ?
                <input
                  type='hidden'
                  name='survey_id'
                  value={props.surveyId}
                /> : null
            }
            <label htmlFor='qrvey_dashboard_name'>Name:</label>
            <input
              id='qrvey_dashboard_name'
              name='qrvey_dashboard_name'
              defaultValue={`Copy of ${props.link.text}`}
            />
          </form>
        </PiModal.Body>
        <PiModal.Footer>
          <button
            className='pi-primary-button'
            type='submit'
            form={`qrvey_dashboard_clone_form_${dashboardId}`} // DRY}
          >
            Copy
          </button>
        </PiModal.Footer>
      </PiModal>
    );
  }

  const shareDashboardDialogRef = React.useRef(null);

  const openShareDashboardDialog = () => {
    if (shareDashboardDialogRef.current) {
      shareDashboardDialogRef.current.showModal();
    }
  };

  /**
   * A modal dialogue for specifying users to share a report with
   * @return { Modal }
   **/
  function ShareModal() {
    const [peopleSelected, setPeopleSelected] = React.useState([]);
    const [sharedWith, setSharedWith] = React.useState(() => {
      if (props.shareOptions === undefined) {
        return [];
      } else {
        return props.shareOptions.filter((option) => option.shared);
      }
    });

    const peopleNotSharedWith = () => {
      const selectedUserIds = peopleSelected.map((person) => person.userId);

      return props.shareOptions?.filter((option) => {
        return !selectedUserIds.includes(option.userId) && !option.shared;
      }).map((option) => {
        return {
          label: option.userName,
          value: option.userId,
        };
      });
    };

    const accessLevelOptions = [
      {value: 0, label: 'Read'},
    ];

    if (props.canEdit) {
      accessLevelOptions.push({value: 1, label: 'Edit'});
    }

    const ListOfPeopleContainer = () => {
      /**
       * Mark a user as having no permission to access this report
       * @param { number } userId
       **/
      function markAsRevoked(userId) {
        const newSharedWith = [...sharedWith];
        const userToChange = newSharedWith.find((option) => option.userId == userId);
        userToChange.permissions = '';

        setSharedWith(newSharedWith);
      }

      return (
        <div>
          <input
            type='hidden'
            name='_method'
            value='PUT'
          />
          <input
            type='hidden'
            name='authenticity_token'
            value={authenticityToken}
          />
          <input
            type='hidden'
            name='qrvey_dashboard_id'
            value={dashboardId}
          />
          <table className='access-table'>
            <thead>
              <tr>
                <th>People with access</th>
                <th>Permissions</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {
                sharedWith.map((option, i) => {
                  return (
                    <tr
                      key={option.userId}
                      className={option.permissions === '' ? 'revoked' : ''}
                    >
                      <td>
                        {option.userName}
                        <input
                          type='hidden'
                          name={`users[][id]`}
                          value={option.userId}
                        />
                      </td>
                      <td>
                        {
                          option.permissions !== '' ?
                            <select
                              name={`users[][permissions]`}
                              defaultValue={option.permissions.toString()}
                              onChange={(e) => {
                                const newSharedWith = [...sharedWith];
                                const userToChange = newSharedWith.find((shareOption) => shareOption.userId == option.userId);
                                const newPermission = e.target.value;

                                userToChange.permissions = newPermission;
                                setSharedWith(newSharedWith);
                              }}
                            >
                              <OptionsForSelect options={accessLevelOptions} />
                            </select> : <>
                              <span>removal pending</span>
                              <input
                                type='hidden'
                                name={`users[][permissions]`}
                                value=""
                              />
                            </>
                        }
                      </td>
                      <td>
                        {
                          props.canRevokeAccess && option.permissions !== '' ?
                            <DeleteButton
                              onClick={(e) => markAsRevoked(option.userId)}
                            /> : null
                        }
                      </td>
                    </tr>
                  );
                })
              }
            </tbody>
          </table>
        </div>
      );
    };

    const cancelShare = () => {
      setPeopleSelected([]);
    };

    const closeShareDialog = () => {
      if (shareDashboardDialogRef.current) {
        shareDashboardDialogRef.current.close();
      }
    };

    const ShareIndexPanel = () => {
      return (
        <>
          <PiModal.Body>
            <form
              id={`qrvey_dashboard_share_form_${dashboardId}`}
              action='/qrvey/change_dashboard_permissions'
              method='POST'
            >
              <Select
                maxMenuHeight={100}
                isMulti
                options={peopleNotSharedWith()}
                className='basic-multi-select tag-selector'
                onChange={(selectedPeople) => {
                  setPeopleSelected(selectedPeople);
                }}
                value={peopleSelected}
                placeholder='Add people'
                name='user_ids_to_share_with[]'
              />
              <input
                type='hidden'
                name='_method'
                value='PUT'
              />
              <input
                type='hidden'
                name='authenticity_token'
                value={authenticityToken}
              />
              <input
                type='hidden'
                name='qrvey_dashboard_id'
                value={dashboardId}
              />
              {
                sharedWith.length > 0 ?
                  <ListOfPeopleContainer /> : null
              }
            </form>
          </PiModal.Body>
          <PiModal.Footer>
            <div className='actions-container'>
              <button
                className='pi-primary-button'
                type='submit'
                form={`qrvey_dashboard_share_form_${dashboardId}`}
              >
                Save
              </button>
              <button
                type='button'
                className='pi-secondary-button'
                onClick={closeShareDialog}
              >
                Cancel
              </button>
            </div>
          </PiModal.Footer>
        </>
      );
    };

    const ShareWithManyPanel = () => {
      return (
        <>
          <PiModal.Body>
            <form
              id={`qrvey_dashboard_share_form_${dashboardId}`}
              action='/qrvey/share_dashboard'
              method='POST'
            >
              <div className='user-selection-container'>
                <Select
                  maxMenuHeight={100}
                  isMulti
                  options={peopleNotSharedWith()}
                  className='basic-multi-select user-selector'
                  onChange={(selectedPeople) => {
                    setPeopleSelected(selectedPeople);
                  }}
                  value={peopleSelected}
                  placeholder='Add people'
                  name='user_ids_to_share_with[]'
                />
                <input
                  type='hidden'
                  name='_method'
                  value='PUT'
                />
                <input
                  type='hidden'
                  name='authenticity_token'
                  value={authenticityToken}
                />
                <input
                  type='hidden'
                  name='qrvey_dashboard_id'
                  value={dashboardId}
                />
                <select name='permissions'>
                  <OptionsForSelect options={accessLevelOptions} />
                </select>
              </div>
            </form>
          </PiModal.Body>
          <PiModal.Footer>
            <div className='actions-container'>
              <button
                className='pi-primary-button'
                type='submit'
                form={`qrvey_dashboard_share_form_${dashboardId}`}
              >
                Share
              </button>
              <button
                className='pi-secondary-button'
                onClick={() => cancelShare()}
              >
                Cancel
              </button>
            </div>
          </PiModal.Footer>
        </>
      );
    };

    return (
      <PiModal
        ref={shareDashboardDialogRef}
        modalClassName='qrvey-modal'
      >
        <PiModal.Header title={`Share "${props.link.text}"`} />
        {
          peopleSelected.length === 0 ?
            <ShareIndexPanel /> :
            <ShareWithManyPanel />
        }
      </PiModal>
    );
  };

  /**
   * The content (body?) of the list item
   * @return { JSX.Element }
   **/
  function Contents() {
    const [renderContextMenuTrigger, setRenderContextMenuTrigger] = React.useState(false);

    const labelLengthLimit = 20;
    const trimmedLinkText = props.link.text.length > labelLengthLimit ?
      `${props.link.text.substring(0, labelLengthLimit)}...` :
      props.link.text;

    return (
      <div
        className='dashboard-item-container'
        onMouseEnter={() => setRenderContextMenuTrigger(true)}
        onMouseLeave={() => setRenderContextMenuTrigger(false)}
      >
        <a
          className='qrvey-dashboard-link'
          href={props.link.url}
          title={props.link.text}
        >
          {trimmedLinkText}
        </a>
        {
          (props.canCopy || props.canDelete || props.canShare) ?
            <ContextMenuContainer
              dashboardId={dashboardId}
              dashboardName={props.link.text}
              renderContextMenuTrigger={renderContextMenuTrigger}
              canDelete={props.canDelete}
              canShare={props.canShare}
              canCopy={props.canCopy}
              deleteDashboardLink={props.deleteDashboardLink}
              showCopyModal={openCopyDashboardDialog}
              showShareModal={openShareDashboardDialog}
              canEdit={props.canEdit}
              editModeUrl={props.editModeUrl}
            /> : null
        }
      </div>
    );
  }

  const listItemClassName = classNames(
      'qrvey-list-item',
      {current: props.link.current},
      props.link.additionalClasses,
  );

  return (
    <li
      className={listItemClassName}
      key={props.link.text}
    >
      <Contents />
      <CopyModal />
      <ShareModal />
    </li>
  );
};

export default DashboardItem;
