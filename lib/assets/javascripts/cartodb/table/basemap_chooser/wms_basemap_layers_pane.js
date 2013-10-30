
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

      var layer = new cdb.admin.TileLayer({
        urlTemplate: this.options.url,
        layers: $(e.target).attr("data-layer_name"),
        name: $(e.target).attr("data-layer_name"),
        format: 'image/png', // TODO: be smart about the format
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
