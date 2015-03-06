var $ = require('jquery');
var cdb = require('cartodb.js');

/**
 *  Document view
 *
 */

module.exports = cdb.core.View.extend({

  el: document,

  initialize: function() {
    this._initBinds();
  },

  render: function() {
    return this;
  },

  _initBinds: function() {
    this.collection.bind('change add remove', this._setDocumentTitle, this);
  },

  _setDocumentTitle: function() {
    var failed = 0;
    var completed = 0;
    var total = this.collection.size();

    this.collection.each(function(m) {
      if (m.hasFailed()) {
        ++failed;
      }
      if (m.hasCompleted()) {
        ++completed;
      }
    });

    var per = ((failed + completed) * 100) / total;
    var title = '';

    // Title
    if (total === 0) {
      title = this.model.get('username') + ' | CartoDB';
    } else {
      title = '(' + (completed + failed) + '/' + total + ')';
      title += " " + this.model.get('username') + ' | CartoDB';
    }
    document.title = title;
    
    // Badge
    if (failed > 0) {
      var favicon= new Favico({
        bgColor : '#C74B43',
        textColor : '#FFFFFF',
        fontStyle: 'lighter'
      });
      favicon.badge(failed);
    } else if (completed > 0) {
      var favicon= new Favico({
        bgColor: '#5CB85C',
        textColor: '#FFFFFF',
        fontStyle: 'lighter'
      });
      favicon.badge(completed);
    } else {
      var favicon= new Favico();
      favicon.reset();
    }
  }

});