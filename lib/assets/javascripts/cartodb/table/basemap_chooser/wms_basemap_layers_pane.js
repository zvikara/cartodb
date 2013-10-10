
  /**
   *  WMS layers pane for basemap chooser
   */

  cdb.admin.WMSBasemapLayersPane = cdb.core.View.extend({
    className: "basemap-pane",

    initialize: function() {
      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_wms_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({ layers: this.options.layers }));
      return this;
    }
  });
