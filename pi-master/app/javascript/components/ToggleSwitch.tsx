import React from 'react';

interface ToggleSwitchProps {
  defaultChecked: boolean
  onChange: (event: ChangeEvent<HTMLInputElement>) => any;
};

/**
 * A simple toggle switch.
 * It looks like
 *
 * @param {ToggleSwitchProps} props -- see interface above
 * @return {JSX.Element}
 **/
function ToggleSwitch(props: ToggleSwitchProps) {
  return (
    <label className="console-switch">
      <input
        type='checkbox'
        defaultChecked={props.defaultChecked}
        onChange={(e) => {
          props.onChange(e);
        }}
      />
      <span className="console-slider"></span>
    </label>
  );
}

export default ToggleSwitch;
