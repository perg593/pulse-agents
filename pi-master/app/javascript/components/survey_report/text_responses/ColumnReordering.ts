// A column's index with invisible columns taken into consideration
const fullspaceIndex = (fullColumnOrder :string[], columnId :string) => {
  return fullColumnOrder.indexOf(columnId);
};

/**
 * Determines the new column order.
 *
 * The columns that the user can drag and drop is not the full set
 * of columns. Some columns may have their visibility toggled, or they
 * may not be draggable/droppable. We must interpret the source and destination
 * indices in the context of the full column array.
 *
 * @param {string[]} fullColumnOrder
 * @param {Array} visibleColumns
 * @param {string} sourceColumnId
 * @param {number} destinationIndex
 *
 * @return {string[]} The new column order
 **/
function newColumnOrder(
    fullColumnOrder :string[],
    visibleColumns :string[],
    sourceColumnId :string,
    destinationIndex :number,
) {
  const fullSpaceSourceIndex = fullspaceIndex(fullColumnOrder, sourceColumnId);

  const destinationColumn = visibleColumns[destinationIndex];

  const fullSpaceDestinationIndex = fullspaceIndex(fullColumnOrder, destinationColumn.id);

  const newColumnOrder = [...fullColumnOrder];
  newColumnOrder.splice(fullSpaceSourceIndex, 1);
  newColumnOrder.splice(fullSpaceDestinationIndex, 0, sourceColumnId);

  return newColumnOrder;
}

export {newColumnOrder};
