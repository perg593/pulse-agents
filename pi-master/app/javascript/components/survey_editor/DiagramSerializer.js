/**
 * Adds an input to the form. Normally diagram widgets handle this, but there
 * are some things they can't easily handle, like link destruction.
 *
 * TODO: Cache form object
 *
 * @param { string } name - the name of the attribute
 * @param { string } value - the value of the attribute
 */
const addInputToForm = (name, value) => {
  const form = $('#canvas_form');

  $('<input />').attr({
    type: 'hidden',
    name: name,
    value: value,
  }).appendTo(form);
};

/**
 * Removes all inputs with the matching name from the form.
 *
 * @param { string } name - the name of the input attribute(s)
 */
const removeInputsFromForm = (name) => {
  const selector = `#canvas_form input[name='${name}']`;
  const inputs = document.querySelectorAll(selector);

  for (const input of inputs) {
    input.remove();
  }
};

/**
 * Represents a route between a possible answer and a question
 */
class PossibleAnswerRoute {
  /**
   * @param { number } nodeIndex
   * @param { number } possibleAnswerIndex
   * @param { number } nextQuestionId
   * @param { string } ephemeralNextQuestionId
   */
  constructor(nodeIndex, possibleAnswerIndex,
      nextQuestionId, ephemeralNextQuestionId) {
    this.nodeIndex = nodeIndex;
    this.possibleAnswerIndex = possibleAnswerIndex;
    this.nextQuestionId = nextQuestionId;
    this.ephemeralNextQuestionId = ephemeralNextQuestionId;
  }
}

/**
 * Converts all possible answer routing information into
 * an array of PossibleAnswerRoutes
 *
 * @param { Array } questionNodes
 * @return { Array } PossibleAnswerRoute
 */
function getPossibleAnswerRouting(questionNodes) {
  const possibleAnswerRouting = [];

  questionNodes.forEach((node) => {
    const ephemeralIdName = `survey[questions_attributes][${node.question.index}][ephemeral_id]`;
    const ephemeralIdValue = generateEphemeralQuestionId(node.question.position);
    addInputToForm(ephemeralIdName, ephemeralIdValue);

    possibleAnswerRouting.push(node.getPossibleAnswerPorts().map((sourcePort, portIndex) => {
      let nextQuestionId = null;
      let ephemeralNextQuestionId = null;

      const targetPort = sourcePort.targetPort();

      if (targetPort) {
        const nextQuestion = targetPort.parent.question;
        nextQuestionId = nextQuestion.id;

        if (nextQuestionId === null) {
          // no ID means the link is to a new question
          ephemeralNextQuestionId = generateEphemeralQuestionId(nextQuestion.position);
        }
      }

      const possibleAnswerIndex = node.findPossibleAnswerIndex(sourcePort.data);

      // TODO: Abort the AJAX call and saving in general
      if (possibleAnswerIndex == -1) {
        console.error('failed to locate possible answer!');
      }

      return new PossibleAnswerRoute(
          node.question.index, possibleAnswerIndex,
          nextQuestionId, ephemeralNextQuestionId,
      );
    }));
  });

  return possibleAnswerRouting.flat(1);
}

/**
 * Adds possible answer routing to the form
 * @param { Array } possibleAnswerRouting -- PossibleAnswerRoute
 */
function addPossibleAnswerRoutingToForm(possibleAnswerRouting) {
  possibleAnswerRouting.forEach((entry) => {
    const possibleAnswerIndex = entry.possibleAnswerIndex;

    const possibleAnswerContext = `survey[questions_attributes][${entry.nodeIndex}][possible_answers_attributes][${possibleAnswerIndex}]`;

    const nextQuestionIdName = `${possibleAnswerContext}[next_question_id]`;
    const nextQuestionIdValue = entry.nextQuestionId;
    addInputToForm(nextQuestionIdName, nextQuestionIdValue);

    if (entry.ephemeralNextQuestionId) {
      const inputName = `${possibleAnswerContext}[ephemeral_next_question_id]`;
      const inputValue = entry.ephemeralNextQuestionId;
      addInputToForm(inputName, inputValue);
    }
  });
}

/**
 * Represents a route from one question to another
 */
