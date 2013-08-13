
  /**
   *  Mapbox pane for import a file
   */


  cdb.admin.MapboxBaseMapChooserPane = cdb.admin.BaseMapChooserPane.extend({
    
    className: "basemap-pane",

    initialize: function() {
      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({ type: 'MapBox' }));
      return this;
    }
  });
