import {
  AbstractDisplacementState, Action, InputType,
} from '@projectstorm/react-canvas-core';

/**
 * A custom override for link selection behaviour.
 * In the default implementation, clicking a link creates a vertex.
 * In this custom implementation, clicking a link will select the link,
 * which normally requires SHIFT + left click
 * https://github.com/projectstorm/react-diagrams/issues/611
 */
export class SelectLinkState extends AbstractDisplacementState {
  /**
   * Initializes the SelectLinkState
   */
  constructor() {
    super({name: 'select-link'});

    this.registerAction(
        new Action({
          type: InputType.MOUSE_DOWN,
          fire: (actionEvent) => this.onMouseDown(actionEvent),
        }),
    );
  }

  /**
   * Handles MouseDown events.
   * Used to select links
   * @param {ActionEvent} actionEvent - MouseDown details
   */
  onMouseDown(actionEvent) : void {
    const link = this.engine.getMouseElement(actionEvent.event);

    if (link.isLocked()) {
      this.eject();
    }

    this.engine.getModel().clearSelection();
    link.setSelected(true);
  }

  /**
   * Providing an unused default implementation for AbstractDisplacementState
   * @param {ActionEvent} actionEvent - The mouseMove event
  */
  fireMouseMoved(actionEvent) {}
}
