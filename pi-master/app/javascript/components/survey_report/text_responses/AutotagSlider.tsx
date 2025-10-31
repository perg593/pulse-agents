import React from 'react';

import ToggleSwitch from '../../ToggleSwitch';

interface AutotagSliderProps {
  autotagEnabled: boolean
  questionId: number
};

/**
 * A GUI for toggling a question's autotagging.
 *
 * @param {AutotagSliderProps} props - see interface above
 * @return {JSX.Element}
 **/
function AutotagSlider(props: AutotagSliderProps) {
  const [autotagEnabled, setAutotagEnabled] = React.useState(props.autotagEnabled);

  /**
   * Updates the question's autotagging setting on the server
   *
   * @param {boolean} active - The new autotag setting
   **/
  function toggleAutotag(active: boolean) {
    $.ajax({
      url: `/questions/${props.questionId}/toggle_tag_automation_worker`,
      method: 'PATCH',
      data: {
        question: {
          tag_automation_worker_enabled: active,
        },
      },
    }).done(function(responseData) {
      console.debug('We did it!');
      setAutotagEnabled(active);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to update! D:', jqXHR, textStatus, errorThrown);
    });
  }

  return (
    <div className='autotag-container'>
      <ToggleSwitch
        defaultChecked={autotagEnabled}
        onChange={(e) => toggleAutotag(e.target.checked)}
      />
      <span>AutoTag Refresh {autotagEnabled ? 'ON' : 'OFF'}</span>
    </div>
  );
}

export default AutotagSlider;
