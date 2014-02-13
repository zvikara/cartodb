(function() {
  "use strict";

  CodeMirror.colorHint = function(cm, getHints, options) {
    // We want a single cursor position.
    if (cm.somethingSelected()) return;
    if (getHints == null) getHints = cm.getHelper(cm.getCursor(), "hint");
    if (getHints == null) return;

    if (cm.state.completionActive) cm.state.completionActive.close();

    var completion = cm.state.completionActive = new Completion(cm, getHints, options || {});
    CodeMirror.signal(cm, "startCompletion", cm);
    if (completion.options.async)
      getHints(cm, function(hints) { completion.showHints(hints); }, completion.options);
    else
      return completion.showHints(getHints(cm, completion.options));
  };

  function Completion(cm, getHints, options) {
    this.cm = cm;
    this.getHints = getHints;
    this.options = options;
    this.widget = this.onClose = null;
  }

  Completion.prototype = {
    close: function() {
      if (!this.active()) return;
      this.cm.state.completionActive = null;

      if (this.widget) this.widget.close();
      if (this.onClose) this.onClose();
      CodeMirror.signal(this.cm, "endCompletion", this.cm);
    },

    active: function() {
      return this.cm.state.completionActive == this;
    },

    pick: function(data, i) {
      var completion = data.list[i];
      if (completion.hint) completion.hint(this.cm, data, completion);
      else this.cm.replaceRange(getText(completion), data.from, data.to);
      this.close();
    },

    showHints: function(data) {
      if (!this.active()) return this.close();

      // if (this.options.completeSingle != false && data.list.length == 1)
      //   this.pick(data, 0);
      // else
        this.showWidget(data);
    },

    showWidget: function(data) {
      this.widget = new Widget(this, data);
      CodeMirror.signal(data, "shown");

      var debounce = null, completion = this, finished;
      var closeOn = this.options.closeCharacters || /[\s()\[\]{};:>,-]/;
      var startPos = this.cm.getCursor(), startLen = this.cm.getLine(startPos.line).length;

      function done() {
        if (finished) return;
        finished = true;
        completion.close();
        completion.cm.off("cursorActivity", activity);
        if (data) CodeMirror.signal(data, "close");
      }

      function update() {
        if (finished) return;
        CodeMirror.signal(data, "update");
        if (completion.options.async)
          completion.getHints(completion.cm, finishUpdate, completion.options);
        else
          finishUpdate(completion.getHints(completion.cm, completion.options));
      }
      function finishUpdate(data_) {
        data = data_;
        if (finished) return;
        if (!data || !data.list.length) return done();
        completion.widget = new Widget(completion, data);
      }

      function activity() {
        clearTimeout(debounce);
        var pos = completion.cm.getCursor(), line = completion.cm.getLine(pos.line);
        if (pos.line != startPos.line || line.length - pos.ch != startLen - startPos.ch ||
            pos.ch < startPos.ch || completion.cm.somethingSelected() ||
            (pos.ch && closeOn.test(line.charAt(pos.ch - 1)))) {
          completion.close();
        } else {
          debounce = setTimeout(update, 170);
          if (completion.widget) completion.widget.close();
        }
      }
      this.cm.on("cursorActivity", activity);
      this.onClose = done;
    }
  };

  function getText(completion) {
    if (typeof completion == "string") return completion;
    else if (typeof completion == "object") return completion[0];
    else return completion.text;
  }

  function getType(completion) {
    if (typeof completion == "object") return completion[1];
    else return "";
  }

  function buildKeyMap(options, handle) {
    var baseMap = {
      Up: function() {handle.moveFocus(-1);},
      Down: function() {handle.moveFocus(1);},
      PageUp: function() {handle.moveFocus(-handle.menuSize());},
      PageDown: function() {handle.moveFocus(handle.menuSize());},
      Home: function() {handle.setFocus(0);},
      End: function() {handle.setFocus(handle.length);},
      Enter: handle.pick,
      Tab: handle.pick,
      Esc: handle.close
    };
    var ourMap = options.customKeys ? {} : baseMap;
    function addBinding(key, val) {
      var bound;
      if (typeof val != "string")
        bound = function(cm) { return val(cm, handle); };
      // This mechanism is deprecated
      else if (baseMap.hasOwnProperty(val))
        bound = baseMap[val];
      else
        bound = val;
      ourMap[key] = bound;
    }
    if (options.customKeys)
      for (var key in options.customKeys) if (options.customKeys.hasOwnProperty(key))
        addBinding(key, options.customKeys[key]);
    if (options.extraKeys)
      for (var key in options.extraKeys) if (options.extraKeys.hasOwnProperty(key))
        addBinding(key, options.extraKeys[key]);
    return ourMap;
  }










  /**
   *  Codemirror color widget
   *
   */


  function Widget(completion, data) {
    this.completion = completion;
    this.data = data;
    var widget = this, cm = completion.cm, options = completion.options;

    var color_picker = this.color_picker = new cdb.admin.ColorPicker({
      imagePicker:          false,
      kind:                 'marker',
      vertical_position:    "up",
      horizontal_position:  "left",
      horizontal_offset:    5,
      vertical_offset:      0,
      tick:                 "left",
    });

    var pos = cm.cursorCoords(options.alignWithWord !== false ? data.from : null);
    var left = pos.left, top = pos.bottom, below = true;

    color_picker.el.style.left = left + "px";
    color_picker.el.style.top = top + "px";
    // If we're at the edge of the screen, then we want the menu to appear on the left of the cursor.
    var winW = window.innerWidth || Math.max(document.body.offsetWidth, document.documentElement.offsetWidth);
    var winH = window.innerHeight || Math.max(document.body.offsetHeight, document.documentElement.offsetHeight);

    (options.container || document.body).appendChild(color_picker.render().el);

    var box = color_picker.el.getBoundingClientRect();
    var overlapX = box.right - winW, overlapY = box.bottom - winH;
    if (overlapX > 0) {
      if (box.right - box.left > winW) {
        color_picker.el.style.width = (winW - 5) + "px";
        overlapX -= (box.right - box.left) - winW;
      }
      color_picker.el.style.left = (left = pos.left - overlapX) + "px";
    }
    if (overlapY > 0) {
      var height = box.bottom - box.top;
      if (box.top - (pos.bottom - pos.top) - height > 0) {
        overlapY = height + (pos.bottom - pos.top);
        below = false;
      } else if (height > winH) {
        color_picker.el.style.height = (winH - 5) + "px";
        overlapY -= height - winH;
      }
      color_picker.el.style.top = (top = pos.bottom - overlapY) + "px";
    }

    color_picker.$el.show();

    // cm.addKeyMap(this.keyMap = buildKeyMap(options, {
    //   moveFocus: function(n) { widget.changeActive(widget.selectedHint + n); },
    //   setFocus: function(n) { widget.changeActive(n); },
    //   menuSize: function() { return widget.screenAmount(); },
    //   length: completions.length,
    //   close: function() { completion.close(); },
    //   pick: function() { widget.pick(); }
    // }));

    if (options.closeOnUnfocus !== false) {
      var closingOnBlur;
      // cm.on("blur", this.onBlur = function() { closingOnBlur = setTimeout(function() { completion.close(); }, 100); });
      // cm.on("focus", this.onFocus = function() { clearTimeout(closingOnBlur); });
    }

    var startScroll = cm.getScrollInfo();
    cm.on("scroll", this.onScroll = function() {
      var curScroll = cm.getScrollInfo(), editor = cm.getWrapperElement().getBoundingClientRect();
      var newTop = top + startScroll.top - curScroll.top;
      var point = newTop - (window.pageYOffset || (document.documentElement || document.body).scrollTop);
      if (!below) point += color_picker.el.offsetHeight;
      if (point <= editor.top || point >= editor.bottom) return completion.close();
      color_picker.el.style.top = newTop + "px";
      color_picker.el.style.left = (left + startScroll.left - curScroll.left) + "px";
    });

    CodeMirror.on(color_picker, "click", function(e) {
      var t = e.target || e.srcElement;
      // if (t.hintId != null) {widget.changeActive(t.hintId); widget.pick();}
    });
    // CodeMirror.on(hints, "mouseover", function(e) {
    //   // var t = e.target || e.srcElement;
    //   // if (t.hintId != null) widget.changeActive(t.hintId);
    // });
    // CodeMirror.on(hints, "mousedown", function() {
    //   // setTimeout(function(){cm.focus();}, 20);
    // });

    CodeMirror.signal(data, "select", [], color_picker.firstChild);

    return true;
  }

  Widget.prototype = {
    close: function() {
      if (this.completion.widget != this) return;
      this.completion.widget = null;
      this.color_picker.clean();
      // this.completion.cm.removeKeyMap(this.keyMap);

      // var cm = this.completion.cm;
      // if (this.completion.options.closeOnUnfocus !== false) {
      //   cm.off("blur", this.onBlur);
      //   cm.off("focus", this.onFocus);
      // }
      // cm.off("scroll", this.onScroll);
    },

    pick: function() {
      this.completion.pick(this.data, this.selectedHint);
    },

    changeActive: function(i) {},

    screenAmount: function() {
      return Math.floor(this.color_picker.clientHeight) || 1;
    }
  };









  /**
   *  Codemirror color helper
   *
   *  - We should get the color if it is specified
   */

  CodeMirror.registerHelper("hint", "color", function(cm, options) {
    var cur = cm.getCursor(),
        token = cm.getTokenAt(cur);

    // Get color if it is defined

    return {
      list: [],
      from: CodeMirror.Pos(cur.line, token.start),
      to: CodeMirror.Pos(cur.line, token.end)
    };
  });



})();
