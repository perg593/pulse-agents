import React from 'react';
import PropTypes from 'prop-types';

import createEngine, {
  PortModelAlignment,
} from '@projectstorm/react-diagrams';

import {CanvasWidget} from '@projectstorm/react-canvas-core';

import PiModal from '../modal_dialog/PiModal';

import DisabledFeaturesContext from './DisabledFeaturesContext';

import SurveyListSidebar from '../SurveyListSidebar';
import SurveySettingsSidebar from '../SurveySettingsSidebar';

import {CustomDiagramModel} from '../react_diagram_extension/CustomDiagramModel';
import {QuestionNodeModel} from '../react_diagram_extension/QuestionNodeModel';
import {QuestionNodeFactory} from '../react_diagram_extension/QuestionNodeFactory';
import {SimplePortFactory} from '../react_diagram_extension/SimplePortFactory';
import {QuestionPortModel} from '../react_diagram_extension/QuestionPortModel';
import {QuestionLinkFactory} from '../react_diagram_extension/QuestionLinkFactory';

import {CustomDeleteItemsAction} from '../react_diagram_extension/CustomDeleteItemsAction';
import {CustomZoomCanvasAction} from '../react_diagram_extension/CustomZoomCanvasAction';

import {CustomDefaultState} from '../react_diagram_extension/CustomDefaultState';

import {InvitationNodeFactory} from '../react_diagram_extension/InvitationNodeFactory';
import {InvitationNodeModel} from '../react_diagram_extension/InvitationNodeModel';

import {ThankYouNodeFactory} from '../react_diagram_extension/ThankYouNodeFactory';
import {ThankYouNodeModel} from '../react_diagram_extension/ThankYouNodeModel';

import SurveySubNav from '../SurveySubNav';
import ZoomPanel from './ZoomPanel';
import PreviewPanel from './PreviewPanel';

import {serializeToForm} from './DiagramSerializer';

import DummyFormSubmitButton from '../DummyFormSubmitButton';

// This is the same buffer used by CustomMoveItemsState
const interlaneBuffer = 70;

// Call this whenever we enter all_at_once mode, just in case
// widget dimensions have changed
// TODO: Consolidate this with CustomMoveItemsState
const setAllAtOncePositions = (diagramEngine) => {
  const diagramModel = diagramEngine.getModel();

  let [xPosition, yPosition] = canvasCenter(diagramEngine);

  const invitationNode = diagramModel.getInvitationNode();
  invitationNode.setLocked(true);

  const thankYouNode = diagramModel.getThankYouNode();
  thankYouNode.setLocked(true);

  diagramModel.getQuestionNodes().forEach((node, i) => {
    node.hidePorts = true;
  });

  const nodes = [
    invitationNode,
    ...diagramModel.getQuestionNodesInPositionOrder(),
    thankYouNode,
  ];

  nodes.forEach((node, i) => {
    const nodeSelector = `.node[data-nodeid="${node.getID()}"]`;
    const nodeDOM = document.querySelector(nodeSelector);

    node.setPosition(...[xPosition, yPosition]);
    node.makeDirty();

    yPosition += nodeDOM.offsetHeight + interlaneBuffer;
  });
};

/**
 * Toggle's the canvas' ability to pan on mouse drag
 *
 * @param { Object } engine
 * @param { bool } newValue
 **/
function toggleCanvasDrag(engine, newValue) {
  const OverridingEventHandler = new CustomDefaultState({
    dragCanvasStateOptions: {allowDrag: newValue},
    createLinkStateOptions: {
      lockLinkModification: engine.getModel().lockStructuralChanges,
    },
    dragNodeStateOptions: {allowDrag: !engine.getModel().lockStructuralChanges},
  });

  engine.getStateMachine().pushState(OverridingEventHandler);
}

