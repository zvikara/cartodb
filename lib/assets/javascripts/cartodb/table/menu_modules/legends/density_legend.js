/**
 * DensityLegend
 */
cdb.admin.mod.DensityLegend = cdb.admin.mod.CustomLegend.extend({

  _FILTER_NAME: "density",

  _setupTemplates: function() {

    this.template = this.getTemplate('table/menu_modules/legends/views/density_legend_pane');

    this.item_templates = [];
    this.item_templates["text"]  = 'table/menu_modules/legends/views/legend_item_text';
    this.item_templates["color"] = 'table/menu_modules/legends/views/legend_item_color';

  },

  _calculateItems: function() {

    var leftLabel  = "left label";
    var rightLabel = "right label";

    if (this.items) {
      leftLabel  = this.items.at(0).get("value");
      rightLabel = this.items.at(1).get("value");
    }

    var items = [];

    this.properties = this.wizardProperties.properties;

    var methodMap = {
      '3 Buckets': 3,
      '5 Buckets': 5,
      '7 Buckets': 7
    };

    var nquartiles = methodMap[this.properties['method']];
    var ramp = cdb.admin.color_ramps[this.properties['color_ramp']][nquartiles];

    items.push(new cdb.geo.ui.LegendItemModel({ type: "text",  name: "Left label",  value: leftLabel }));
    items.push(new cdb.geo.ui.LegendItemModel({ type: "text",  name: "Right label", value: rightLabel }));

    _.each(ramp, function(color) {
      items.push(new cdb.geo.ui.LegendItemModel({ type: "color", name: "Color", value: color }));
    });

    this.items.reset(items);

  },

  _renderItem: function(item) {

    var view = new cdb.admin.mod.LegendEditorItem({
      model: item,
      observe: "value",
      template_name: this.item_templates[item.get("type")]
    });

    this.$el.find("ul").append(view.render().$el);
    this.addView(view);

  }

});


