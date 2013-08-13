/**
 * Create the views for the basemap chooser panes
 *
 * usage example:
 *
 * this.mapboxPane = new cdb.admin.BaseMapChooserPane({
 *   template: cdb.templates.getTemplate('table/views/basemap_chooser')
 * });
 * this.addView(this.mapboxPane);
 *
*/

cdb.admin.BaseMapChooserPane = cdb.core.View.extend({
  className: "basemap-pane",

  render: function() {
    this.$el.append(this.template({type: this.options.type}));
    return this;
  }
});
