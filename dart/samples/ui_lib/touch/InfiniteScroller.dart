part of touch;

// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Adds a listener to the scroller with triggers events
 * when a trigger point at the top, or bottom, of the screen is reached.
 *
 * To use this you will need to have an element with a scroller attached
 * to it. You need to have defined (in pixels) how far from the top or
 * bottom the scroll position must be in order to trigger (the "trigger
 * point") The element using this must have functions for hitting the top
 * trigger, and the bottom trigger. In general, these methods will
 * ascertain whether we have more data to scroll to (i.e. when we hit
 * the bottom trigger point but have reached the end of the data
 * displayed in the element we should ignore it), make the call for
 * more data and reposition the scroller - repositioning is key to
 * good user experience.
 *
 * Triggers are generated by listening for the SCROLL_END event from the
 * scroller, so data calls are not initiated whilst scrolling is happening,
 * but after.
 *
 * Controls changing divs between the usual (non-loading) div and the
 * loading div. To take advantage of this, callback function should return
 * a boolean indicating whether the usual div should be replaced by the
 * loading div.
 */
class InfiniteScroller {
  Scroller _scroller;

  /**
   * Function to invoke when trigger point is reached at the top of the view.
   */
  Function _onTopScroll;

  /**
   * Function to invoke when trigger point is reached at the bottom of the view.
   */
  Function _onBottomScroll;

  /** Offset for trigger point at the top of the view. */
  double _offsetTop;

  /** Offset for trigger point at the bottom of the view. */
  double _offsetBottom;

  /** Saves the last Y position. */
  double _lastScrollY;
  Element _topDiv;
  Element _topLoadingDiv;
  Element _bottomDiv;
  Element _bottomLoadingDiv;

  InfiniteScroller(Scroller scroller,
                   Function onTopScroll, Function onBottomScroll,
                   double offsetTop, [double offsetBottom = null])
      : _scroller = scroller,
        _onTopScroll = onTopScroll,
        _onBottomScroll = onBottomScroll,
        _offsetTop = offsetTop,
        _offsetBottom = offsetBottom == null ? offsetTop : offsetBottom,
        _lastScrollY = 0.0 {
  }

  /**
   * Adds the loading divs.
   * [topDiv] The div usually shown at the top.
   * [topLoadingDiv] is the div to show at the top when waiting for more
   * content to load at the top of the page.
   * [bottomDiv] is the div usually shown at the bottom.
   * [bottomLoadingDiv] is the div to show at the bottom when waiting for more
   * content to load at the end of the page.
   */
  void addLoadingDivs([Element topDiv = null,
                       Element topLoadingDiv = null,
                       Element bottomDiv = null,
                       Element bottomLoadingDiv = null]) {
    _topDiv = topDiv;
    _topLoadingDiv = topLoadingDiv;
    _bottomDiv = bottomDiv;
    _bottomLoadingDiv = bottomLoadingDiv;
    _updateVisibility(false, _topDiv, _topLoadingDiv);
    _updateVisibility(false, _bottomDiv, _bottomLoadingDiv);
  }

  void initialize() {
    _registerEventListeners();
  }

  /**
   * Switch back the divs after loading complete. Delegate should call
   * this function after loading is complete.
   */
  void loadEnd() {
    _updateVisibility(false, _topDiv, _topLoadingDiv);
    _updateVisibility(false, _bottomDiv, _bottomLoadingDiv);
  }

  /**
   * Called at the end of a scroll event.
   */
  void _onScrollEnd() {
    double ypos = _scroller.getVerticalOffset();

    // Scroll is below last point.
    if (ypos < _lastScrollY) {
      double bottomTrigger = _scroller.getMinPointY() + _offsetBottom;
      // And below trigger point.
      if (ypos <= bottomTrigger) {
        _updateVisibility(_onBottomScroll(), _bottomDiv, _bottomLoadingDiv);
      }
    } else {
      if (ypos > _lastScrollY) {
        // Scroll is above last point.
        double topTrigger = _scroller.getMaxPointY() - _offsetTop;
        // And above trigger point.
        if (ypos >= topTrigger) {
          _updateVisibility(_onTopScroll(), _topDiv, _topLoadingDiv);
        }
      }
    }
    _lastScrollY = ypos;
  }

  /**
   * Register the event listeners.
   */
  void _registerEventListeners() {
    _scroller.onScrollerEnd.add((Event event) { _onScrollEnd(); });
  }

  /**
   * Hides one div and shows another.
   */
  void _updateVisibility(bool isLoading, Element element,
                         Element loadingElement) {
    if (element != null) {
      element.style.display = isLoading ? "none" : "";
    }
    if (loadingElement != null) {
      loadingElement.style.display = isLoading ? "" : "none";
    }
  }
}
