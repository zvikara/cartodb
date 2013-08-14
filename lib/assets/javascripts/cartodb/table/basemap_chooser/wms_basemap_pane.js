
  /**
   *  WMS pane for import a file
   */


  cdb.admin.WMSBasemapChooserPane = cdb.admin.BasemapChooserPane.extend({
    className: "basemap-pane",

    initialize: function() {
      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({
        placeholder: 'Insert your WMS base URL',
        error: 'Your WMS base URL is not valid.'
      }));
      return this;
    }
  });
