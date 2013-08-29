/**
 * Create the views for the import panes
*/

cdb.admin.ImportPane = cdb.core.View.extend({
  className: "import-pane",

  render: function() {
    this.$el.append(this.template({chosen: this.options.chosen}));
    return this;
  }
});
