import React from 'react';

/**
 * A react component that updates state every x ms,
 * effectively "batching" keyboard input
 *
 * @return {HTMLInputElement}
 **/
function DebouncedInput({
  value: initialValue,
  onChange,
  debounce = 500,
  ...props
}: {
  value: string | number
  onChange: (value: string | number) => void
  debounce?: number
} & Omit<React.InputHTMLAttributes<HTMLInputElement>, 'onChange'>) {
  const [value, setValue] = React.useState(initialValue);
  const timeoutRef = React.useRef<number>();

  const clearCurrentTimeout = () => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
  };

  React.useEffect(() => {
    setValue(initialValue);
  }, [initialValue]);

  React.useEffect(() => {
    // Clear existing timeout
    clearCurrentTimeout();

    // Set new timeout that resets on every keystroke
    timeoutRef.current = setTimeout(() => {
      if (initialValue != value) {
        onChange(value);
      }
    }, debounce);

    // Cleanup function
    return clearCurrentTimeout;
  }, [value, debounce, initialValue, onChange]);

  return (
    <input
      {...props}
      value={value}
      onChange={(e) => setValue(e.target.value)}
    />
  );
}

export default DebouncedInput;
