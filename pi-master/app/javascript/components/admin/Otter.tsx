import React from 'react';

import classNames from 'classnames';

interface OtterProps {
  image: string
  title: string
  additionalClasses?: string
}

/**
 * A very serious visual element
 *
 * @param {OtterProps} props
 * @return {JSX.Element}
 **/
function Otter(props: OtterProps) {
  return (
    <div
      className={classNames('very-serious-vignette', props.additionalClasses)}
      title={props.title}
      style={{backgroundImage: `url(${props.image})`}}
    >
    </div>
  );
}

export default Otter;
