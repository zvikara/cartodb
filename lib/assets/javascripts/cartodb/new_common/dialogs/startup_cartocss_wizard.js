var cdb = require('cartodb.js');
var BaseDialog = require('../views/base_dialog/view');
var pluralizeString = require('../view_helpers/pluralize_string');
var randomQuote = require('../view_helpers/random_quote');
var MapCardPreview = require('../views/mapcard_preview');
var _ = require('underscore');
var $ = require('jquery');
var moment = require('moment');

var AFFECTED_ENTITIES_SAMPLE_COUNT = 3;
var AFFECTED_VIS_COUNT = 3;

/**
 * Delete items dialog
 */
module.exports = BaseDialog.extend({

  events: function() {
    return _.extend({}, BaseDialog.prototype.events, {
      'click .js-ok': '_ok'
    });
  },

  initialize: function() {
    this.elder('initialize');
    this.layer = this.options.layer;
    this.previews = new Backbone.Collection();
    this.previews.bind('add', this.render, this);
    this.add_related_model(this.previews);
    this._loadMapPreviews();
  },

  render: function() {
    BaseDialog.prototype.render.call(this);
    return this;
  },

  /**
   * @implements cdb.ui.common.Dialog.prototype.render_content
   */
  render_content: function() {
     return cdb.templates.getTemplate('new_common/dialogs/startup_cartocss_wizard')({
       previews: this.previews.toJSON()
    });
  },

  /**
   * @overrides BaseDialog.prototype._ok
   */
  _ok: function(e) {
    this.killEvent(e);
  },


  // given column stats return if worths rendering
  hasInsights: function(stats) {
    if (stats.type === 'number') {
      return true;
    } else if(stats.type === 'string') {
      if(stats.distinct> 20) return false;
    }
    return false;
  },

  columnMap: function(sql, c, geometryType, bbox) {
    var self = this;
    var s = cdb.admin.SQL();
    s.describe(sql, c, function(data) {
      if (self.hasInsights(data)) {
        var css = cartodb.CartoCSS.guessCss(sql, geometryType, data.column, data);
        if (css) {
          self.map(sql, css, bbox, function(url) {
            self.previews.add({
              img_url: url,
              column: c
            });
          });
        }
      }
    });
  },

  map: function(sql, cartocss, bbox, callback) {
     var layer_definition = {
        user_name: window.user_data.username,
        maps_api_template: this.layer.get('maps_api_template'),
        api_key: window.user_data.api_key,
        layers: [
        /*{
          type: "http",
          options: {
            urlTemplate: "http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
            subdomains: [ "a", "b", "c" ]
          }
        },*/ {
          type: "cartodb",
          options: {
            sql: sql,
            cartocss: cartocss,
            cartocss_version: "2.1.1"
          }
        }]
      };

      // and now we just ask for the URL and append it to the page
      cartodb.Image(layer_definition)
        .size(300, 170)
        .bbox([bbox[0][1], bbox[0][0], bbox[1][1], bbox[1][0]])
        .getUrl(function(error, url) {
          callback(url+ "?api_key=" +  window.user_data.api_key);
        });
  },


  _loadMapPreviews: function() {
    var self = this;
    var s = cdb.admin.SQL();
    var table = this.layer.table;
    table.bind('change:geometry_types', function() {
      var sql = table.data().getSQL();
      s.describe(sql, 'the_geom', function(data) {
        var geometryType = table.geomColumnTypes()[0];
        var columns = table.get('schema');
        _(columns).each(function(v) {
          if (!cdb.admin.Row.isReservedColumn(v[0])) {
            self.columnMap(sql, v[0], geometryType, data.bbox);
          }
        })
      });
    });



    //var self = this;

    //this.$el.find('.MapCard').each(function() {
      //var mapCardPreview = new MapCardPreview({
        //el: $(this).find('.js-header'),
        //vizjson: $(this).data('vizjson-url'),
        //width: 298,
        //height: 130
      //}).load();

      //self.addView(mapCardPreview);
    //});

  }

});
