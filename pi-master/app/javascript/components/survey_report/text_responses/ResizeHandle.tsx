import React from 'react';

interface ResizeHandleProps {
  header: Object, // react-table header
};

/**
 * A handle for the pointer to grab to resize a column
 *
 * @param {ResizeHandleProps} props
 * @return {JSX.Element} The handle
 **/
function ResizeHandle(props: ResizeHandleProps) {
  const columnIsResizable = !props.header.column.columnDef.meta.resizeDisabled ?? true;
  const isResizing = props.header.column.getIsResizing();

  if (columnIsResizable) {
    return (
      <div
        onMouseDown={props.header.getResizeHandler()}
        className={`resizer ${ isResizing ? 'isResizing' : '' }`}
      >
      </div>
    );
  } else {
    return null;
  }
}

export default ResizeHandle;
