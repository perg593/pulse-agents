import React from 'react';

import PanelTemplate from '../scheduled_reports/PanelTemplate.jsx';
import OptionsForSelect from '../OptionsForSelect';

interface TagJSSettingsPanelProps {
  authenticityToken: string
  accountId: number
  tagJsVersion: string
  tagJsVersionOptions: [
    {
      label: string
      value: string
    }
  ]
};

/**
 * @param { TagJSSettingsPanelProps } props
 * @return { JSX.Element }
 **/
function TagJSSettingsPanel(props: TagJSSettingsPanelProps) {
  const [tagJsVersion, setTagJsVersion] = React.useState(props.tagJsVersion);

  /**
   * @param { string } tagJsVersion
   * @return { string } description of this tag JS version
   **/
  function tagJsDescription(tagJsVersion: string) {
    switch (tagJsVersion) {
      case '1.0.0':
        return "The original. Not recommended for new accounts. Only upgrade if it's causing problems";
      case '1.0.1':
        return "Incompatible with Google Tag Manager. Only upgrade if it's causing problems.";
      case '1.0.2':
        return 'The default for new accounts. Fully compatible with Google Tag Manager.';
    }

    return `Unrecognized tag JS version ${tagJsVersion}`;
  }

  return (
    <PanelTemplate title='Code Snippet Version'>
      <form
        action={`/admin/accounts/${props.accountId}`}
        method='POST'
      >
        <div className='settings-row'>
          <div className='settings-container'>
            <input
              type='hidden'
              name='authenticity_token'
              value={props.authenticityToken}
            />
            <input type='hidden' name='_method' value='patch' />

            <select
              name='account[tag_js_version]'
              value={tagJsVersion}
              onChange={(e) => {
                setTagJsVersion(e.target.value);
              }}
            >
              <OptionsForSelect options={props.tagJsVersionOptions} />
            </select>

            <p className='settings-description'>
              { tagJsDescription(tagJsVersion) }
            </p>
          </div>

          <div className='button-container'>
            <button
              className='pi-primary-button'
              type='submit'
            >
              Update
            </button>
          </div>
        </div>
      </form>
    </PanelTemplate>
  );
};

export default TagJSSettingsPanel;
