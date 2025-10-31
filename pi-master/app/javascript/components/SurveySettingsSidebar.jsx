import React from 'react';
import PropTypes from 'prop-types';

import DisabledFeaturesContext from './survey_editor/DisabledFeaturesContext';

import ExpandSidebarIcon from '../images/survey_dashboard/expand.svg';
import CollapseSidebarIcon from '../images/survey_dashboard/collapse.svg';

import TargetingOptions from './survey_edit_sidebar/TargetingOptions.jsx';
import GeneralOptions from './survey_edit_sidebar/GeneralOptions';
import FormattingOptions from './survey_edit_sidebar/FormattingOptions';

import NewQuestionPanel from './survey_edit_sidebar/NewQuestionPanel';
import SidebarTab from './survey_edit_sidebar/SidebarTab';

SurveySettingsSidebar.propTypes = {
  surveyId: PropTypes.number.isRequired,
  surveyTags: PropTypes.array,
  surveyGeneralOptions: PropTypes.object.isRequired,
  surveyFormattingOptions: PropTypes.object.isRequired,
  surveyTargetingOptions: PropTypes.object.isRequired,
  storedOpenTabName: PropTypes.string,
  addQuestionHandler: PropTypes.func.isRequired,
  addInvitationHandler: PropTypes.func.isRequired,
  includeInvitation: PropTypes.func.isRequired,
  htmlAttributeMap: PropTypes.object.isRequired,
  authenticityToken: PropTypes.string.isRequired,
};

