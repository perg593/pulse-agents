import {
  DefaultNodeModel, NodeModelGenerics, PortModelAlignment,
} from '@projectstorm/react-diagrams';

import {QuestionPortModel} from './QuestionPortModel';

export interface QuestionNodeModelGenerics {
  PORT: QuestionPortModel;
}

/**
 * The data model representing everything in a QuestionNode (aka Question Card)
*/
export class QuestionNodeModel
  extends DefaultNodeModel<NodeModelGenerics & QuestionNodeModelGenerics> {
  question: Object;
  possibleAnswers: Object[];
  survey: Object;
  persistentDiagramProperties: Object;
  dirty: boolean;
  hidePorts: boolean;

  /**
   * Initializes the QuestionNodeModel
   * @param { Object } question - the object containing question data
   * @param { Object } possibleAnswers - an array of possible answer data
   * @param { Object } survey - the object containing survey data
   * @param { Object } persistentDiagramProperties - diagram settings that
   *   are stored in the db. (e.g. node position)
  */
  constructor(
      question: object,
      possibleAnswers: object = {},
      survey: object,
      persistentDiagramProperties: Object,
      hidePorts: boolean,
  ) {
    super({
      type: 'question',
    });

    this.question = question;
    this.possibleAnswers = possibleAnswers;
    this.survey = survey;

    this.addPort(
        new QuestionPortModel(PortModelAlignment.LEFT,
            true,
            null,
            'questionInPort',
            this.question,
        ),
    );

    const numPossibleAnswers = this.possibleAnswers.length;
    for (let i = 0; i < numPossibleAnswers; i++) {
      const possibleAnswer = this.possibleAnswers[i];

      if (possibleAnswer.nextQuestionAllowed) {
        this.addPort(
            new QuestionPortModel(
                PortModelAlignment.RIGHT,
                false,
                this.possibleAnswerPortName(possibleAnswer.position),
                'possibleAnswerPort',
                possibleAnswer,
            ),
        );
      }
    }

    if (this.question.nextQuestionAllowed) {
      this.addPort(
          new QuestionPortModel(
              PortModelAlignment.BOTTOM,
              false,
              null,
              'questionOutPort',
              this.question,
          ),
      );
    }

    this.persistentDiagramProperties = persistentDiagramProperties;
    this.setPosition(...this.persistentDiagramProperties.position);

    this.hidePorts = hidePorts;
    this.dirty = false;
  }

  /**
   * Updates (mutates) our internal question object
   * @param { Object } newValues - the object containing new question data
   */
  updateQuestion(newValues: Object) {
    for (const key in newValues) {
      this.question[key] = newValues[key];
    }

    this.makeDirty();
  }

  /**
   * Finds the possible answer in our collection matching the
   * provided possible answer's identifier
   * @param { Object } possibleAnswer - the object we want to find
   * @return { QuestionPortModel }
   */
  findPossibleAnswer(possibleAnswer: Object) {
    const possibleAnswerIndex = this.findPossibleAnswerIndex(possibleAnswer);

    return this.possibleAnswers[possibleAnswerIndex];
  }

  /**
   * Finds the index of the possible answer in our collection matching the
   * provided possible answer's identifier
   * @param { Object } possibleAnswer - the object we want to find
   * @return { number } the index of the possible answer in this.possibleAnswers
   */
  findPossibleAnswerIndex(possibleAnswer: Object) {
    return this.possibleAnswers.findIndex((candidatePossibleAnswer) => {
      if (candidatePossibleAnswer.id !== undefined &&
          possibleAnswer.id !== undefined) {
        return candidatePossibleAnswer.id === possibleAnswer.id;
      } else if (candidatePossibleAnswer.placeholderKey !== undefined &&
                 possibleAnswer.placeholderKey !== undefined) {
        return candidatePossibleAnswer.placeholderKey === possibleAnswer.placeholderKey;
      } else {
        return false;
      }
    });
  }

  /**
   * Updates the possible answer at the given position to the new position and
   * shifts all possible answers in between.
   * @param { bigint } sourcePosition - the original visual index
   * @param { bigint } destinationPosition - the target visual index
   */
  updatePosition(sourcePosition: bigint, destinationPosition: bigint) {
    const numPossibleAnswers = this.getNonDeletedPossibleAnswers().length;
    const oldLastPossibleAnswer = this.getLastPossibleAnswer();
    const possibleAnswerThatMoved = this.possibleAnswers.find(
        (possibleAnswer) => possibleAnswer.position === sourcePosition,
    );

    // Shift all possible answers between the source and destination
    // i.e. moving up in the list
    if (destinationPosition < sourcePosition) {
      this.possibleAnswers.filter(
          (possibleAnswer) => possibleAnswer.position >= destinationPosition &&
              possibleAnswer.position < sourcePosition,
      ).forEach(
          (possibleAnswer) => this.updatePossibleAnswer(
              possibleAnswer, {position: possibleAnswer.position + 1},
          ),
      );
    // i.e. moving down in the list
    } else {
      this.possibleAnswers.filter(
          (possibleAnswer) => possibleAnswer.position <= destinationPosition &&
              possibleAnswer.position > sourcePosition,
      ).forEach(
          (possibleAnswer) => this.updatePossibleAnswer(
              possibleAnswer, {position: possibleAnswer.position - 1},
          ),
      );
    }

    // Shift the possible answer that was dragged and dropped
    this.updatePossibleAnswer(
        possibleAnswerThatMoved, {position: destinationPosition},
    );

    const lastQuestionMoved = sourcePosition === numPossibleAnswers - 1 ||
      destinationPosition === numPossibleAnswers - 1;

    if (lastQuestionMoved &&
        this.question.type.value === 'multiple_choices_question') {

      const port = this.getPossibleAnswerPort(oldLastPossibleAnswer);
      const newLastPossibleAnswer = this.getLastPossibleAnswer();

      port.data = newLastPossibleAnswer;
    }
  }

  /**
   * Updates one of our internal possible answer objects
   * @param { Object } possibleAnswer - the object with the ID we want to update
   * @param { Object } newValues - the object containing
   *   new possible answer data
   */
  updatePossibleAnswer(possibleAnswer: Object, newValues: Object) {
    // TODO: make this work for newly-created (i.e. unsaved) PAs
    const ourPossibleAnswer = this.findPossibleAnswer(possibleAnswer);
    const possibleAnswerIndex = this.possibleAnswers.indexOf(ourPossibleAnswer);

    const newPossibleAnswers = [...this.possibleAnswers];

    newPossibleAnswers[possibleAnswerIndex] = {
      ...ourPossibleAnswer,
      ...newValues,
    };

    this.possibleAnswers = newPossibleAnswers;
  }

  /**
   * Removes the provided possible answer from our array
   * @param { Object } possibleAnswer - the possible answer to remove
  */
  removePossibleAnswer(possibleAnswer: Object) {
    const ourPossibleAnswer = this.findPossibleAnswer(possibleAnswer);
    const removingLast = this.getLastPossibleAnswer() === ourPossibleAnswer;

    // Don't flag possible answers that aren't saved in the db
    if (ourPossibleAnswer.id === undefined) {
      this.possibleAnswers.splice(
          this.possibleAnswers.indexOf(ourPossibleAnswer),
          1,
      );
    } else {
      ourPossibleAnswer.flagged_for_deletion = true;
    }

    // All possible answers with a higher position value must have their
    // position decremented by one
    this.getNonDeletedPossibleAnswers().forEach((remainingPossibleAnswer) => {
      if (remainingPossibleAnswer.position > ourPossibleAnswer.position) {
        const newValues = {position: remainingPossibleAnswer.position - 1};
        this.updatePossibleAnswer(remainingPossibleAnswer, newValues);
      }
    });

    const portToRemove = this.getPossibleAnswerPort(possibleAnswer);

    // Multiple choice questions need to retain a port
    // for the last possible answer
    if (removingLast &&
          this.question.type.value === 'multiple_choices_question') {

      const lastPossibleAnswer = this.getLastPossibleAnswer();
      portToRemove.data = lastPossibleAnswer;
    } else if (portToRemove) {
      this.removePortAndLinks(portToRemove);
    }
  }

  /**
   * Adds a new possible answer image option
   * @param { Object } newImageOption - the option to add
  */
  addPossibleAnswerImageOption(newImageOption: Object) {
    this.survey.existingImageOptions.push(newImageOption);
  }

  /**
   * Adds the provided possible answer to our model and diagram
   * @param { Object } newPossibleAnswer - the possible answer to add
  */
  addPossibleAnswer(newPossibleAnswer: Object) {
    this.possibleAnswers.push(newPossibleAnswer);

    if (newPossibleAnswer.nextQuestionAllowed) {
      if (this.question.type.value === 'multiple_choices_question') {
        // there should be exactly one -- the final possible answer's port
        const port = this.getPossibleAnswerPorts()[0];
        port.data = newPossibleAnswer;
      } else {
          const portName = this.possibleAnswerPortName(newPossibleAnswer.position);

          this.addPort(
              new QuestionPortModel(
                  PortModelAlignment.RIGHT,
                  false,
                  portName,
                  'possibleAnswerPort',
                  newPossibleAnswer,
              ),
          );
      }
    }
  }

  /**
   * Remove the provided port and all of its links from the diagram
   * @param { QuestionPortModel } port - the port you'd like to remove
  */
  removePortAndLinks(port: DefaultPortModel): void {
    port.removeLinks();
    this.removePort(port);
  }

  /**
   * Returns the possible answers that have not been flagged for deletion
   * @return { Array } an array of possible answers
  */
  getNonDeletedPossibleAnswers() {
    return this.possibleAnswers.filter((possibleAnswer) => {
      return possibleAnswer.flagged_for_deletion !== true;
    });
  }

  /**
   * Returns the port associated with the possible answer
   * @param { Object } possibleAnswer - the possible answer who's port you want
   * @return { QuestionPortModel }
  */
  getPossibleAnswerPort(possibleAnswer: Object) {
    return this.getPossibleAnswerPorts().find((port) => {
      if (port.data.id !== undefined &&
          possibleAnswer.id !== undefined) {
        return port.data.id === possibleAnswer.id;
      } else if (port.data.placeholderKey !== undefined &&
                 possibleAnswer.placeholderKey !== undefined) {
        return port.data.placeholderKey === possibleAnswer.placeholderKey;
      } else {
        return false;
      }
    });
  }

  /**
   * Returns all possible answer ports
   * @return { Array } an array of possible answer ports
   */
  getPossibleAnswerPorts() {
    return this.portsOut.filter((port) => {
      return port.options.type === 'possibleAnswerPort';
    });
  }

  /**
   * Returns last non deleted possible answer.
   * @return { Object } the last possible answer object
   */
  getLastPossibleAnswer() {
    const nonDeletedPossibleAnswers = this.getNonDeletedPossibleAnswers();

    return nonDeletedPossibleAnswers.find((possibleAnswer) => {
      return possibleAnswer.position === nonDeletedPossibleAnswers.length - 1;
    });
  }

  /**
   * Returns the port that other cards point to
   * @return { QuestionPortModel }
  */
  getQuestionInputPort() {
    return this.getPort(PortModelAlignment.LEFT);
  }

  /**
   * Returns the port that leads to the next question for
   * question-level routing
   * @return { QuestionPortModel }
  */
  getQuestionOutputPort() {
    return this.getPort(PortModelAlignment.BOTTOM);
  }

  /**
   * Forces a re-render by toggling a serialized value
   */
  makeDirty() {
    this.dirty = true;
  }

  /**
   * Reset dirty to false
   * @return { QuestionNodeModel }
   */
  cleanUp() {
    this.dirty = false;
    return this;
  }

  /**
   * Serializes the model
   * @return { Object }
  */
  serialize() {
    return ({
      ...super.serialize(),
      question: this.question,
      possibleAnswers: this.possibleAnswers,
      dirty: this.dirty,
      hidePorts: this.hidePorts,
    });
  }

  /**
   * Deserializes the model
   * @param { Object } data
   * @param { DiagramEngine } engine
  */
  deSerialize(data: any, engine: DiagramEngine) {
    super.deSerialize(data, engine);
  }

  /**
   * Returns a property's default value
   *
   * @param { string } property
   * @return { any } the default value.
   */
  defaultValue(property) {
    switch (property) {
      case 'emptyErrorText':
        if (['single_choice_question', 'multiple_choices_question', 'free_text_question', 'slider_question'].includes(this.question.type.value)) {
          return 'Required.';
        }
      case 'errorText':
        if (this.question.type.value === 'free_text_question') {
          return 'Oops, looks like you are trying to submit personal information!';
        }
      case 'singleChoiceDefaultLabel':
        if (this.question.type.value === 'single_choice_question') {
          return 'Select an option';
        }
      case 'submitLabel':
        return 'Submit';
      case 'additionalContentPosition':
        if (['single_choice_question', 'multiple_choices_question', 'free_text_question'].includes(this.question.type.value)) {
          return 'header';
        }
      case 'height':
        if (this.question.type.value === 'free_text_question') {
          return 1;
        }
      case 'maxLength':
        if (this.question.type.value === 'free_text_question') {
          return 141;
        }
      case 'maximumSelection':
        if (this.question.type.value === 'multiple_choices_question') {
          return this.possibleAnswers.length;
        }
      default:
        console.debug('unrecognized property', property);
        return '';
    }
  }

  private

  /**
   * Returns the name of the possible answer port at the given position
   * @param { number } position
   * @return { string } port name
  */
  possibleAnswerPortName(position: bigint) {
    return PortModelAlignment.RIGHT + '_' + position;
  }
}
