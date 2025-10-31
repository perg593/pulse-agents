import React from 'react';
import PropTypes from 'prop-types';

import {ErrorBoundary} from 'react-error-boundary';
import {DragDropContext, Droppable, Draggable} from '@hello-pangea/dnd';

import ErrorFallback from '../ErrorFallback';
import QrveyDashboardMapping from './QrveyDashboardMapping';

QrveyDashboardMappingWrapper.propTypes = {
  authenticityToken: PropTypes.string.isRequired,
  qrveyDashboardMappings: PropTypes.array.isRequired,
  // id, qrveyName, piName, position
};

/**
 * A wrapper component for the qrvey dashboard mapping page's content
 * @param { Object } props -- see PropTypes
 * @return { JSX.Element }
*/
function QrveyDashboardMappingWrapper(props) {
  const [qrveyDashboardMappings, setQrveyDashboardMappings] = React.useState(props.qrveyDashboardMappings);

  /**
   * Creates a QrveyDashboardMapping record on the server using a form
   *
   * @param { event } e - a form submission event
   **/
  function createDashboardMapping(e) {
    e.preventDefault();

    const form = $(e.target);
    const data = form.serialize();

    $.ajax({
      url: form.attr('action'),
      data: data,
      type: form.attr('method'),
    }).done(function(responseData) {
      console.debug('responseData', responseData);

      setQrveyDashboardMappings([...qrveyDashboardMappings, responseData.qrveyDashboardMapping]);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed', jqXHR, textStatus, errorThrown);
    });
  }

  /**
   * Deletes a QrveyDashboardMapping record on the server.
   * Repositions (defragments) remaining dashboard mapping records on the server.
   *
   * @param { number } qrveyDashboardMappingId - the ID of the record to delete
   **/
  function deleteDashboardMapping(qrveyDashboardMappingId) {
    $.ajax({
      url: `/admin/qrvey_dashboard_mappings/${qrveyDashboardMappingId}`,
      method: 'DELETE',
    }).done(function(responseData) {
      setQrveyDashboardMappings(responseData.qrveyDashboardMappings);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed', jqXHR, textStatus, errorThrown);
    });
  }

  /**
   * Updates a QrveyDashboardMapping record on the server.
   *
   * @param { number } qrveyDashboardMappingId - the ID of the record to update
   * @param { Object } newDashboardMappingAttributes - an object with the values to update
   *   {columnName: value}
   **/
  function updateDashboardMapping(qrveyDashboardMappingId, newDashboardMappingAttributes) {
    $.ajax({
      url: `/admin/qrvey_dashboard_mappings/${qrveyDashboardMappingId}`,
      data: {qrvey_dashboard_mapping: newDashboardMappingAttributes},
      method: 'PATCH',
    }).done(function(responseData) {
      console.debug('responseData', responseData);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed', jqXHR, textStatus, errorThrown);
    });
  }

  /**
   * Updates a QrveyDashboardMapping's position on the server. The backend will update
   *   other dashboard mapping positions to fit.
   *
   * @param { number } qrveyDashboardMappingId - the ID of the record to update
   * @param { number } newPosition - the dashboard mapping's new position
   **/
  function updateDashboardMappingPosition(qrveyDashboardMappingId, newPosition) {
    $.ajax({
      url: `/admin/qrvey_dashboard_mappings/${qrveyDashboardMappingId}/change_position`,
      data: {new_position: newPosition},
      method: 'POST',
    }).done(function(responseData) {
      console.debug('responseData', responseData);

      setQrveyDashboardMappings([...responseData.qrveyDashboardMappings]);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed', jqXHR, textStatus, errorThrown);
    });
  }

  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
    >
      <h1>Qrvey Dashboard Mappings</h1>
      <form
        action='/admin/qrvey_dashboard_mappings'
        method='POST'
        onSubmit={(e) => createDashboardMapping(e)}
        className='new-entry-container'
      >
        <input
          type='hidden'
          name='authenticity_token'
          value={props.authenticityToken}
        />
        <input
          type='hidden'
          name='qrvey_dashboard_mapping[position]'
          value={qrveyDashboardMappings.length + 1}
        />
        <input
          name='qrvey_dashboard_mapping[qrvey_name]'
          placeholder='Qrvey dashboard mapping name'
          required='required'
        />
        <input
          name='qrvey_dashboard_mapping[pi_name]'
          placeholder='User friendly dashboard mapping name'
          required='required'
        />
        <button
          className='btn btn-default create-survey-button'
          type='submit'
        >
          Create Dashboard Mapping Entry
        </button>
      </form>

      <DragDropContext
        onDragEnd={(dragUpdateObj) => {
          if (dragUpdateObj.reason === 'DROP') {
            const sourceIndex = dragUpdateObj.source.index;
            const destinationIndex = dragUpdateObj.destination &&
              dragUpdateObj.destination.index;

            if (typeof sourceIndex === 'number' && typeof destinationIndex === 'number' && sourceIndex != destinationIndex) {
              updateDashboardMappingPosition(qrveyDashboardMappings[sourceIndex].id, destinationIndex + 1);
            }
          }
        }}
      >
        <table className='dashboards-table'>
          <thead>
            <tr>
              <th>Qrvey dashboard mapping name</th>
              <th>Friendly name for console</th>
            </tr>
          </thead>
          <Droppable droppableId="table">
            {(droppableProvided) => (
              <tbody
                ref={(ref) => {
                  droppableProvided.innerRef(ref);
                }}
                {...droppableProvided.droppableProps}
              >
                {
                  qrveyDashboardMappings.map((qrveyDashboardMapping, qrveyDashboardMappingIndex) => {
                    return (
                      <Draggable
                        draggableId={qrveyDashboardMapping.id.toString()}
                        index={qrveyDashboardMappingIndex}
                        key={qrveyDashboardMapping.id.toString()}
                      >
                        {(provided, snapshot) => (
                          <tr
                            key={qrveyDashboardMapping.id}
                            ref={provided.innerRef}
                            {...provided.draggableProps}
                            {...provided.dragHandleProps}
                          >
                            <QrveyDashboardMapping
                              deleteDashboardMapping={(qrveyDashboardMappingId) => {
                                deleteDashboardMapping(qrveyDashboardMappingId);
                              }}
                              updateDashboardMapping={(qrveyDashboardMappingId, newVals) => {
                                updateDashboardMapping(qrveyDashboardMappingId, newVals);
                              }}
                              {...qrveyDashboardMapping}
                            />
                          </tr>
                        )}
                      </Draggable>
                    );
                  })
                }
                {droppableProvided.placeholder}
              </tbody>
            )}
          </Droppable>
        </table>
      </DragDropContext>
    </ErrorBoundary>
  );
}

export default QrveyDashboardMappingWrapper;