class QuestionRoute {
  /**
   * @param { number } nodeIndex
   * @param { number } nextQuestionColumn
   * @param { number } nextQuestionId
   * @param { string } ephemeralNextQuestionId
   */
  constructor(nodeIndex, nextQuestionColumn,
      nextQuestionId, ephemeralNextQuestionId) {
    this.nodeIndex = nodeIndex;
    this.nextQuestionColumn = nextQuestionColumn;
    this.nextQuestionId = nextQuestionId;
    this.ephemeralNextQuestionId = ephemeralNextQuestionId;
  }
}

/**
 * Generates serialized question routing structures
 * @param { Array } questionNodes -- Array of QuestionNodeModels
 * @return { Array } an array of QuestionRoutes
 */
function getQuestionRouting(questionNodes) {
  const questionRoutes = [];

  questionNodes.forEach((node) => {
    const nextQuestionColumn = node.question.nextQuestionColumn;

    if (nextQuestionColumn === null || nextQuestionColumn === undefined) {
      return null;
    }

    const sourcePort = node.getQuestionOutputPort();

    let nextQuestionId = null;
    let ephemeralNextQuestionId = null;

    if (sourcePort) {
      const targetPort = sourcePort.targetPort();

      if (targetPort) {
        const nextQuestion = targetPort.parent.question;
        nextQuestionId = nextQuestion.id;

        if (nextQuestionId === null) {
          ephemeralNextQuestionId = `ephemeral_question_id_${nextQuestion.position}`;
        }
      }
    }

    questionRoutes.push(new QuestionRoute(
        node.question.index, nextQuestionColumn,
        nextQuestionId, ephemeralNextQuestionId,
    ));
  });

  return questionRoutes;
}

/**
 * Adds question routing to the form
 * @param { Array } questionRoutes -- QuestionRoutes
 */
function addQuestionRoutingToForm(questionRoutes) {
  questionRoutes.forEach((entry) => {
    const questionContext = `survey[questions_attributes][${entry.nodeIndex}]`;

    const columnName = entry.nextQuestionColumn;
    addInputToForm(`${questionContext}[${columnName}]`, entry.nextQuestionId);

    if (entry.ephemeralNextQuestionId !== null) {
      addInputToForm(`${questionContext}[ephemeral_${columnName}]`, entry.ephemeralNextQuestionId);
    }
  });
}

/**
 * Generates a unique question ID to help identify new questions.
 *
 * TODO: Find a more stable way to generate these
 * Maybe using Date.now, or a random number
 * @param { number } questionPosition - the position of the question
 * @return { string } the ephemeral (short-lived, not stored in db) question ID
*/
function generateEphemeralQuestionId(questionPosition) {
  return `ephemeral_question_id_${questionPosition}`;
}

/**
 * Adds all cards' positions (i.e. [x,y] coordinates) to the form
 * @param { DiagramModel } diagramModel -- react-diagrams model
 */
function addCardPositionsToForm(diagramModel) {
  // Store positon data for every card in the diagram
  if (!diagramModel.allAtOnceMode) {
    diagramModel.getNodes().forEach((node) => {
      let inputContext = null;

      switch (node.options.type) {
        case 'question':
          inputContext = `survey[questions_attributes][${node.question.index}][diagram_properties_attributes][position][]`;
          break;
        case 'invitation':
          inputContext = `survey[invitation_diagram_properties_attributes][position][]`;
          break;
        case 'thankYou':
          inputContext = `survey[thank_you_diagram_properties_attributes][position][]`;
          break;
        default:
          // TODO: Abort save
          console.debug('Unrecognized node type', node.options.type);
      }

      if (inputContext) {
        removeInputsFromForm(inputContext);

        addInputToForm(inputContext, node.position.x);
        addInputToForm(inputContext, node.position.y);
      }
    });
  }
}

/**
 * Serializes the diagram's routing and card positions to the form
 * @param { CustomDiagramModel } diagramModel -- react-diagrams model
 */
function serializeToForm(diagramModel) {
  const questionNodes = diagramModel.getQuestionNodes();

  const possibleAnswerRouting = getPossibleAnswerRouting(questionNodes);
  addPossibleAnswerRoutingToForm(possibleAnswerRouting);

  const questionRouting = getQuestionRouting(questionNodes);
  addQuestionRoutingToForm(questionRouting);

  addCardPositionsToForm(diagramModel);
}

export {serializeToForm};
