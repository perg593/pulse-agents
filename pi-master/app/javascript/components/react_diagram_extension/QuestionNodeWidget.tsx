import * as React from 'react';

import ReactDOM from 'react-dom';

import {
  DiagramEngine, PortWidget,
} from '@projectstorm/react-diagrams';

import {ResizableBox} from 'react-resizable';
import 'react-resizable/css/styles.css';

import {DragDropContext, Droppable, Draggable} from '@hello-pangea/dnd';

import {Menu, Item, Separator, contextMenu} from 'react-contexify';

import 'react-contexify/ReactContexify.css';

import DOMPurify from 'dompurify';

import {QuestionNodeModel} from './QuestionNodeModel';
import {EditableField} from '../survey_editor/EditableField';

import DeleteIcon from '../../images/survey_editor/delete.svg';
import AddIcon from '../../images/survey_editor/add.svg';
import HandlesIcon from '../../images/survey_editor/handles.svg';

import QuestionSettingsModal from '../question_settings_modal/QuestionSettingsModal';
import PossibleAnswerImageModal from '../survey_editor/PossibleAnswerImageModal';

export interface QuestionNodeWidgetProps {
  node: QuestionNodeModel;
  engine: DiagramEngine;
  size?: number;
  setAllAtOncePositions: Function;
}

/**
 * The React widget representing a QuestionNode (aka Question Card)
 */
