import React from 'react';

/**
 * A checkbox with checked, unchecked, and partially-checked states
 * @return {HTMLInputElement}
 **/
function IndeterminateCheckbox({
  indeterminate,
  className = '',
  ...rest
}: HTMLProps<HTMLInputElement>) {
  const ref = React.useRef<HTMLInputElement>(null!);

  React.useEffect(() => {
    if (typeof indeterminate === 'boolean') {
      ref.current.indeterminate = !rest.checked && indeterminate;
    }
  }, [ref, indeterminate]);

  return (
    <input
      type='checkbox'
      ref={ref}
      className={className}
      {...rest}
    />
  );
}

export default IndeterminateCheckbox;
