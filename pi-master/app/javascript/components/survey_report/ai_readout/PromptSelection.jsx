import React from 'react';
import PropTypes from 'prop-types';
import OptionsForSelect from '../../OptionsForSelect';

const PromptSelection = ({selectedPromptVersion, handlePromptVersionChange, promptTemplates, isLoading}) => (
  <div className="prompt-selection">
    <label htmlFor="prompt-version">Prompt Version:</label>
    <select
      id="prompt-version"
      value={selectedPromptVersion}
      onChange={(e) => handlePromptVersionChange(e.target.value)}
      disabled={isLoading}
    >
      <option value="">Select a prompt version</option>
      <OptionsForSelect
        options={
          promptTemplates.map((template) => {
            return {
              label: template.name,
              value: template.id,
            };
          })
        }
      />
    </select>
  </div>
);

PromptSelection.propTypes = {
  selectedPromptVersion: PropTypes.string,
  handlePromptVersionChange: PropTypes.func.isRequired,
  promptTemplates: PropTypes.array.isRequired,
  isLoading: PropTypes.bool.isRequired,
};

export default PromptSelection;
