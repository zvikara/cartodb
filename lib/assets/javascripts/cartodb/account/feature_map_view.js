var cdb = require('cartodb.js');
var _ = require('underscore');

/**
 *  Feature map previewer and selector
 */

module.exports = cdb.core.View.extend({

  events: {
    'click ': '_openMapSelector'
  },

  initialize: function() {

  },

  render: function() {
    this.clearSubViews();
    this._destroyMap();
    this._renderMap();
    return this;
  },

  _initBinds: function() {
    this.model.bind('change', this.render, this);
  },

  _renderMap: function() {

  },

  _destroyMap: function() {
    if (this.map) {

    }
  },

  _openMapSelector: function() {

  },

  clean: function() {
    this.elder('clean');
  }

  
});