export class QuestionNodeWidget
  extends React.Component<QuestionNodeWidgetProps> {
  readonly minimumNumberOfPossibleAnswers = 2;

  question: Object;
  questionContext: string;

  readonly colorPalette = [
    '#9B62A7',
    '#6F4C9B',
    '#5568B8',
    '#4D8AC6',
    '#549EB3',
    '#60AB9E',
    '#77B77D',
    '#A6BE54',
    '#E49C39',
    '#E67932',
    '#95211B',
  ];

  /**
   * Initializes the QuestionNodeWidget
   * @param { Object } props - contains node model data and an engine reference
   */
  constructor(props) {
    super(props);

    this.question = this.props.node.question;
    this.questionContext = `survey[questions_attributes][${this.question.index}]`;

    this.state = {
      activeInputId: null,
      question_content: this.question.content,
    };

    this.props.node.possibleAnswers.forEach((possibleAnswer) => {
      this.state[possibleAnswer.id] = possibleAnswer.content;
    });

    this.handleContextMenuItemClick =
        this.handleContextMenuItemClick.bind(this);

    this.renderDraggableClone = this.renderDraggableClone.bind(this);
    this.lockStructuralChanges = this.props.engine.getModel().lockStructuralChanges;
    this.readOnly = this.props.engine.getModel().readOnly;
  }

  /**
   * Adds an input to the form. Used for things we can't otherwise
   * render in render() (perhaps because we've been destroyed)
   *
   * @param { string } name - the name of the attribute
   * @param { string } value - the value of the attribute
   */
  addInputToForm(name: string, value: string) {
    const form = $('#canvas_form');

    $('<input />').attr({
      type: 'hidden',
      name: name,
      value: value,
    }).appendTo(form);
  }

  /**
   * Removes this node's question from the diagram
   */
  deleteQuestion() {
    if (!window.confirm('Are you sure you want to delete this question?')) {
      return;
    }

    if (this.question.id != null) {
      this.addInputToForm(`${this.questionContext}[_destroy]`, '1');
      this.addInputToForm(`${this.questionContext}[id]`, this.question.id);
    }

    this.props.node.remove();
  }

  /**
   * Adds a new possible answer to this question
   */
  addPossibleAnswer() {
    const position = this.props.node.getLastPossibleAnswer().position + 1;

    const newPossibleAnswer = {
      content: `Answer ${position + 1}`,
      nextQuestionAllowed: true,
      placeholderKey: `new_possible_answer_${Date.now()}`,
      position: position,
    };

    // We'll want to wipe the old last possible answer's next_question_id.
    // Since the port will be gone, we must add the input to the form now.
    if (this.question.type.value === 'multiple_choices_question' &&
     this.props.node.getLastPossibleAnswer().id !== undefined
    ) {
      const possibleAnswerIndex = this.props.node.possibleAnswers.length - 1;
      const possibleAnswerContext =
        `${this.questionContext}[possible_answers_attributes][${possibleAnswerIndex}]`;

      this.addInputToForm(`${possibleAnswerContext}[next_question_id]`, null);
    }

    this.props.node.addPossibleAnswer(newPossibleAnswer);

    if (this.props.engine.getModel().allAtOnceMode) {
      this.props.setAllAtOncePositions();
    }

    this.props.engine.repaintCanvas();
  }

  /**
   * Whether or not this question supports adding possible answers
   * @return { boolean } - Whether or not a possible answer can be added
   */
  canAddPossibleAnswers(): boolean {
    if (this.lockStructuralChanges) {
      return false;
    }

    const typesSupportingPossibleAnswers = [
      'single_choice_question', 'multiple_choices_question', 'slider_question',
    ];

    return typesSupportingPossibleAnswers.includes(this.question.type.value) &&
      !this.question.nps;
  }

  /**
   * Generates the node footer, which is only visible when this node is selected
   * @return { JSX.Element } - the footer element
   */
  renderFooter(): JSX.Element {
    const canDelete = !this.lockStructuralChanges &&
      this.props.engine.getModel().getQuestionNodes().length > 1;

    return (
      <div className='node-footer'>
        {
          canDelete ?
            <a onClick={() => this.deleteQuestion()} href='#'>
              <img src={DeleteIcon}/>
              <span>DELETE</span>
            </a> :
              null
        }

        {
          this.readOnly ? null : <QuestionSettingsModal
            engine={this.props.engine}
            node={this.props.node}
            lockPossibleAnswerOrderRandomization={this.lockStructuralChanges}
          />
        }

        {
          this.canAddPossibleAnswers() ?
            <a onClick={() => this.addPossibleAnswer()} href='#'>
              <div className='add-button'>
                <img src={AddIcon}/>
                <span>ADD NEW</span>
              </div>
            </a> :
              null
        }
      </div>
    );
  }

  /**
   * Deletes the specified possible answer
   * @param { Object } possibleAnswer - the possible answer object to destroy
   */
  deletePossibleAnswer(possibleAnswer: Object) {
    // remove from graph
    this.props.node.removePossibleAnswer(possibleAnswer);
    this.props.engine.repaintCanvas();

    this.props.node.getPossibleAnswerPorts().forEach((port) => {
      // very important, without this the port's new position in the DOM
      // won't be acknowledged by the canvas
      port.reportedPosition = false;
    });

    // If the possible answer had a port, then react-diagrams will detect a
    // change to the diagram and refresh; however, possible answers for
    // multiple choice questions don't necessarily have ports, so react-diagram
    // must be forced to update.
    this.forceUpdate();
  }

  /**
   * Renders hidden form inputs
   * @return { JSX.Element } All necessary hidden inputs
   */
  renderHiddenInputs(): JSX.Element {
    const questionProperties = [
      {
        name: 'id',
        value: this.question.id || '',
      },
      {
        name: 'nps',
        value: this.question.nps || '',
      },
      {
        name: 'randomize',
        value: [0, 1].includes(parseInt(this.question.randomize)) ?
          this.question.randomize :
            '',
      },
      {
        name: 'button_type',
        value: this.question.buttonType,
      },
      {
        name: 'answers_per_row_mobile',
        value: this.question.answersPerRowMobile || '',
      },
      {
        name: 'answers_per_row_desktop',
        value: this.question.answersPerRowDesktop || '',
      },
      {
        name: 'single_choice_default_label',
        value: this.question.singleChoiceDefaultLabel || this.props.node.defaultValue('singleChoiceDefaultLabel'),
      },
      {
        name: 'question_type',
        value: this.question.type.value || '',
      },
      {
        name: 'desktop_width_type',
        value: this.question.desktopWidthType,
        omit_if_undefined: true,
      },
      {
        name: 'answers_alignment_desktop',
        value: this.question.answersAlignmentDesktop || '',
      },
      {
        name: 'mobile_width_type',
        value: this.question.mobileWidthType,
        omit_if_undefined: true,
      },
      {
        name: 'answers_alignment_mobile',
        value: this.question.answersAlignmentMobile || '',
      },
      {
        name: 'before_question_text',
        value: DOMPurify.sanitize(this.question.beforeQuestionText) || '',
      },
      {
        name: 'after_question_text',
        value: DOMPurify.sanitize(this.question.afterQuestionText) || '',
      },
      {
        name: 'before_answers_count',
        value: this.question.beforeAnswersCount || '',
      },
      {
        name: 'after_answers_count',
        value: this.question.afterAnswersCount || '',
      },
      {
        name: 'before_answers_items',
        value: this.question.beforeAnswersItems || [],
      },
      {
        name: 'after_answers_items',
        value: this.question.afterAnswersItems || [],
      },
      {
        name: 'hint_text',
        value: this.question.hintText || '',
      },
      {
        name: 'submit_label',
        value: this.question.submitLabel || this.props.node.defaultValue('submitLabel'),
      },
      {
        name: 'error_text',
        value: this.question.errorText || this.props.node.defaultValue('errorText'),
      },
      {
        name: 'height',
        value: this.question.height || this.props.node.defaultValue('height'),
        omit_if_undefined: true,
      },
      {
        name: 'max_length',
        value: this.question.maxLength || this.props.node.defaultValue('maxLength'),
        omit_if_undefined: true,
      },
      {
        name: 'maximum_selection',
        value: this.question.maximumSelection || this.props.node.defaultValue('maximumSelection'),
      },
      {
        name: 'enable_maximum_selection',
        value: this.question.enableMaximumSelection || '',
      },
      {
        name: 'empty_error_text',
        value: this.question.emptyErrorText || this.props.node.defaultValue('emptyErrorText'),
      },
      {
        name: 'maximum_selections_exceeded_error_text',
        value: this.question.maximumSelectionsExceededErrorText || '',
      },
      {
        name: 'fullscreen',
        value: this.question.fullscreen || '',
      },
      {
        value: this.question.autocloseEnabled || '',
        name: 'autoclose_enabled',
      },
      {
        value: this.question.autocloseDelay || '',
        name: 'autoclose_delay',
      },
      {
        value: this.question.autoredirectEnabled || '',
        name: 'autoredirect_enabled',
      },
      {
        value: this.question.autoredirectDelay || '',
        name: 'autoredirect_delay',
      },
      {
        value: this.question.autoredirectUrl || '',
        name: 'autoredirect_url',
      },
      {
        value: this.question.showAfterAAO || '',
        name: 'show_after_aao',
      },
      {
        value: this.question.opacity || '',
        name: 'opacity',
      },
      {
        value: this.question.backgroundColor || '',
        name: 'background_color',
      },
      {
        value: this.question.imageSettings || '',
        name: 'image_settings',
      },
      {
        value: this.question.position,
        name: 'position',
      },
      {
        value: this.question.customContent || '',
        name: 'custom_content',
      },
      {
        value: this.question.showAdditionalContent || false,
        name: 'show_additional_content',
      },
      {
        value: this.question.additionalContent || '',
        name: 'additional_content',
      },
      {
        value: this.question.additionalContentPosition || this.props.node.defaultValue('additionalContentPosition'),
        name: 'additional_content_position',
      },
      {
        value: this.question.sliderStartPosition || '',
        name: 'slider_start_position',
      },
      {
        value: this.question.sliderSubmitButtonEnabled ?? false,
        name: 'slider_submit_button_enabled',
      },
      {
        value: this.question.optional ?? false,
        name: 'optional',
      },
    ];

    return (
      <>
        {
          questionProperties.map((questionProperty) => {
            // Let db set default value
            if (questionProperty.omit_if_undefined &&
                questionProperty.value === undefined) {
              return null;
            }

            if (Array.isArray(questionProperty.value)) {
              const fields = [];
              for (let i = 0; i < questionProperty.value.length; i++) {
                fields.push(
                    <input
                      name={`${this.questionContext}[${questionProperty.name}][]`}
                      type='hidden'
                      value={questionProperty.value[i]}
                      key={`${questionProperty.name}_${i}`}
                    />,
                );
              }

              return fields;
            } else {
              return (
                <input
                  name={`${this.questionContext}[${questionProperty.name}]`}
                  type='hidden'
                  value={questionProperty.value}
                  key={questionProperty.name}
                />
              );
            }
          })
        }
      </>
    );
  }

  /**
   * Renders hidden form inputs for a possible answer
   * @param { Object } possibleAnswer
   * @param { string } possibleAnswerContext - the form context
   * @return { JSX.Element } All necessary hidden inputs
   */
  renderHiddenPossibleAnswerInputs(
      possibleAnswer: Object, possibleAnswerContext: string,
  ): JSX.Element {
    const possibleAnswerProperties = [
      {
        name: 'answer_image_id',
        value: possibleAnswer.answerImageId || '',
      },
      {
        name: 'image_height',
        value: possibleAnswer.imageHeight || '',
      },
      {
        name: 'image_height_mobile',
        value: possibleAnswer.imageHeightMobile || '',
      },
      {
        name: 'image_height_tablet',
        value: possibleAnswer.imageHeightTablet || '',
      },
      {
        name: 'image_width',
        value: possibleAnswer.imageWidth || '',
      },
      {
        name: 'image_width_mobile',
        value: possibleAnswer.imageWidthMobile || '',
      },
      {
        name: 'image_width_tablet',
        value: possibleAnswer.imageWidthTablet || '',
      },
      {
        name: 'image_position_cd',
        value: possibleAnswer.imagePositionCd || '',
      },
      {
        name: 'position',
        value: possibleAnswer.position,
      },
    ];

    if (this.question.nps) {
      possibleAnswerProperties.push(
          {
            name: 'content',
            value: possibleAnswer.content,
          },
      );
    }

    if (possibleAnswer.id) {
      possibleAnswerProperties.push(
          {
            name: 'id',
            value: possibleAnswer.id,
          },
      );
    }

    if (this.question.type.value === 'multiple_choices_question' &&
      possibleAnswer != this.props.node.getLastPossibleAnswer()) {
      // Wipe next_question_ids for anything that's not last_question_id
      // This is simpler than tracking changes in question order
      possibleAnswerProperties.push(
          {
            name: 'next_question_id',
            value: '',
          },
      );
    }

    return (
      <>
        {
          possibleAnswerProperties.map((possibleAnswerProperty) => {
            return (
              <input
                name={`${possibleAnswerContext}[${possibleAnswerProperty.name}]`}
                type='hidden'
                value={possibleAnswerProperty.value}
                key={possibleAnswerProperty.name}
              />
            );
          })
        }
      </>
    );
  };

  /**
   * Renders hidden form inputs for a possible answer
   * @param { Object } possibleAnswer
   * @return { JSX.Element } The node-level options for the possible answer
   */
  renderPossibleAnswerOptions(possibleAnswer: Object): JSX.Element {
    const isSelected = this.props.node.isSelected();

    const canDelete = !this.lockStructuralChanges &&
      this.props.node.getNonDeletedPossibleAnswers().length > this.minimumNumberOfPossibleAnswers;

    if (isSelected) {
      return (
        <>
          {
            this.question.type.value === 'single_choice_question' && !this.question.nps ?
              <PossibleAnswerImageModal
                engine={this.props.engine}
                node={this.props.node}
                possibleAnswer={possibleAnswer}
                existingImageOptions={this.props.node.survey.existingImageOptions}
                readOnly={this.readOnly}
              /> :
                null
          }

          {
            canDelete ?
              <a
                href='#'
                onClick={() => this.deletePossibleAnswer(possibleAnswer)}
              >
                <img src={DeleteIcon}/>
              </a> :
                null
          }
        </>
      );
    } else {
      return null;
    }
  }

  /**
   * Renders the possible answer clone used by @hello-pangea/dnd during drag.
   * Think of it as a stripped-down version of the usual possible answer field.
   *
   * https://github.com/hello-pangea/dnd
   *
   * @param {Object} provided - see @hello-pangea/dnd docs
   * @param {Object} _snapshot - see @hello-pangea/dnd docs
   * @param {Object} rubric - see @hello-pangea/dnd docs
   * @return { JSX.Element } The possible answer
   */
  renderDraggableClone(provided, _snapshot, rubric) {
    const possibleAnswer = this.possibleAnswersByPosition().filter((possibleAnswer) => possibleAnswer.flagged_for_deletion !== true)[rubric.source.index];
    const possibleAnswerPort = this.props.node.getPossibleAnswerPort(possibleAnswer);

    return (
      <div
        {...provided.draggableProps}
        ref={provided.innerRef}
        className='possible-answer-container-clone'
      >
        {possibleAnswer.content}
        {
          possibleAnswerPort ?
            <PortWidget
              port={possibleAnswerPort}
              engine={this.props.engine}
              className={`possible-answer-port`}
            /> :
              null
        }
      </div>
    );
  }

  /**
   * Renders a possible answer.
   *
   * NOTE: When being dragged (i.e. for possible answer reordering), this will
   * not execute. renderDraggableClone will run instead, which provides a simplified
   * version.
   *
   * @param {Object} possibleAnswer - the possible answer to render
   * @return { JSX.Element } The possible answer
   */
  renderPossibleAnswer(possibleAnswer :Object): JSX.Element {
    const initialIndex = this.props.node.possibleAnswers.indexOf(possibleAnswer);

    const possibleAnswerContext =
      `${this.questionContext}[possible_answers_attributes][${initialIndex}]`;

    const possibleAnswerPort = this.props.node.getPossibleAnswerPort(possibleAnswer);
    const possibleAnswerKey = possibleAnswer.id || possibleAnswer.placeholderKey;

    if (possibleAnswer.flagged_for_deletion) {
      return (
        possibleAnswer.id ?
          <div style={{display: 'none'}} key={possibleAnswerKey}>
            <input
              name={`${possibleAnswerContext}[id]`}
              value={possibleAnswer.id}
              type='hidden'
            />
            <input
              name={`${possibleAnswerContext}[_destroy]`}
              value='1'
              type='hidden'
            />
          </div> :
            null
      );
    }

    const contextMenuId = `context_menu_${this.props.node.options.id}_${initialIndex}`;

    const contextMenuProps = {
      onContextMenu: (e) => {
        contextMenu.show(
            {
              id: contextMenuId,
              event: e,
              props: {
                port: possibleAnswerPort,
              },
            },
        );
      },
    };

    const dragDisabled = !this.props.node.isSelected() ||
      this.props.node.question.nps ||
      this.lockStructuralChanges;

    return (
      <Draggable
        key={possibleAnswerKey}
        draggableId={possibleAnswerKey + '_possible_answer_draggable'}
        index={possibleAnswer.position}
        isDragDisabled={dragDisabled}
      >
        {(provided, snapshot) => {
          return (
            <li
              className='possible-answer-container'
              key={possibleAnswerKey}
              ref={provided.innerRef}
              {...provided.draggableProps}
            >
              {
                this.renderHiddenPossibleAnswerInputs(
                    possibleAnswer,
                    possibleAnswerContext,
                )
              }

              <div className={`possible-answer-label-container ${ dragDisabled ? '' : 'drag-enabled'}`}>
                {
                  this.question.nps === true ?
                    possibleAnswer.content :
                    <>
                      {
                        dragDisabled ? null :
                          <img
                            className='handles-icon'
                            src={HandlesIcon}
                            {...provided.dragHandleProps}
                          />
                      }
                      <EditableField
                        placeholderTagName='span'
                        placeholderTagClass='possible-answer-label'
                        placeholderText={'enter possible answer text'}
                        initialContent={possibleAnswer.content}
                        inputContext={`${possibleAnswerContext}[content]`}
                        inputClass='possible-answer-content-input'
                        node={this.props.node}
                        readOnly={this.readOnly}
                      />
                      <div className='possible-answer-label-icons'>
                        { this.renderPossibleAnswerOptions(possibleAnswer) }
                      </div>
                    </>
                }
              </div>

              {
                possibleAnswerPort ?
                <PortWidget
                  port={possibleAnswerPort}
                  engine={this.props.engine}
                  className={`possible-answer-port target ${this.props.node.hidePorts ? 'hidden' : null}`}
                >
                  <div
                    className='possible-answer-port'
                    style={{
                      backgroundColor: possibleAnswerPort.currentColor()
                    }}
                    {...(this.lockStructuralChanges ? {} : contextMenuProps) }
                  >
                  </div>

                  {
                    Object.values(possibleAnswerPort.links).length > 0 ?
                      <span
                        className='fake-starting-line'
                        style={{ borderColor: possibleAnswerPort.currentColor() }}
                      >
                      </span> :
                        null
                  }

                  {
                    ReactDOM.createPortal(
                        <Menu id={contextMenuId}>
                          {
                            this.props.engine.getModel().getNodes().filter((node) => {
                              return node !== this.props.node && node instanceof QuestionNodeModel;
                            }).map((node) => {
                              const port = node.getQuestionInputPort();

                              return (
                                <Item
                                  id='add'
                                  key={port.options.id}
                                  onClick={this.handleContextMenuItemClick}
                                  data={{
                                    selectedQuestionPort: port,
                                  }}
                                  disabled={possibleAnswerPort.targetPort() === port}
                                >
                                  {node.question.content}
                                </Item>
                              );
                            })
                          }
                          <Separator />
                          <Item
                            id='remove'
                            onClick={this.handleContextMenuItemClick}
                            hidden={!possibleAnswerPort.targetPort()}
                          >
                            No Connection
                          </Item>
                        </Menu>,
                        document.body,
                    )
                  }
                </PortWidget> :
                  null
              }
            </li>
          )}
        }
      </Draggable>
    );
  }

  /**
   * Returns a list of possible answers sorted by position
   * @return { Array } an array of possible answers
   */
  possibleAnswersByPosition() {
    return this.props.node.possibleAnswers.slice().sort((a, b) => {
      return a.position - b.position;
    });
  }

  /**
   * Handles a click on a right-click context menu's items
   * See https://fkhadra.github.io/react-contexify/api/item#ItemHandler
   * @param {Event} event
   * @param {Object} props
   * @param {Object} data
   */
  handleContextMenuItemClick({id, event, props, data}) {
    switch (id) {
      case 'remove':
        props.port.removeLinks();

        this.props.engine.repaintCanvas();
        break;
      case 'add':
        const startPort = props.port;
        const endPort = data.selectedQuestionPort;

        startPort.removeLinks();

        const newLink = startPort.link(endPort);

        this.props.engine.getModel().addLink(newLink);

        // Necessary for the ports' new positions in the DOM
        // to be acknowledged by the canvas
        // Without this the new link will be drawn with a bad offset
        startPort.reportedPosition = false;
        endPort.reportedPosition = false;

        this.props.engine.repaintCanvas();
        break;
    }
  }

  /**
   * Renders the QuestionNodeWidget
   * @return { QuestionNodeWidget }
   */
  render() {
    const isSelected = this.props.node.isSelected();
    const questionColors = {};

    const node = this.props.node;
    const questionInPort = node.getQuestionInputPort();
    const questionOutPort = node.getQuestionOutputPort();
    const possibleAnswerPorts = node.getPossibleAnswerPorts();

    const outPorts = possibleAnswerPorts;
    if (questionOutPort) {
      outPorts.push(questionOutPort);
    }

    let colorIndex = 0;
    outPorts.forEach((outPort) => {
      const targetPort = outPort.targetPort();

      if (targetPort) {
        const nextQuestionPosition = targetPort.data.position;
        if (questionColors[nextQuestionPosition] === undefined) {
          questionColors[nextQuestionPosition] = this.colorPalette[colorIndex];
          colorIndex++;
          if (colorIndex >= this.colorPalette.length) {
            colorIndex = 0;
          }
        }

        outPort.setActiveColor(questionColors[nextQuestionPosition]);

        Object.values(outPort.links).forEach((link) => {
          link.setActiveColor(questionColors[nextQuestionPosition]);
          link.setUseActiveColor(isSelected);
          link.targetPort.setActiveColor(questionColors[nextQuestionPosition]);
        });
      }
    });

    const questionContentToDisplay = () => {
      if (this.question.type.value === 'custom_content_question') {
        return `${this.question.content} (not shown to end users)`;
      } else {
        return this.question.content;
      }
    };

    const optionalOption = () => {
      if (!this.readOnly && this.props.engine.getModel().allAtOnceMode) {
        if (isSelected) {
          const inputId = `${this.question.id}_optional`;

          return (
            <div className='optional-edit-container'>
              <label
                className='optional-label editable'
                htmlFor={inputId}
              >
                Optional
              </label>
              <input
                id={inputId}
                type='checkbox'
                value={this.question.optional}
                checked={this.question.optional}
                onChange={(e) => {
                  const newValue = e.target.checked;

                  this.props.node.updateQuestion({optional: newValue});
                  this.props.engine.repaintCanvas();
                }}
              />
            </div>
          );
        } else if (this.question.optional) {
          return <h3 className='optional-summary'>(Optional)</h3>;
        } else {
          return null;
        }
      } else {
        return null;
      }
    };

    return (
      <ResizableBox width={385} height={Infinity}
        minConstraints={[385, 200]} maxConstraints={[1000, 1000]}
        className='box'
        resizeHandles={['ne']}
        axis='x'
        onResize={() => node.setLocked(true)}
        onResizeStop={() => node.setLocked(false)}
      >
        <div className={`node-contents question-node${ isSelected ? ' selected' : '' }`}>
          <div className='node-body'>
            <PortWidget
              style={{ backgroundColor: questionInPort.currentColor() }}
              port={questionInPort}
              engine={this.props.engine}
              className={`question-port in ${questionInPort.linkProximate ? 'link-proximate' : ''} ${node.hidePorts ? 'hidden' : ''}`}
            />

            { this.renderHiddenInputs() }

            <input
              name={`${this.questionContext}[diagram_properties_attributes][id]`}
              type='hidden'
              value={node.persistentDiagramProperties.id}
            />

            <div className='node-header-container'>
              <h2 className='node-type-label'>{this.question.type.label}</h2>
              { optionalOption() }
            </div>

            <EditableField
              placeholderTagName='h1'
              placeholderTagClass='question-content-label'
              placeholderText={'enter question text'}
              contentToDisplay={questionContentToDisplay()}
              initialContent={this.question.content}
              inputContext={`${this.questionContext}[content]`}
              inputClass='question-content-input'
              node={node}
              onUpdate={(newContent) => {
                this.props.node.updateQuestion({content: newContent});
                this.props.engine.repaintCanvas();
              }}
              readOnly={this.readOnly}
            />

            <DragDropContext
              onDragEnd={(dragUpdateObj) => {
                if (dragUpdateObj.reason === 'DROP') {
                  const sourceIndex = dragUpdateObj.source.index;
                  const destinationIndex = dragUpdateObj.destination &&
                      dragUpdateObj.destination.index;

                  if (destinationIndex !== undefined && sourceIndex != destinationIndex) {
                    this.props.node.updatePosition(sourceIndex, destinationIndex);
                  }
                }
              }}
            >
              <Droppable
                droppableId="possibleAnswerDroppable"
                direction="vertical"
                getContainerForClone={() => document.getElementsByClassName('canvas-widget')[0]}
                renderClone={this.renderDraggableClone}
              >
                {(provided, snapshot) => (
                  <ul
                    {...provided.droppableProps}
                    ref={provided.innerRef}
                    className='possible-answers-list'
                  >
                    {
                      this.possibleAnswersByPosition().map((possibleAnswer) => {
                        return this.renderPossibleAnswer(possibleAnswer);
                      })
                    }
                    {provided.placeholder}
                  </ul>
                )}
              </Droppable>
            </DragDropContext>

            {
              questionOutPort ?
                <PortWidget
                  style={{ backgroundColor: questionOutPort.currentColor() }}
                  port={questionOutPort}
                  engine={this.props.engine}
                  className={`question-port out ${node.hidePorts ? 'hidden' : ''}`}
                /> :
                  null
            }

          </div>
          { isSelected ? this.renderFooter() : null }
        </div>
      </ResizableBox>
    );
  }
}
