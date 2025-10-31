import React from 'react';
import PropTypes from 'prop-types';

import PanelTemplate from './PanelTemplate.jsx';

const UnregisteredEmailOptionsList = (props) => {
  return (
    props.newEmailOptions.map((newEmailOption, i) => {
      const emailIndex = props.numRegisteredOptions + i;
      const attributeContext = `scheduled_report[scheduled_report_emails_attributes][${emailIndex}][email]`;

      return (
        <li key={newEmailOption}>
          <input
            type='email'
            name={attributeContext}
            defaultValue={newEmailOption}
            placeholder='Enter an e-mail address'
            onBlur={(e) => {
              const updatedEmailOptions = [...props.newEmailOptions];
              updatedEmailOptions[i] = e.target.value;
              props.setNewEmailOptions(updatedEmailOptions);
            }}
            required
          />
          <button
            type='button'
            className='close'
            onClick={() => {
              props.newEmailOptions.splice(i, 1);
              props.setNewEmailOptions([...props.newEmailOptions]);
            }}
          >
            ×
          </button>
        </li>
      );
    })
  );
};

UnregisteredEmailOptionsList.propTypes = {
  newEmailOptions: PropTypes.array.isRequired,
  setNewEmailOptions: PropTypes.func.isRequired,
  numRegisteredOptions: PropTypes.number.isRequired,
};

const EmailOption = (props) => {
  const id = `scheduled_report_email_address_${props.emailOption.label.replaceAll(/[@,.]/g, '_')}`;
  const attributeContext = `scheduled_report[scheduled_report_emails_attributes][${props.emailOptionIndex}]`;

  const renderHiddenEmailFields = () => {
    if (!props.emailOption.id) {
      return null;
    }

    const shouldDestroy = !props.emailOption.checked;

    return (
      <>
        <input
          type="hidden"
          name={`${attributeContext}[id]`}
          value={props.emailOption.id}
        />

        {
          shouldDestroy ?
            <input
              type="hidden"
              name={`${attributeContext}[_destroy]`}
              value='1'
            />: null
        }
      </>
    );
  };

  return (
    <li key={props.emailOption.label}>
      { renderHiddenEmailFields() }

      <input
        id={id}
        type="checkbox"
        name={`${attributeContext}[email]`}
        value={props.emailOption.email}
        checked={props.emailOption.checked}
        onChange={(e) => {
          const newObject = {
            ...props.emailOption,
            checked: e.target.checked,
          };
          props.updateEmailOptionAtIndex(props.emailOptionIndex, newObject);
        }}
      />

      <label htmlFor={id}>
        {props.emailOption.label}
      </label>
    </li>
  );
};

EmailOption.propTypes = {
  emailOption: PropTypes.object.isRequired,
  emailOptionIndex: PropTypes.number.isRequired,
  updateEmailOptionAtIndex: PropTypes.func.isRequired,
};

const EmailOptionsList = (props) => {
  const [emailOptions, setEmailOptions] = React.useState(props.emailOptions);

  /**
   * Update the email option at the specified index
   * @param {number} index
   * @param {object} newObject - the new e-mail option
   */
  function updateEmailOptionAtIndex(index, newObject) {
    const updatedEmailOptions = [...emailOptions];
    updatedEmailOptions[index] = newObject;
    setEmailOptions(updatedEmailOptions);
  }

  return (
    <>
      <li>
        <input
          id='select_all_emails'
          type="checkbox"
          onChange={(e) => {
            const updatedEmailOptions = emailOptions.map((emailOption) => {
              return {
                ...emailOption,
                checked: e.target.checked,
              };
            });
            setEmailOptions(updatedEmailOptions);
          }}
          checked={emailOptions.every((emailOption) => emailOption.checked)}
        />

        <label htmlFor='select_all_emails'>
          All
        </label>
      </li>

      {
        emailOptions.map((emailOption, i) => {
          return <EmailOption
            key={emailOption.label}
            emailOption={emailOption}
            emailOptionIndex={i}
            updateEmailOptionAtIndex={updateEmailOptionAtIndex}
          />;
        })
      }
    </>
  );
};

EmailOptionsList.propTypes = {
  emailOptions: PropTypes.array.isRequired, // see ScheduledReportPresenter
};

const RecipientsPanel = (props) => {
  const [newEmailOptions, setNewEmailOptions] = React.useState([]);

  return (
    <PanelTemplate title='Recipients'>
      <ul className='email-list'>
        <EmailOptionsList emailOptions={props.emailOptions} />
        <UnregisteredEmailOptionsList
          newEmailOptions={newEmailOptions}
          setNewEmailOptions={setNewEmailOptions}
          numRegisteredOptions={props.emailOptions.length}
        />
      </ul>

      <button
        type='button'
        className='btn btn-xs btn-default'
        onClick={() => {
          if (newEmailOptions.some((emailOption) => emailOption.trim().length === 0)) {
            // there's a blank one out there,
            // let them fill that in before adding more
          } else {
            setNewEmailOptions([...newEmailOptions, '']);
          }
        }}
      >
        New Email
      </button>
    </PanelTemplate>
  );
};

RecipientsPanel.propTypes = {
  emailOptions: PropTypes.array.isRequired, // see ScheduledReportPresenter
};

export default RecipientsPanel;
