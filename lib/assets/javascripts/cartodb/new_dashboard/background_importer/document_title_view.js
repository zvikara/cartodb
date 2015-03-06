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
    var img = '01';

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
      if (failed > 0) {
        title = '( ! )';
      } else {
        title = '(' + (completed + failed) + '/' + total + ')';
      }

      title += " " + this.model.get('username') + ' | CartoDB';
    }

    document.title = title;

    // Favicon
    if (per == 0) {
      img = '01'
    } else if (per < 25) {
      img = '02'
    } else if (per < 50) {
      img = '03'
    } else if (per < 75) {
      img = '04'
    } else {
      img = '05'
    }
    
    $.faviconNotify(cdb.config.get('assets_url') + '/images/favicons/' + img + '.png');
  }

});