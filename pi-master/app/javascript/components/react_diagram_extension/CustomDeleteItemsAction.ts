import React from 'react';

import {Action, ActionEvent, InputType} from '@projectstorm/react-canvas-core';

import {QuestionLinkModel} from './QuestionLinkModel';
import {QuestionNodeModel} from './QuestionNodeModel';

interface CustomDeleteItemsActionOptions {
    keyCodes?: number[];
    locked?: boolean;
}

/**
 * Deletes all selected links
*/
export class CustomDeleteItemsAction extends Action {
  /**
   * Initializes the CustomDeleteItemsAction
   * @param { Object } options - CustomDeleteItemsActionOptions
  */
  constructor(options: CustomDeleteItemsActionOptions = {}) {
    options = {
      keyCodes: ['Delete', 'Backspace'],
      ...options,
    };

    super({
      type: InputType.KEY_DOWN,
      fire: (event: ActionEvent<React.KeyboardEvent>) => {
        if (options.keyCodes.includes(event.event.code)) {
          const selectedEntities = this.engine.getModel().getSelectedEntities();
          const links = selectedEntities.filter((model) => {
            return model instanceof QuestionLinkModel &&
              model.getSourcePort().parent instanceof QuestionNodeModel &&
              !options.locked;
          });

          if (links.length > 0) {
            links.forEach((model) => {
              model.remove();
            });

            this.engine.repaintCanvas();
          }
        }
      },
    });
  }
}
