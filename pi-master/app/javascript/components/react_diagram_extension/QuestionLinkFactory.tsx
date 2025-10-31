import * as React from 'react';
import {DefaultLinkFactory} from '@projectstorm/react-diagrams';

import {QuestionLinkModel} from './QuestionLinkModel';
import {QuestionLinkWidget} from './QuestionLinkWidget';

export class QuestionLinkFactory extends DefaultLinkFactory {
  hideLinks: boolean;

  constructor(hideLinks :boolean) {
    super('questionLink');
  }

  generateModel(): QuestionLinkModel {
    return new QuestionLinkModel();
  }

  generateReactWidget(event): JSX.Element {
    return (
      <QuestionLinkWidget
        link={event.model}
        diagramEngine={this.engine}
      />
    );
  }
}
