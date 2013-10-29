
  /**
   *  WMS layers pane for basemap chooser
   */

  cdb.admin.WMSBasemapLayersPane = cdb.core.View.extend({
    className: "basemap-pane",

    events: {
      'click li a.button'   : "_onClickLayer"
    },

    _onClickLayer: function(e) {

      e.preventDefault(e);
      e.stopPropagation(e);

      console.log(e);

      var layer = new cdb.admin.TileLayer({
        urlTemplate: "http://wms.geo.admin.ch",
        layers: 'ch.bakom.verfuegbarkeit-hdtv',
        format: 'image/png',
        transparent: true,
        type: "wms"
      });

      this.trigger('successChooser', layer, "wms_name");

    },

    initialize: function() {
      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_wms_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({ layers: this.options.layers }));
      return this;
    }
  });
