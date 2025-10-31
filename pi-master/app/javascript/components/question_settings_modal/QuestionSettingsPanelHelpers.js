/**
 * A wrapper for question updates used by all modal panels.
 *
 * @param { Function } setQuestionProperties
 * @param { Object } questionProperties
 * @param { Object } node -- the react-diagrams question node
 * @param { Object } newObject -- The object containing updates
 */
function updateLocalAndNodeProperties(
    setQuestionProperties, questionProperties,
    node, newObject,
) {
  setQuestionProperties(
      {
        ...questionProperties,
        ...newObject,
      },
  );

  node.updateQuestion(newObject);
}

export {updateLocalAndNodeProperties};
