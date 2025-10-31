import React from 'react';

import ColorPickerPopup from '../ColorPickerPopup';

import {TagOption} from './Types';
interface TagEntryProps {
    tag: TagOption
    updateTagAndAppliedTags: Function
    deleteTagAndAppliedTags: Function
};

/**
 * A tag displayed within the TagManager's list
 *
 * @param {TagEntryProps} props
 * @return {JSX.Element}
 **/
function TagEntry(props: TagEntryProps) {
  const [showColorPicker, setShowColorPicker] = React.useState(false);

  return (
    <>
      {
         showColorPicker ?
           <ColorPickerPopup
             legend={[{
               id: props.tag.id,
               name: props.tag.text,
               color: props.tag.color,
               colorUpdateUrl: '',
             }]}
             updateColor={(_selectedLegendId, newColor, _colorUpdateUrl) => {
               props.updateTagAndAppliedTags(props.tag.id, '', newColor);
               setShowColorPicker(false);
             }}
             hideColorPicker={() => setShowColorPicker(false)}
           /> : null
      }
      <li className='tag' key={props.tag.id}>
        <button
          className='color'
          style={{backgroundColor: props.tag.color}}
          onClick={() => setShowColorPicker(true)}
        ></button>
        <input
          className='name'
          defaultValue={props.tag.text}
          onKeyDown={
            (event) => {
              if (event.key !== 'Enter') return;

              const updatedName = event.target.value;
              if (props.tag.text === updatedName) return;

              props.updateTagAndAppliedTags(props.tag.id, updatedName);
            }
          }
        />
        <button
          className='delete'
          onClick={() => {
            if (confirm('Are you sure?') == true) {
              props.deleteTagAndAppliedTags(props.tag.id);
            }
          }}
        >
          <span>×</span>
        </button>
      </li>
    </>
  );
}

export default TagEntry;