/**
 * Initializes the react-diagram engine
 *
 * @param { Object } surveyData - the data for the Survey record
 * @param { Object } nodeData - the data for the question and possible answers
 * @param { Object } diagramUpdateHandler - callback for diagram changes
 *   structure of survey (question, possible answer, and routing[link] deletion/creation)
 *
 * @return { Object } the initialized engine
*/
const prepareEngine = (surveyData,
    nodeData,
    diagramUpdateHandler,
) => {
  const context = React.useContext(DisabledFeaturesContext)
  const disableStructuralChanges = context.disableStructuralChanges || context.readOnly;

  const engine = createEngine({
    registerDefaultDeleteItemsAction: false,
    registerDefaultZoomCanvasAction: false,
  });
  engine.maxNumberPointsPerLink = 0;

  const diagramModel = new CustomDiagramModel(
      {
        allAtOnceMode: surveyData.displayAllQuestions,
        lockStructuralChanges: disableStructuralChanges,
        readOnly: context.readOnly,
      },
  );

  // register some other factories as well
  engine.getPortFactories().registerFactory(
      new SimplePortFactory(
          'question',
          (config) => {
            new QuestionPortModel(PortModelAlignment.LEFT);
          },
      ),
  );
  engine.getNodeFactories().registerFactory(new QuestionNodeFactory(
      () => setAllAtOncePositions(engine),
  ));
  engine.getLinkFactories().registerFactory(new QuestionLinkFactory());

  engine.getNodeFactories().registerFactory(new InvitationNodeFactory());
  engine.getNodeFactories().registerFactory(new ThankYouNodeFactory());

  const nodes = nodeData.map((data) => {
    const curNode = new QuestionNodeModel(
        data.questionData,
        data.possibleAnswers,
        surveyData,
        data.questionData.diagramProperties,
        diagramModel.allAtOnceMode
    );

    if (context.readOnly) {
      curNode.setLocked(true);
    }

    return curNode;
  });

  const nodeLinks = nodeData.map((data, nodeIndex) => {
    let questionLink = null;
    let nextQuestionId = data.questionData.nextQuestionId;

    // create link between this node and question with next question ID
    if (nextQuestionId) {
      const startPort = nodes[nodeIndex].getQuestionOutputPort();

      const endNodeIndex = nodeData.findIndex(
          (datum) => datum.questionData.id === nextQuestionId,
      );

      const endPort = nodes[endNodeIndex].getQuestionInputPort();

      questionLink = startPort.link(endPort);
    }

    const possibleAnswerLink = data.possibleAnswers.map((possibleAnswerData, possibleAnswerIndex) => {
      nextQuestionId = possibleAnswerData.nextQuestionId;

      if (nextQuestionId) {
        const startPort = nodes[nodeIndex].getPossibleAnswerPort(possibleAnswerData);

        const endNodeIndex = nodeData.findIndex((datum) => {
          return datum.questionData.id === nextQuestionId;
        });
        const endPort = nodes[endNodeIndex].getQuestionInputPort();

        return startPort.link(endPort);
      } else {
        return null;
      }
    });

    return [questionLink, ...possibleAnswerLink];
  }).flat().filter(Boolean);

  diagramModel.addAll(...nodes, ...nodeLinks);

  const invitationNode = new InvitationNodeModel(
      surveyData.invitation,
      surveyData.invitationButton,
      surveyData.invitationButtonDisabled,
      surveyData.invitationDiagramProperties,
      diagramModel.allAtOnceMode,
  );
  if (!surveyData.invitation) {
    invitationNode.delete();
  }

  const firstQuestionLink =
    invitationNode.getStartPort().link(nodes[0].getQuestionInputPort());

  // all?
  diagramModel.addAll(invitationNode, firstQuestionLink);
  invitationNode.registerListener({
    eventDidFire: handleNodeSelection,
  });

  if (context.readOnly) {
    invitationNode.setLocked(true);
  }

  const thankYouNode = new ThankYouNodeModel(
      surveyData.thankYou,
      surveyData.pollEnabled,
      surveyData.thankYouDiagramProperties,
  );

  if (context.readOnly) {
    thankYouNode.setLocked(true);
  }

  // all?
  diagramModel.addAll(thankYouNode);

  engine.setModel(diagramModel);

  nodes.forEach((node) => {
    node.registerListener({
      eventDidFire: handleNodeSelection,
    });
  });

  diagramModel.registerListener({
    eventDidFire: (e) => diagramUpdateHandler(e, engine),
  });

  // Registers our overriding event handler
  toggleCanvasDrag(engine, !diagramModel.allAtOnceMode);

  // Registers our custom deletion handler
  engine.getActionEventBus().registerAction(
      new CustomDeleteItemsAction({locked: disableStructuralChanges}),
  );

  engine.getActionEventBus().registerAction(
      new CustomZoomCanvasAction({inverseZoom: true}),
  );

  return engine;
};

