import * as React from 'react';

import {RightAngleLinkWidget} from '@projectstorm/react-diagrams';
import {PointModel, LinkWidget} from '@projectstorm/react-diagrams-core';
import {Point} from '@projectstorm/geometry';

/**
 * Copy+pasted from react-diagrams to allow for customization
 * https://github.com/projectstorm/react-diagrams/blob/master/packages/react-diagrams-routing/src/link/RightAngleLinkWidget.tsx
 */
export class QuestionLinkWidget extends RightAngleLinkWidget {
  /**
   * Initializes the QuestionLinkWidget
   * @param { Object } props - see react-diagrams RightAngleLinkWidget
   */
  constructor(props) {
    super(props);
  }

  /**
  * Copy+pasted from react-diagrams to allow for customization
  * https://github.com/projectstorm/react-diagrams/blob/master/packages/react-diagrams-routing/src/link/RightAngleLinkWidget.tsx
  *
  * This lies somewhere between right-angle routing and smart pathing
  *
  * Two main cases: target port is to the left, and target port is to the right
  *
  * Left:
  *
  * m-----------------m
  * |                 |
  * m--t           s--m
  *
  * Right:
  *
  * s----m
  *      |
  *      |
  *      m----t
  *
  *
  * We maintain 6 points to simplify the logic, so we sometimes double (or even
  * quadruple) middle points. e.g.
  *
  * s----mmmm----t
  * @return { QuestionLinkWidget }
  **/
  render() {
    if (this.props.link.hidden) {
      return null;
    }

    //ensure id is present for all points on the path
    let points = this.props.link.getPoints();
    let paths = [];

    // Get points based on link orientation
    let pointLeft = points[0];
    let pointRight = points[points.length - 1];
    let hadToSwitch = false;
    if (pointLeft.getX() > pointRight.getX()) {
      pointLeft = points[points.length - 1];
      pointRight = points[0];
      hadToSwitch = true;
    }
    let dy = Math.abs(points[0].getY() - points[points.length - 1].getY());

    const horizontalDirection = hadToSwitch ? 'left' : 'right';

    // When new link add one middle point to get everywhere 90° angle
    if (this.props.link.getTargetPort() === null && points.length === 2) {
      [...Array(2)].forEach((item) => {
        this.props.link.addPoint(
          new PointModel({
            link: this.props.link,
            position: new Point(pointLeft.getX(), pointRight.getY())
          }),
          1
        );
      });
      this.props.link.setManuallyFirstAndLastPathsDirection(true, true);
    }
    // When new link is moving and not connected to target port move with middle point
    // TODO: @DanielLazarLDAPPS This will be better to update in DragNewLinkState
    //  in function fireMouseMoved to avoid calling this unexpectedly e.g. after Deserialize
    else if (this.props.link.getTargetPort() === null && this.props.link.getSourcePort() !== null) {
      points[1].setPosition(
        pointRight.getX() + (pointLeft.getX() - pointRight.getX()) / 2,
        !hadToSwitch ? pointLeft.getY() : pointRight.getY()
      );
      points[2].setPosition(
        pointRight.getX() + (pointLeft.getX() - pointRight.getX()) / 2,
        !hadToSwitch ? pointRight.getY() : pointLeft.getY()
      );
    }
    // Render was called but link is not moved but user.
    // Node is moved and in this case fix coordinates to get 90° angle.
    // For loop just for first and last path
    else if (!this.state.canDrag && points.length == 6) {
      const newCoords = this.calculateInBetweenPoints(horizontalDirection, points);

      for (let i = 0; i < newCoords.length; i++) {
        points[i + 1].setPosition(newCoords[i][0], newCoords[i][1]);
      }
    }

    if (this.props.link.getTargetPort() !== null && this.props.link.getSourcePort() !== null) {
      // Remove middle points so we can add our own in.
      //
      // o---m
      //     |
      //     |
      //     m----o
      //
      if ([3,4].includes(points.length)) {
        this.props.link.setPoints([points[0], points[points.length - 1]]);
      }

      // Fill in the points between the start and end points
      if (points.length === 2) {
        const newCoords = this.calculateInBetweenPoints(horizontalDirection, points);

        for (let i = newCoords.length - 1; i >= 0; i--) {
          this.addPoint(newCoords[i][0], newCoords[i][1]);
        }
      }
    }

    for (let j = 0; j < points.length - 1; j++) {
      paths.push(
        this.generateLink(
          LinkWidget.generateLinePath(points[j], points[j + 1]),
          {
            'data-linkid': this.props.link.getID(),
            'data-point': j,
            onMouseDown: (event: MouseEvent) => {
              if (event.button === 0) {
                this.setState({ canDrag: true });
                this.dragging_index = j;
                // Register mouse move event to track mouse position
                // On mouse up these events are unregistered check "this.handleUp"
                window.addEventListener('mousemove', this.handleMove);
                window.addEventListener('mouseup', this.handleUp);
              }
            },
            onMouseEnter: (event: MouseEvent) => {
              this.setState({ selected: true });
              this.props.link.lastHoverIndexOfPath = j;
            }
          },
          j
        )
      );
    }

    this.refPaths = [];
    return <g data-default-link-test={this.props.link.getOptions().testName}>{paths}</g>;
  }

  /**
   * Calculates and returns a set of inbetween points, that is, the points
   * between the initial "source" and final "target" points.
   *
   * @param { string } horizontalDirection - The direction from the link
   *   source to the link target ('left', 'right')
   * @param { Array } points - The set of points in the path
   * @return { Array } an array of points between source and target
   */
  calculateInBetweenPoints(horizontalDirection: string, points: Array<PointModel>) {
    const startPoint = points[0];
    const endPoint = points[points.length - 1];
    const startCoords = [startPoint.getX(), startPoint.getY()];
    const endCoords = [endPoint.getX(), endPoint.getY()];

    switch (horizontalDirection) {
      case 'left':
        return [
          [startCoords[0] + 20, startCoords[1]],
          [startCoords[0] + 20, endCoords[1] - 40],
          [endCoords[0] - 20, endCoords[1] - 40],
          [endCoords[0] - 20, endCoords[1]],
        ];
      case 'right':
        const newX = (startCoords[0] + endCoords[0]) / 2;

        return [
          [newX, startCoords[1]],
          [newX, startCoords[1]], // dummy point
          [newX, endCoords[1]], // dummy point
          [newX, endCoords[1]],
        ];
      default:
        console.debug('uh oh');
    }
  }

  /**
   * @param { number } x - The point's x value
   * @param { number } y - The point's y value
   * Side effect: The "points" structure used in render will be modified
   */
  addPoint(x: number, y: number) {
    this.props.link.addPoint(
        new PointModel({
          link: this.props.link,
          position: new Point(x, y),
        }),
    );
  }
}