/**
 * A wrapper component for the survey edit page's right survey settings sidebar
 * @param { Object } props
 * @return { SurveySettingsSidebar }
*/
function SurveySettingsSidebar(props) {
  const [panelExpansionSettings, setPanelExpansionSettings] = React.useState({});

  const updatePanelExpansionSettings = (panelSetting) => {
    setPanelExpansionSettings({
      ...panelExpansionSettings,
      ...panelSetting,
    });
  };

  const [sidebarPanelExpanded, setSidebarPanelExpanded] = React.useState(true);
  // [general, targeting, formatting]
  const [openTabName, setOpenTabName] = React.useState(
      props.storedOpenTabName || 'general',
  );

  // GeneralOptions
  const [tagSelections, setTagSelections] = React.useState(
      props.surveyTags.filter((surveyTag) => {
        return surveyTag.value.appliedSurveyTagId !== null;
      }),
  );

  // FormattingOptions
  const [formattingOptions, setFormattingOptions] = React.useState(
      {
        displayAllQuestions: props.surveyFormattingOptions.displayAllQuestions ? 'true' : 'false',
        allAtOnceEmptyErrorEnabled: props.surveyFormattingOptions.allAtOnceEmptyErrorEnabled,
        allAtOnceSubmitLabel: props.surveyFormattingOptions.allAtOnceSubmitLabel || 'Submit',
        allAtOnceErrorText: props.surveyFormattingOptions.allAtOnceErrorText || 'Please fill answers',
        randomizeQuestionOrder: props.surveyFormattingOptions.randomizeQuestionOrder,
        surveyType: props.surveyFormattingOptions.surveyType,
        fullscreenMargin: props.surveyFormattingOptions.fullscreenMargin || '',
        sdkWidgetHeight: props.surveyFormattingOptions.sdkWidgetHeight || '',
        pusherEnabled: props.surveyFormattingOptions.pusherEnabled,
        inlineTargetSelector: props.surveyFormattingOptions.inlineTargetSelector,
        mobileInlineTargetSelector: props.surveyFormattingOptions.mobileInlineTargetSelector,
        sdkInlineTargetSelector: props.surveyFormattingOptions.sdkInlineTargetSelector,
        themeId: props.surveyFormattingOptions.themeId || '',
        sdkThemeId: props.surveyFormattingOptions.sdkThemeId || '',
        availableCssThemes: props.surveyFormattingOptions.availableCssThemes,
        availableSdkThemes: props.surveyFormattingOptions.availableSdkThemes,
        customCss: props.surveyFormattingOptions.customCss,
        positionType: props.surveyFormattingOptions.positionType || 'right_position',
        positionContent: props.surveyFormattingOptions.positionContent || '0px',
        inlineTargetPosition: props.surveyFormattingOptions.inlineTargetPosition,
      }
  );

  // GeneralOptions
  const [generalOptions, setGeneralOptions] = React.useState(
      {
        auditLog: props.surveyGeneralOptions.auditLog,
        surveyBriefJob: props.surveyGeneralOptions.surveyBriefJob,
        surveyBriefEnabled: props.surveyGeneralOptions.surveyBriefEnabled,
        authenticityToken: props.authenticityToken,
        surveyOverviewDocument: props.surveyGeneralOptions.surveyOverviewDocument,
      },
  );

  // TargetingOptions
  const [targetingOptions, setTargetingOptions] = React.useState(
      {
        sampleRate: props.surveyTargetingOptions.sampleRate,
        desktopEnabled: props.surveyTargetingOptions.desktopEnabled,
        tabletEnabled: props.surveyTargetingOptions.tabletEnabled,
        mobileEnabled: props.surveyTargetingOptions.mobileEnabled,
        iosEnabled: props.surveyTargetingOptions.iosEnabled,
        androidEnabled: props.surveyTargetingOptions.androidEnabled,
        emailEnabled: props.surveyTargetingOptions.emailEnabled,
        triggers: props.surveyTargetingOptions.triggers,
        suppressers: props.surveyTargetingOptions.suppressers,
        startsAt: props.surveyTargetingOptions.startsAt ? new Date(props.surveyTargetingOptions.startsAt) : null,
        endsAt: props.surveyTargetingOptions.endsAt ? new Date(props.surveyTargetingOptions.endsAt) : null,

        triggerOptions: props.surveyTargetingOptions.triggerOptions,
        answerTriggerOptions: props.surveyTargetingOptions.answerTriggerOptions,

        answerTrigger: props.surveyTargetingOptions.answerTrigger,
        pageAfterSecondsTrigger: props.surveyTargetingOptions.pageAfterSecondsTrigger,
        pageScrollTrigger: props.surveyTargetingOptions.pageScrollTrigger,
        pageIntentExitTrigger: props.surveyTargetingOptions.pageIntentExitTrigger,
        pageElementClickedTrigger: props.surveyTargetingOptions.pageElementClickedTrigger,
        pageElementVisibleTrigger: props.surveyTargetingOptions.pageElementVisibleTrigger,
        textOnPageTrigger: props.surveyTargetingOptions.textOnPageTrigger,

        stopShowingWithoutAnswer: props.surveyTargetingOptions.stopShowingWithoutAnswer,
        ignoreFrequencyCap: props.surveyTargetingOptions.ignoreFrequencyCap,
        refireEnabled: props.surveyTargetingOptions.refireEnabled,
        refireTime: props.surveyTargetingOptions.refireTime,
        refireTimePeriod: props.surveyTargetingOptions.refireTimePeriod || 'minutes',

        refireTimePeriodOptions: props.surveyTargetingOptions.refireTimePeriodOptions,
        goal: props.surveyTargetingOptions.goal,

        geoipTriggers: props.surveyTargetingOptions.geoipTriggers,
        geoipTriggerOptions: props.surveyTargetingOptions.geoipTriggerOptions,

        clientKeyTrigger: props.surveyTargetingOptions.clientKeyTrigger,
        deviceTriggers: props.surveyTargetingOptions.deviceTriggers,

        deviceTriggerMatcherOptions: props.surveyTargetingOptions.deviceTriggerMatcherOptions,

        pageviewTrigger: props.surveyTargetingOptions.pageviewTrigger,

        visitTrigger: props.surveyTargetingOptions.visitTrigger,
        visitTriggerOptions: props.surveyTargetingOptions.visitTriggerOptions,

        mobileInstallTrigger: props.surveyTargetingOptions.mobileInstallTrigger,
        mobileLaunchTrigger: props.surveyTargetingOptions.mobileLaunchTrigger,
      },
  );

  const destructionAttribute = { name: '_destroy', value: '1' };

  /**
   * Tells you whether or not a string is null or empty
   *
   * @param {string} input
   * @return {bool}
   **/
  function stringNullOrEmpty(input) {
    return [null, ''].includes(input);
  }

  const onTabClick = (tabName) => {
    setOpenTabName(tabName);

    const parameterContext = 'openTabName';
    const url = new URL(window.location);

    url.searchParams.delete(parameterContext);

    url.searchParams.append(parameterContext, tabName);

    window.history.pushState({}, '', url);
  };

  /**
   * Builds attribute objects for renderHiddenAttribute
   * @param {object} theObject
   * @param {array} attributes - array of strings
   * @return {array} an array of name-value pairs
   */
  function buildAttributes(theObject, attributes) {
    return attributes.map((attributeName) => {
      return {
        name: props.htmlAttributeMap[attributeName],
        value: theObject[attributeName],
      };
    });
  };

  /**
   * Renders a group of hidden attributes for a given context
   * @param { String } inputContext 'survey[something][else][12][foo]`
   * @param { Array } attributes -- [{ name: 'some_name', value: '42' }...]
   * @return { JSX.Element }
  */
  function renderHiddenAttributes(inputContext, attributes) {
    return attributes.map((attribute) => {
      return renderHiddenAttribute(inputContext, attribute);
    });
  };

  /**
   * Renders a single hidden input field attribute
   * @param { String } inputContext 'survey[something][else][12][foo]`
   * @param { Object } attribute: { name: 'some_name', value: '42' }
   * @return { JSX.Element }
  */
  function renderHiddenAttribute(inputContext, attribute) {
    if (attribute.value === null) {
      return;
    }

    return (
      <input
        type='hidden'
        name={`${inputContext}[${attribute.name}]`}
        value={attribute.value}
        key={`${inputContext}_${attribute.name}`}
      />
    );
  };

  const renderTagSelections = () => {
    return (
      <>
        {
          tagSelections.map((tagSelection, i) => {
            const inputContext = `survey[applied_survey_tags_attributes][${i}]`;

            const attributes = buildAttributes(tagSelection.value, [
              'surveyTagId',
            ]);

            if (tagSelection.value.appliedSurveyTagId) {
              attributes.push(...buildAttributes(tagSelection.value, [
                'appliedSurveyTagId',
              ]));
            }

            return renderHiddenAttributes(inputContext, attributes);
          })
        }

        {
          unappliedSurveyTags().filter((surveyTag) => {
            return surveyTag.value.appliedSurveyTagId;
          }).map((surveyTag, i) => {
            const inputContext = `survey[applied_survey_tags_attributes][${i + tagSelections.length}]`;

            const attributes = buildAttributes(surveyTag.value, [
              'appliedSurveyTagId',
            ]);

            attributes.push(destructionAttribute);

            return renderHiddenAttributes(inputContext, attributes);
          })
        }
      </>
    );
  };

  const unappliedSurveyTags = () => {
    return props.surveyTags.filter((surveyTag) => {
      return !tagSelections.includes(surveyTag);
    });
  };

  const renderHiddenGeneralInputs = () => {
    const inputContext = `survey[last_survey_brief_job_attributes]`;

    const attributes = buildAttributes(generalOptions.surveyBriefJob, [
      'brief',
      'id',
    ]);

    return (
      <>
        { renderTagSelections() }
        { renderHiddenAttributes(inputContext, attributes) }
      </>
    );
  };

  const renderHiddenFormattingInputs = () => {
    // TODO: Consider specifying this in presenter or something,
    // or maybe just convert camelCase to snake_case at runtime
    const attributes = buildAttributes(formattingOptions, [
      'displayAllQuestions',
      'allAtOnceEmptyErrorEnabled',
      'allAtOnceSubmitLabel',
      'allAtOnceErrorText',
      'randomizeQuestionOrder',
      'surveyType',
      'themeId',
      'sdkThemeId',
      'customCss',
    ]);

    switch (formattingOptions.surveyType) {
      case 'docked_widget':
        attributes.push(
            ...buildAttributes(formattingOptions, ['positionType', 'positionContent']),
        );
        break;
      case 'inline':
        attributes.push(
            ...[
              ...buildAttributes(formattingOptions, [
                'inlineTargetSelector',
                'mobileInlineTargetSelector',
                'sdkInlineTargetSelector',
                'inlineTargetPosition',
                'sdkWidgetHeight',
              ]),
            ],
        );
        break;
      case 'top_bar':
        attributes.push(
            ...buildAttributes(formattingOptions, [
              'pusherEnabled',
              'sdkWidgetHeight',
            ]),
        );
        break;
      case 'bottom_bar':
        attributes.push(
            ...buildAttributes(formattingOptions, ['sdkWidgetHeight']),
        );
        break;
      case 'fullscreen':
        attributes.push(
            ...buildAttributes(formattingOptions, ['fullscreenMargin']),
        );
        break;
      default:
        console.debug('Unrecognized survey_type', formattingOptions.surveyType);
    }

    const inputContext = `survey`;

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenTargetingInputs = () => {
    const targetingAttributes = buildAttributes(targetingOptions, [
      'sampleRate',
      'desktopEnabled',
      'tabletEnabled',
      'mobileEnabled',
      'iosEnabled',
      'androidEnabled',
      'emailEnabled',
      'startsAt',
      'endsAt',
      'stopShowingWithoutAnswer',
      'ignoreFrequencyCap',
      'refireEnabled',
      'refireTime',
      'refireTimePeriod',
      'goal',
    ]);

    const inputContext = `survey`;

    return renderHiddenAttributes(inputContext, targetingAttributes);
  };

  const renderHiddenTriggerInputs = () => {
    const inputContext = `survey[triggers_attributes]`;
    const inputs = [];

    targetingOptions.triggers.map((trigger, i) => {
      const triggerAttributes = buildAttributes(trigger, ['id', 'typeCd', 'triggerContent']);

      if (trigger.flaggedForDeletion) {
        triggerAttributes.push(destructionAttribute);
      }

      triggerAttributes.forEach((triggerAttribute) => {
        inputs.push(renderHiddenAttribute(`${inputContext}[${i}]`, triggerAttribute));
      });
    });

    return inputs;
  };

  const renderHiddenSuppresserInputs = () => {
    const inputContext = `survey[suppressers_attributes]`;
    const inputs = [];

    targetingOptions.suppressers.map((suppresser, i) => {
      const suppresserAttributes = [
        ...buildAttributes(suppresser, [
          'id',
          'typeCd',
          'triggerContent',
        ]),
      ];

      if (suppresser.flaggedForDeletion) {
        suppresserAttributes.push(destructionAttribute);
      }

      suppresserAttributes.forEach((suppresserAttribute) => {
        inputs.push(renderHiddenAttribute(`${inputContext}[${i}]`, suppresserAttribute));
      });
    });

    return inputs;
  };

  const renderHiddenPreviousSurveyTriggerInputs = () => {
    const inputContext = `survey[answer_triggers_attributes][0]`;

    const attributes = buildAttributes(targetingOptions.answerTrigger, [
      'id',
      'previousAnsweredSurveyId',
      'previousPossibleAnswerId',
    ]);

    if (targetingOptions.answerTrigger.id &&
      targetingOptions.answerTrigger.previousAnsweredSurveyId === null) {
      attributes.push(destructionAttribute);
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenPageAfterSecondsTriggerInputs = () => {
    const inputContext = `survey[page_after_seconds_trigger_attributes]`;
    const trigger = targetingOptions.pageAfterSecondsTrigger

    const attributes = buildAttributes(trigger,
        [
          'id',
          'renderAfterXSecondsEnabled',
          'renderAfterXSeconds',
        ],
    );

    const triggerInvalid = stringNullOrEmpty(trigger.renderAfterXSeconds);

    if (triggerInvalid) {
      if (trigger.id) {
        attributes.push(destructionAttribute);
      } else {
        return;
      }
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenPageScrollTriggerInputs = () => {
    const inputContext = `survey[page_scroll_trigger_attributes]`;
    const trigger = targetingOptions.pageScrollTrigger;

    const attributes = buildAttributes(targetingOptions.pageScrollTrigger, [
      'id',
      'renderAfterXPercentScrollEnabled',
      'renderAfterXPercentScroll',
    ]);

    const triggerInvalid = stringNullOrEmpty(trigger.renderAfterXPercentScroll);

    if (triggerInvalid) {
      if (trigger.id) {
        attributes.push(destructionAttribute);
      } else {
        return;
      }
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenPageIntentExitTriggerInputs= () => {
    const inputContext = `survey[page_intent_exit_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.pageIntentExitTrigger, [
      'id',
      'renderAfterIntentExitEnabled',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenPageElementClickedTriggerInputs = () => {
    const inputContext = `survey[page_element_clicked_trigger_attributes]`;
    const trigger = targetingOptions.pageElementClickedTrigger;

    const attributes = buildAttributes(trigger, [
      'id',
      'renderAfterElementClickedEnabled',
      'renderAfterElementClicked'
    ]);

    const triggerInvalid = stringNullOrEmpty(trigger.renderAfterElementClicked);

    if (triggerInvalid) {
      if (trigger.id) {
        attributes.push(destructionAttribute);
      } else {
        return;
      }
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenPageElementVisibleTriggerInputs = () => {
    const inputContext = `survey[page_element_visible_trigger_attributes]`;
    const trigger = targetingOptions.pageElementVisibleTrigger;

    const attributes = buildAttributes(trigger, [
      'id',
      'renderAfterElementVisibleEnabled',
      'renderAfterElementVisible'
    ]);

    const triggerInvalid = stringNullOrEmpty(trigger.renderAfterElementVisible);

    if (triggerInvalid) {
      if (trigger.id) {
        attributes.push(destructionAttribute);
      } else {
        return;
      }
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenTextOnPageTriggerInputs = () => {
    const inputContext = `survey[text_on_page_trigger_attributes]`;
    const trigger = targetingOptions.textOnPageTrigger;

    const attributes = buildAttributes(trigger, [
      'id',
      'textOnPageEnabled',
      'textOnPageSelector',
      'textOnPagePresence',
      'textOnPageValue',
    ]);

    const triggerInvalid = stringNullOrEmpty(trigger.textOnPageSelector) ||
      stringNullOrEmpty(trigger.textOnPageValue);

    if (triggerInvalid) {
      if (trigger.id) {
        attributes.push(destructionAttribute);
      } else {
        return;
      }
    }

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenGeoipTriggerInputs = () => {
    const inputContext = `survey[geoip_triggers_attributes]`;
    const inputs = [];

    targetingOptions.geoipTriggers.map((trigger, i) => {
      const triggerAttributes= buildAttributes(trigger, [
        'id',
        'geoCountry',
        'geoStateOrDma',
      ]);

      if (trigger.flaggedForDeletion) {
        triggerAttributes.push(destructionAttribute);
      }

      triggerAttributes.forEach((triggerAttribute) => {
        inputs.push(renderHiddenAttribute(`${inputContext}[${i}]`, triggerAttribute));
      });
    });

    return inputs;
  };

  const renderHiddenClientKeyTriggerInputs= () => {
    const inputContext = `survey[client_key_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.clientKeyTrigger, [
      'id',
      'clientKeyPresence',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenDeviceTriggerInputs= () => {
    const inputContext = `survey[device_triggers_attributes]`;
    const inputs = [];

    targetingOptions.deviceTriggers.map((trigger, i) => {
      const triggerAttributes = buildAttributes(trigger, [
        'id',
        'deviceDataKey',
        'deviceDataMatcher',
        'deviceDataValue',
        'deviceDataMandatory',
      ]);

      if (trigger.flaggedForDeletion) {
        triggerAttributes.push(destructionAttribute);
      }

      triggerAttributes.forEach((triggerAttribute) => {
        inputs.push(renderHiddenAttribute(`${inputContext}[${i}]`, triggerAttribute));
      });
    });

    return inputs;
  };

  const renderHiddenPageviewTriggerInputs = () => {
    const inputContext = `survey[pageview_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.pageviewTrigger, [
      'id',
      'pageviewsCount',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenVisitTriggerInputs = () => {
    const inputContext = `survey[visit_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.visitTrigger, [
      'id',
      'visitorType',
      'visitsCount',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenMobileInstallTriggerInputs = () => {
    const inputContext = `survey[mobile_install_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.mobileInstallTrigger, [
      'id',
      'mobileDaysInstalled',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const renderHiddenMobileLaunchTriggerInputs = () => {
    const inputContext = `survey[mobile_launch_trigger_attributes]`;

    const attributes = buildAttributes(targetingOptions.mobileLaunchTrigger, [
      'id',
      'mobileLaunchTimes',
    ]);

    return renderHiddenAttributes(inputContext, attributes);
  };

  const Options = () => {
    switch (openTabName) {
      case 'general':
        return (
          <GeneralOptions
            surveyId={props.surveyId}
            generalOptions={generalOptions}
            setGeneralOptions={setGeneralOptions}
            unappliedSurveyTags={unappliedSurveyTags()}
            appliedSurveyTags={tagSelections}
            setTagSelections={setTagSelections}
            panelExpansionSettings={panelExpansionSettings}
            updatePanelExpansionSettings={updatePanelExpansionSettings}
          />
        );
      case 'targeting':
        return (
          <TargetingOptions
            targetingOptions={targetingOptions}
            setTargetingOptions={setTargetingOptions}
            panelExpansionSettings={panelExpansionSettings}
            updatePanelExpansionSettings={updatePanelExpansionSettings}
          />
        );
      case 'formatting':
        return (
          <FormattingOptions
            formattingOptions={formattingOptions}
            setFormattingOptions={setFormattingOptions}
            panelExpansionSettings={panelExpansionSettings}
            updatePanelExpansionSettings={updatePanelExpansionSettings}
            toggleAllAtOnce={props.toggleAllAtOnce}
          />
        );
      default:
        console.debug('unrecognized tab name', openTabName);
        return null;
    }
  };

  const HiddenFields = () => {
    return (
      <>
        { renderHiddenGeneralInputs() }
        { renderHiddenFormattingInputs() }
        { renderHiddenTargetingInputs() }
        { renderHiddenTriggerInputs() }
        { renderHiddenSuppresserInputs() }
        { renderHiddenPreviousSurveyTriggerInputs() }
        { renderHiddenPageAfterSecondsTriggerInputs() }
        { renderHiddenPageScrollTriggerInputs() }
        { renderHiddenPageIntentExitTriggerInputs() }
        { renderHiddenPageElementClickedTriggerInputs() }
        { renderHiddenPageElementVisibleTriggerInputs() }
        { renderHiddenTextOnPageTriggerInputs() }
        { renderHiddenGeoipTriggerInputs() }
        { renderHiddenClientKeyTriggerInputs() }
        { renderHiddenDeviceTriggerInputs() }
        { renderHiddenPageviewTriggerInputs() }
        { renderHiddenVisitTriggerInputs() }
        { renderHiddenMobileInstallTriggerInputs() }
        { renderHiddenMobileLaunchTriggerInputs() }
      </>
    );
  };

  return (
    <div className={`survey-settings-sidebar ${sidebarPanelExpanded ? 'expanded' : 'collapsed'}`}>
      <div
        className={`sidebar-tab ${sidebarPanelExpanded ? 'expanded' : 'collapsed'}`}
        onClick={() => { setSidebarPanelExpanded(!sidebarPanelExpanded); }}
      >
        <img
          className="folding-arrow-icon"
          src={sidebarPanelExpanded ? CollapseSidebarIcon : ExpandSidebarIcon}>
        </img>
      </div>

      {
        React.useContext(DisabledFeaturesContext).readOnly ? null :
          <NewQuestionPanel
            addQuestionHandler={props.addQuestionHandler}
            addInvitationHandler={props.addInvitationHandler}
            includeInvitation={props.includeInvitation}
          />
      }

      <div className='sidebar-body'>
        <ul className='sidebar-tab-container'>
          {
            [
              ['general', 'General'],
              ['targeting', 'Targeting'],
              ['formatting', 'Formatting'],
            ].map((settings) => {
              return (
                <SidebarTab
                  key={settings[0]}
                  tabName={settings[0]}
                  tabLabel={settings[1]}
                  openTabName={openTabName}
                  onTabClick={(tabName) => onTabClick(tabName)}
                />
              );
            })
          }
        </ul>

        <div className='sidebar-content'>
          <Options />
        </div>

        <HiddenFields />
      </div>
    </div>
  );
}

export default SurveySettingsSidebar;