/**
 * Adds our own additional node selection behaviour.
 * Note that react-diagram takes care of tracking what's selected.
 * @param { Object } e - the node event
*/
function handleNodeSelection(e) {
  if (e.function === 'selectionChanged') {
    const node = e.entity;
    const isSelected = e.isSelected;
    const outPorts = node.portsOut;

    const domElement = document.querySelector(`.node[data-nodeid='${node.options.id}']`);

    if (isSelected) {
      domElement.classList.add('selected');
    } else {
      domElement.classList.remove('selected');
    }

    outPorts.forEach((port) => {
      port.setUseActiveColor(isSelected);

      if (port.targetPort()) {
        port.targetPort().setUseActiveColor(isSelected);
      }

      Object.values(port.links).forEach((link) => {
        link.setUseActiveColor(isSelected);
      });
    });
  }
}

const onSubmitHandler = (e, diagramModel) => {
  e.preventDefault();
  const form = $(e.target);
  serializeToForm(diagramModel);

  const data = form.serialize();

  $.ajax({
    url: form.attr('action'),
    data: data,
    type: form.attr('method'),
  }).done(function(_responseData) {
    console.debug('update succeeded!');
    location.reload();
  }).fail(function(jqXHR, textStatus, errorThrown) {
    alert("We're sorry, but there was a problem saving your survey. The development team has been notified.");
    console.debug('failed to save', jqXHR, textStatus, errorThrown);
  });
};

/**
 * Returns a rough estimate of the canvas centre point
 * 190 and 100 are rough estimates. We won't know the true half-dimensions
 * until the node's been rendered.
 *
 * @param { Object } diagramEngine - the react-diagram
 * @return { Array } [x, y]
*/
function canvasCenter(diagramEngine) {
  const xPosition = window.innerWidth / 2 - 190;
  const yPosition = window.innerHeight / 2 - 100;

  const tempPosition = diagramEngine.getRelativeMousePoint(
      {clientX: xPosition, clientY: yPosition},
  );

  return [tempPosition.x, tempPosition.y];
}

