import React from 'react';

import CompletionUrlField from './CompletionUrlField';

const CompletionUrlSection = (props) => {
  const [completionUrls, setCompletionUrls] = React.useState([]);

  /**
   * Remove the specified completionUrl from the list
   * @param { string } completionUrl - The URL to remove from the list
   */
  function removeCompletionUrl(completionUrl) {
    const indexOfUrl = completionUrls.indexOf(completionUrl);

    completionUrls.splice(indexOfUrl, 1);
    setCompletionUrls([...completionUrls]);
  }

  /**
   * Add a new completion URL to the list
   */
  function addCompletionUrl() {
    if (completionUrls.some((url) => url.trim().length === 0)) {
      // there's a blank one out there,
      // let them fill that in before adding more
    } else {
      setCompletionUrls([...completionUrls, '']);
    }
  }

  /**
   * Modifies an existing completionUrl
   * @param { string } oldUrl - The URL to replace
   * @param { string } newUrl - The new URL value
   * @param { HTMLInputElement } field - The new URL value
   */
  function updateCompletionUrl(oldUrl, newUrl, field) {
    // These will be identical if the url was not changed.
    if (oldUrl === newUrl) {
      return;
    }

    if (completionUrls.indexOf(newUrl) !== -1) {
      field.setCustomValidity('No duplicates, please');
      field.reportValidity();
      return;
    }

    const indexOfUrl = completionUrls.indexOf(oldUrl);

    completionUrls.splice(indexOfUrl, 1, newUrl);

    setCompletionUrls([...completionUrls]);
  }

  return (
    <>
      <h2>Completion Urls:</h2>
      <ul className='completion-url-section'>
        {
          completionUrls.map((completionUrl) => {
            return (
              <li className='completion-url-container' key={completionUrl}>
                <CompletionUrlField
                  completionUrl={completionUrl}
                  removeCompletionUrl={
                    (completionUrl) => {
                      removeCompletionUrl(completionUrl);
                    }
                  }
                  updateCompletionUrl={
                    (oldUrl, newUrl, field) => {
                      updateCompletionUrl(oldUrl, newUrl, field);
                    }
                  }
                />
              </li>
            );
          })
        }
      </ul>
      <button
        type='button'
        onClick={addCompletionUrl}
      >
        Add new
      </button>
    </>
  );
};

export default CompletionUrlSection;
