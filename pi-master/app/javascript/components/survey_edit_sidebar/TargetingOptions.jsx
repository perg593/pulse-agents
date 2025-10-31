import React from 'react';
import PropTypes from 'prop-types';

import SampleRate from './targeting_options/SampleRate';
import DevicesAndChannels from './targeting_options/DevicesAndChannels';
import UrlsAndEvents from './targeting_options/UrlsAndEvents';
import Dates from './targeting_options/Dates';
import PreviousResponses from './targeting_options/PreviousResponses';
import OnPageBehaviour from './targeting_options/OnPageBehaviour';
import CRMTargeting from './targeting_options/CRMTargeting';
import GeoTargeting from './targeting_options/GeoTargeting';
import Goal from './targeting_options/Goal';
import UserBehavior from './targeting_options/UserBehavior';
import SDKTargeting from './targeting_options/SDKTargeting';
import Advanced from './targeting_options/Advanced';

TargetingOptions.propTypes = {
  setTargetingOptions: PropTypes.func.isRequired,
  targetingOptions: PropTypes.object.isRequired,
  panelExpansionSettings: PropTypes.object.isRequired,
  updatePanelExpansionSettings: PropTypes.func.isRequired,
};
/**
 * A component for the survey edit page's targeting options
 * @param { Object } props
 * @return { TargetingOptions }
 */
function TargetingOptions(props) {
  const updateTargetingOption = (newObject) => {
    props.setTargetingOptions({
      ...props.targetingOptions,
      ...newObject,
    });
  };

  /**
   * Updates or Adds an array-based targeting option
   *
   * e.g. (3, 'triggers', {typeContent: 'http://www.duckduckgo.com'})
   * will update the typeContent of the trigger at index 3 with
   * the provided value.
   *
   * @param { bigint } index - Index of the object to change. Passing null will
   * add a new record
   * @param { String } propertyName - The name of the property
   * @param { Object } newValue - The object describing the change
   */
  const onArrayPropertyChange = (index, propertyName, newValue) => {
    const newItems = [...props.targetingOptions[propertyName]];
    if (index === null) {
      newItems.push(newValue);
    } else {
      newItems[index] = {...newItems[index], ...newValue};
    }

    const newObject = {};
    newObject[propertyName] = newItems;

    updateTargetingOption(newObject);
  };

  /**
   * Deletes an array-based targeting option.
   * Options that are stored in the db will be flagged for later deletion.
   * Options that are not yet stored in the db will be removed immediately.
   * Assumes options are never reordered and that preserving indexes is
   * important
   *
   * @param { bigint } index - Index of the object to delete
   * @param { string} propertyName - The name of the property to update
   */
  const deleteArrayItem = (index, propertyName) => {
    if (props.targetingOptions[propertyName][index].id) {
      onArrayPropertyChange(index, propertyName, {flaggedForDeletion: true});
    } else {
      const newItems = [...props.targetingOptions[propertyName]];
      newItems.splice(index, 1);

      const newObject = {};
      newObject[propertyName] = newItems;
      updateTargetingOption(newObject);
    }
  };

  // Determine which surveys are eligible to be selected
  const previousSurveyOptions = props.targetingOptions.answerTriggerOptions.surveyOptions.find((option) => {
    return option.value === props.targetingOptions.answerTrigger.previousAnsweredSurveyId;
  });

  // Determine which possible answers are eligible to be selected
  const previousSurveyPossibleAnswerOptions = previousSurveyOptions ? previousSurveyOptions.possibleAnswerOptions : [];

  return (
    <>
      <SampleRate
        value={props.targetingOptions.sampleRate}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <DevicesAndChannels
        targetingOptions={props.targetingOptions}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <UrlsAndEvents
        triggers={props.targetingOptions.triggers}
        suppressers={props.targetingOptions.suppressers}
        targetingOptions={props.targetingOptions}
        onArrayPropertyChange={onArrayPropertyChange}
        deleteArrayItem={deleteArrayItem}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
        expandByDefault
      />
      <Dates
        startsAt={props.targetingOptions.startsAt}
        endsAt={props.targetingOptions.endsAt}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <PreviousResponses
        answerTrigger={props.targetingOptions.answerTrigger}
        surveyOptions={props.targetingOptions.answerTriggerOptions.surveyOptions}
        previousSurveyPossibleAnswerOptions={previousSurveyPossibleAnswerOptions}
        updateFunction={updateTargetingOption}
        previousSurveyOptions={previousSurveyOptions}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <OnPageBehaviour
        pageAfterSecondsTrigger={props.targetingOptions.pageAfterSecondsTrigger}
        pageScrollTrigger={props.targetingOptions.pageScrollTrigger}
        pageIntentExitTrigger={props.targetingOptions.pageIntentExitTrigger}
        pageElementClickedTrigger={props.targetingOptions.pageElementClickedTrigger}
        pageElementVisibleTrigger={props.targetingOptions.pageElementVisibleTrigger}
        textOnPageTrigger={props.targetingOptions.textOnPageTrigger}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <CRMTargeting
        clientKeyTrigger={props.targetingOptions.clientKeyTrigger}
        deviceTriggers={props.targetingOptions.deviceTriggers}
        updateFunction={updateTargetingOption}
        onArrayPropertyChange={onArrayPropertyChange}
        deviceTriggerMatcherOptions={props.targetingOptions.deviceTriggerMatcherOptions}
        deleteArrayItem={deleteArrayItem}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <GeoTargeting
        geoipTriggers={props.targetingOptions.geoipTriggers}
        geoipTriggerOptions={props.targetingOptions.geoipTriggerOptions}
        onArrayPropertyChange={onArrayPropertyChange}
        deleteArrayItem={deleteArrayItem}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <Goal
        goal={props.targetingOptions.goal}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <UserBehavior
        pageviewTrigger={props.targetingOptions.pageviewTrigger}
        visitTrigger={props.targetingOptions.visitTrigger}
        visitTriggerOptions={props.targetingOptions.visitTriggerOptions}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <SDKTargeting
        mobileInstallTrigger={props.targetingOptions.mobileInstallTrigger}
        mobileLaunchTrigger={props.targetingOptions.mobileLaunchTrigger}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
      <Advanced
        stopShowingWithoutAnswer={props.targetingOptions.stopShowingWithoutAnswer}
        ignoreFrequencyCap={props.targetingOptions.ignoreFrequencyCap}
        refireEnabled={props.targetingOptions.refireEnabled}
        refireTime={props.targetingOptions.refireTime}
        refireTimePeriod={props.targetingOptions.refireTimePeriod}
        refireTimePeriodOptions={props.targetingOptions.refireTimePeriodOptions}
        updateFunction={updateTargetingOption}
        panelExpansionSettings={props.panelExpansionSettings}
        updatePanelExpansionSettings={props.updatePanelExpansionSettings}
      />
    </>
  );
}

export default TargetingOptions;