/**
 * Adds a new question to the diagram
 * @param { string } questionType
 * @param { CustomDiagramModel } diagramModel
 * @param { Object } diagramEngine
 * @param { Object } surveyData
*/
function addQuestion(questionType, diagramModel, diagramEngine, surveyData) {
  let questionData = null;
  let newNode = null;
  const possibleAnswerData = [];

  switch (questionType) {
    case 'slider':
      questionData = {
        type: {
          label: 'NEW SLIDER QUESTION',
          value: 'slider_question',
        },
        content: 'new slider question',
        sliderStartPosition: 1, // The question in the middle
        sliderSubmitButtonEnabled: true,
        nextQuestionAllowed: false,
      };

      for (let i = 1; i <= 3; i++) {
        possibleAnswerData.push({
          content: `Answer ${i}`,
          nextQuestionAllowed: true,
          placeholderKey: `new_possible_answer_${i}_${Date.now()}`,
          position: i-1,
        });
      }

      break;
    case 'nps':
      questionData = {
        type: {
          label: 'NEW NET PROMOTER SCORE',
          value: 'single_choice_question',
        },
        content: 'How likely are you to recommend us to a friend or colleague?',
        nextQuestionAllowed: false,
        nps: true,
        buttonType: 'standard',
        answersPerRowDesktop: 11,
        answersPerRowMobile: 6,
        answersAlignmentDesktop: 'center',
        answersAlignmentMobile: 'center',
      };

      for (let i = 0; i <= 10; i++) {
        possibleAnswerData.push({
          content: i,
          nextQuestionAllowed: true,
          placeholderKey: `new_possible_answer_${i}_${Date.now()}`,
          nextQuestionAllowed: true,
          position: i,
        });
      }

      break;
    case 'custom_content':
      questionData = {
        type: {
          label: 'NEW CUSTOM CONTENT QUESTION',
          value: 'custom_content_question',
        },
        content: 'new card name',
        nextQuestionAllowed: true,
        nextQuestionColumn: 'next_question_id',
      };

      break;
    case 'free_text':
      questionData = {
        type: {
          label: 'NEW FREE TEXT QUESTION',
          value: 'free_text_question',
        },
        content: 'new free text question',
        nextQuestionAllowed: true,
        nextQuestionColumn: 'free_text_next_question_id',
      };

      break;
    case 'multiple_choice':
      questionData = {
        type: {
          label: 'NEW MULTIPLE CHOICE QUESTION',
          value: 'multiple_choices_question',
        },
        content: 'new multiple choice question',
        nextQuestionAllowed: true,
        nextQuestionColumn: 'next_question_id',
        answersPerRowDesktop: 3,
        answersPerRowMobile: 3,
      };

      possibleAnswerData.push({
        content: 'Answer 1',
        placeholderKey: `new_possible_answer_1_${Date.now()}`,
        nextQuestionAllowed: false,
        position: 0,
      });

      possibleAnswerData.push({
        content: 'Answer 2',
        placeholderKey: `new_possible_answer_2_${Date.now()}`,
        nextQuestionAllowed: true,
        position: 1,
      });

      break;
    case 'single_choice':
      questionData = {
        type: {
          label: 'NEW SINGLE CHOICE QUESTION',
          value: 'single_choice_question',
        },
        buttonType: 'standard',
        content: 'new single choice question',
        nextQuestionAllowed: false,
        answersPerRowDesktop: 3,
        answersPerRowMobile: 3,
      };

      possibleAnswerData.push({
        content: 'Answer 1',
        nextQuestionAllowed: true,
        placeholderKey: `new_possible_answer_1_${Date.now()}`,
        position: 0,
      });

      possibleAnswerData.push({
        content: 'Answer 2',
        nextQuestionAllowed: true,
        placeholderKey: `new_possible_answer_2_${Date.now()}`,
        position: 1,
      });

      break;
  }

  const deletedQuestionSelector = '[name^="survey[questions_attributes]"][name$="[_destroy]"]';
  const numDeletedQuestions = document.querySelectorAll(deletedQuestionSelector).length;
  const numCurrentQuestions = diagramModel.getQuestionNodes().length;

  questionData['id'] = null;
  questionData['index'] = numDeletedQuestions + numCurrentQuestions;
  questionData['position'] = numCurrentQuestions;

  let xPosition = null;
  let yPosition = null;

  if (diagramModel.allAtOnceMode) {
    const thankYouNode = diagramModel.getThankYouNode();
    const thankYouNodeDOM = document.querySelector(`.node[data-nodeid="${thankYouNode.getID()}"]`);

    xPosition = canvasCenter(diagramEngine)[0];
    yPosition = thankYouNode.position.y;

    thankYouNode.setPosition(xPosition, yPosition + thankYouNodeDOM.offsetHeight + interlaneBuffer);
  } else {
    [xPosition, yPosition] = canvasCenter(diagramEngine);
  }

  newNode = new QuestionNodeModel(
      questionData,
      possibleAnswerData,
      surveyData,
      {position: [xPosition, yPosition]},
      diagramModel.allAtOnceMode,
  );

  diagramModel.clearSelection();
  diagramModel.addNode(newNode);
  newNode.setSelected(true);
}

SurveyEditor.propTypes = {
  surveyId: PropTypes.number.isRequired,
  questionData: PropTypes.array.isRequired,
  surveyData: PropTypes.object.isRequired,

  // See PreviewPanel
  surveyPreviewData: PropTypes.object.isRequired,
  authenticityToken: PropTypes.string.isRequired,
  livePreviewUrl: PropTypes.string,

  // See SurveySubNav
  subnavLinks: PropTypes.array.isRequired,

  // See SurveySettingsSiderbar
  openTabName: PropTypes.string,
  surveyGeneralOptions: PropTypes.object.isRequired,
  surveyTargetingOptions: PropTypes.object.isRequired,
  surveyFormattingOptions: PropTypes.object.isRequired,
  surveyTags: PropTypes.array,
  htmlAttributeMap: PropTypes.object.isRequired,

  // See SurveyListSiderbar
  surveyListData: PropTypes.array.isRequired,
};

