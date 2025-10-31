import React from 'react';

import TagEntry from './TagEntry';
import Spinner from '../../Spinner';
import SettingsIcon from '../SettingsIcon';

import SparklesIcon from '../../../images/sparkles.svg';
import AiTagRecommendation from './AiTagRecommendation';

import {TagOption} from './Types';
interface TagManagerProps {
    questionId: number
    tags: TagOption[]
    setTags: Function
    updateTagAndAppliedTags: Function
    deleteTagAndAppliedTags: Function
    closeTagManager: Function
    aiTagRecommendationEnabled: boolean
};

/**
 * A modal that allows to create/edit/delete tags
 *
 * @param {TagEntryProps} props
 * @return {JSX.Element}
 **/
function TagManager(props: TagManagerProps) {
  const [showNewTagInput, setShowNewTagInput] = React.useState(false);
  const [loadingAiTagRecommendations, setLoadingAiTagRecommendations] = React.useState(false);
  const [aiTagRecommendations, setAiTagRecommendations] = React.useState([]);

  /**
   * Create a tag with a passed name
   *
   * @param { Text } newTagName - The name of a new tag
   **/
  function createTag(newTagName) {
    $.ajax({
      url: `/questions/${props.questionId}/create_tag`,
      method: 'POST',
      data: {name: newTagName, color: 'black'},
    }).done(function(response) {
      const newTags = [...props.tags, response].sort((tag, tag2) => {
        return tag.text.localeCompare(tag2.text);
      });
      props.setTags(newTags);
    }).fail(function(_response) {
      console.log('Failed to Create Tag');
    });
  }

  /**
     * Ask ChatGPT to recommend tag names
     **/
  function getAiTagRecommendations() {
    $.ajax({
      url: `/questions/${props.questionId}/ai_tag_recommendations`,
      method: 'GET',
      data: {},
    }).done(function(response) {
      setAiTagRecommendations(response.TagRecommendations);
    }).fail(function(_response) {
      console.log('Failed to Get Recommended Tags');
    }).always(function(_response) {
      setLoadingAiTagRecommendations(false);
    });
  };

  return (
    <div className='tag-manager'>
      <div className='tag-manager-header'>
        <button className='close' onClick={props.closeTagManager} >
          <span>×</span>
        </button>
        <h2> Manage Tags </h2>
      </div>
      <div className='tag-manager-body'>
        <h3>Tags</h3>
        <ul className='tags'>
          {
            showNewTagInput ?
              <li className='new-tag'>
                <button className='color'></button>
                <input
                  className='name'
                  placeholder='Type a tag name, press Enter to save'
                  onKeyDown={
                    (event) => {
                      if (event.key !== 'Enter') return;

                      const newTagName = event.target.value;
                      if (newTagName == '') return;

                      createTag(newTagName);
                      event.target.value = '';
                    }
                  }
                />
                <button className='delete' onClick={() => setShowNewTagInput(false)} >
                  <span>×</span>
                </button>
              </li> : null
          }
          {
            props.tags.map((tag, index) => {
              return (
                <TagEntry
                  key={index}
                  tag={tag}
                  updateTagAndAppliedTags={props.updateTagAndAppliedTags}
                  deleteTagAndAppliedTags={props.deleteTagAndAppliedTags}
                />
              );
            })
          }
        </ul>
        <button className='add-tag' onClick={() => setShowNewTagInput(true)}>+ Add New Tag</button>
        {
          props.aiTagRecommendationEnabled ?
            <>
              <button
                className='ai-recommendation'
                onClick={() => {
                  if (loadingAiTagRecommendations == true) return;

                  getAiTagRecommendations();
                  setLoadingAiTagRecommendations(true);
                }}
              >
                <SettingsIcon icon={SparklesIcon}/>
                  &nbsp;Recommend Tags
              </button>
              <ul className='ai-recommended-tags'>
                {
                  loadingAiTagRecommendations ? <Spinner className='ai-tag-spinner'/> :
                    aiTagRecommendations.map((aiTagRecommendation, index) => {
                      return (
                        <AiTagRecommendation
                          key={index}
                          aiTagNameRecommendation={aiTagRecommendation.name}
                          createTag={createTag}
                        />
                      );
                    })
                }
              </ul>
            </> : null
        }
      </div>
    </div>
  );
}

export default TagManager;
