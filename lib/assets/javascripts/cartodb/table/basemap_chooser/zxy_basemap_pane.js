
  /**
   *  ZXY pane for basemap chooser
   */


  cdb.admin.ZXYBasemapChooserPane = cdb.admin.BasemapChooserPane.extend({
    className: "basemap-pane",

    initialize: function() {
      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({
        placeholder: 'Insert your TMS URL template',
        error: 'Your TMS URL template is not valid.'
      }));
      return this;
    }
  });