/**
 * A wrapper component for the survey edit page's content
 * @param { Object } props
 * @return { JSX.Element }
*/
function SurveyEditor(props) {
  const disableStructuralChanges = React.useContext(DisabledFeaturesContext).disableStructuralChanges;

  const handleNodeDeletion = (engine) => {
    const diagramModel = engine.getModel();

    diagramModel.defragmentQuestionPositions();

    diagramModel.assignNewFirstQuestion();
  };

  const handleDiagramUpdate = (e, engine) => {
    if (e.function === 'nodesUpdated') {
      if (!e.isCreated) {
        handleNodeDeletion(engine);
      }
      engine.repaintCanvas();
    } else if (e.function === 'zoomUpdated') {
      const zoomValue = Math.round(diagramEngine.getModel().getDisplayZoomLevel());

      $('#zoom_level_indicator').val(`${zoomValue}%`);
    }
  };

  const [diagramEngine, _setDiagramEngine] = React.useState(
      prepareEngine(props.surveyData,
          props.questionData,
          handleDiagramUpdate,
          disableStructuralChanges,
      ),
  );

  const [allAtOnceMode, setAllAtOnceMode] = React.useState(diagramEngine.getModel().allAtOnceMode);

  const addQuestionOfType = (questionType) => {
    addQuestion(questionType, diagramEngine.getModel(), diagramEngine, props.surveyData);
  };

  const addInvitation = () => {
    const diagramModel = diagramEngine.getModel();

    const invitationNode = diagramModel.getInvitationNode();
    invitationNode.undelete();

    diagramModel.clearSelection();

    invitationNode.setSelected(true);
  };

  const enterAllAtOnceMode = () => {
    const diagramModel = diagramEngine.getModel();
    diagramModel.allAtOnceMode = true;

    toggleCanvasDrag(diagramEngine, false);

    diagramModel.getInvitationNode().hidePorts = true;

    diagramModel.getNodes().forEach((node) => {
      node.persistentDiagramProperties.position = [node.position.x, node.position.y];
    });

    diagramModel.getQuestionNodes().forEach((node) => {
      node.hidePorts = true;

      node.portsOut.forEach((port) => {
        port.reportedPosition = false;
      });

      node.portsIn.forEach((port) => {
        port.reportedPosition = false;
      });
    });

    diagramModel.getLinks().forEach((link) => {
      link.hidden = true;
    });

    setAllAtOncePositions(diagramEngine);
    setAllAtOnceMode(true);
  };

  const exitAllAtOnceMode = () => {
    const diagramModel = diagramEngine.getModel();
    diagramModel.allAtOnceMode = false;

    toggleCanvasDrag(diagramEngine, true);

    // unlock nodes
    const invitationNode = diagramModel.getInvitationNode();

    invitationNode.setLocked(false);
    invitationNode.setPosition(
        ...invitationNode.persistentDiagramProperties.position,
    );
    invitationNode.hidePorts = false;
    invitationNode.getStartPort().reportedPosition = false;

    // unlock nodes
    const thankYouNode = diagramModel.getThankYouNode();
    thankYouNode.setLocked(false);
    thankYouNode.setPosition(
        ...thankYouNode.persistentDiagramProperties.position,
    );

    // reveal ports and links
    diagramModel.getQuestionNodes().forEach((node) => {
      node.setPosition(...node.persistentDiagramProperties.position);

      node.hidePorts = false;

      node.portsOut.forEach((port) => {
        port.reportedPosition = false;
      });

      node.portsIn.forEach((port) => {
        port.reportedPosition = false;
      });
    });

    diagramModel.getLinks().forEach((link) => {
      link.hidden = false;
    });

    diagramEngine.repaintCanvas();
    setAllAtOnceMode(false);
  };

  const toggleAllAtOnce = () => {
    const diagramModel = diagramEngine.getModel();

    if (diagramModel.allAtOnceMode) {
      exitAllAtOnceMode();
    } else {
      enterAllAtOnceMode();
    }
  };

  // run after initial render, when we know node dimensions
  React.useEffect(() => {
    const diagramModel = diagramEngine.getModel();

    if (diagramModel.allAtOnceMode) {
      setAllAtOncePositions(diagramEngine);
    }
  }, []);

  const dialogRef = React.useRef(null);

  const openDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.showModal();
    }
  };

  const LivePreviewModal = () => {
    const openNewSecureWindow = () => {
      const newWindow = window.open('', 'live_preview_window');
      newWindow.opener = null;
    };

    const isSafari = () => {
      return /Apple Computer/.test(navigator.vendor);
    };

    return (
      <PiModal
        ref={dialogRef}
        modalClassName='live-preview-modal'
      >
        <PiModal.Header
          title='Live Preview'
          titleClassName='settings-modal-title'
        />

        <PiModal.Body>
          <form
            id='live_preview_form'
            action='/live_preview'
            method='post'
            target={isSafari() ? '_blank' : 'live_preview_window'}
            onSubmit={isSafari() ? undefined : openNewSecureWindow} // The default behavoir of nullifying window.opener with <form target="_blank"> works only on Safari, whereas opening a new secure window through javascript works as expected on the browsers except Safari. https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/issues/2364
            className='live-preview-container'
          >
            <input
              type='hidden'
              name='authenticity_token'
              value={props.authenticityToken}
              form='live_preview_form'
            />
            <input
              type='hidden'
              name='user[survey_id]'
              value={props.surveyId}
              form='live_preview_form'
            />
            <input
              name='user[live_preview_url]'
              placeholdertext='http://domain.com'
              defaultValue={props.livePreviewUrl}
              className='url-input'
              form='live_preview_form'
            />
            <input
              type='submit'
              className='btn btn-default'
              value='Preview'
              form='live_preview_form'
            />
          </form>
        </PiModal.Body>
      </PiModal>
    );
  };

  return (
    <div className='edit-wrapper'>
      <SurveyListSidebar surveyListData={props.surveyListData}/>
      <div className='canvas-wrapper'>
        <form
          id='canvas_form'
          className='canvas-form'
          action={`/surveys/${props.surveyId}`}
          method='patch'
          onSubmit={(e) => onSubmitHandler(e, diagramEngine.getModel())}
        >
          <div className='form-fields-container'>
            <div className='canvas-container'>
              <SurveySubNav
                subnavLinks={props.subnavLinks}
                selectedTab='edit'
              />
              <CanvasWidget
                engine={diagramEngine}
                className={`canvas-widget ${allAtOnceMode ? 'all-at-once' : ''}`}
              />
            </div>

            <SurveySettingsSidebar
              surveyId={props.surveyId}
              surveyTags={props.surveyTags}
              surveyGeneralOptions={props.surveyGeneralOptions}
              authenticityToken={props.authenticityToken}
              surveyFormattingOptions={props.surveyFormattingOptions}
              surveyTargetingOptions={props.surveyTargetingOptions}
              addQuestionHandler={addQuestionOfType}
              addInvitationHandler={addInvitation}
              includeInvitation={() => {
                const invitationNode = diagramEngine.getModel().getInvitationNode();
                return invitationNode?.deleted;
              }}
              storedOpenTabName={props.openTabName}
              toggleAllAtOnce={toggleAllAtOnce}
              htmlAttributeMap={props.htmlAttributeMap}
            />
          </div>

          <div className='footer-container'>
            <PreviewPanel
              surveyPreviewData={props.surveyPreviewData}
              showLivePreviewModal={openDialog}
            />

            <ZoomPanel diagramEngine={diagramEngine} />

            <DummyFormSubmitButton />
            <input
              className='save-button'
              type='submit'
              value='SAVE'
              disabled={React.useContext(DisabledFeaturesContext).readOnly}
            />
          </div>
        </form>
        <LivePreviewModal />
      </div>
    </div>
  );
}

export default SurveyEditor;
