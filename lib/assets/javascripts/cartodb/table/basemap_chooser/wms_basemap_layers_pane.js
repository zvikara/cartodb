
  /**
   *  WMS layers pane for basemap chooser
   */

  cdb.admin.WMSBasemapLayersPaneItem = cdb.core.Model.extend({
  });

  cdb.admin.WMSBasemapLayersPaneItems = Backbone.Collection.extend({
    model: cdb.admin.WMSBasemapLayersPaneItem
  });

  cdb.admin.WMSBasemapLayersPaneItemView = cdb.core.View.extend({

    tagName: "li",

    template_base: '<strong><%= title %></strong> <a href="#add_this" class="button grey smaller right">Add this</a>',

    events: {
      'click a.button'   : "_onClickLayer"
    },

    initialize: function() {
      this.template = _.template(this.template_base);
    },

    _onClickLayer: function(e) {

      e.preventDefault(e);
      e.stopPropagation(e);

      var layer = new cdb.admin.TileLayer({
        urlTemplate: this.options.url,
        layers: this.model.get("name"),
        name: this.model.get("title"),
        format: 'image/png', // TODO: be smart about the format
        transparent: true,
        type: "wms"
      });

      this.trigger('layer_choosen', layer);

    },

    render: function() {

      this.$el.html(this.template(this.model.toJSON()));
      return this;

    }

  });

  cdb.admin.WMSBasemapLayersPane = cdb.core.View.extend({
    className: "basemap-pane",


    initialize: function() {

      var self = this;

      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_wms_pane');

      this._loadLayers(this.options.layers);

      this.render();

      this.items.each(function(layer) {

        var view = new cdb.admin.WMSBasemapLayersPaneItemView({
          model: layer,
          url: self.options.url
        });

        self.$el.find("ul").append(view.render().$el);
        self.addView(view);

        view.bind("layer_choosen", function(layer) {
          self.trigger('successChooser', layer, "wms_name");
        });

      });
    },

    _loadLayers: function(layers) {

      var items = _.map(layers, function(item) {

        return new cdb.admin.WMSBasemapLayersPaneItem({
          name: item.name,
          title: item.title,
          bounding_boxes: item.bounding_boxes
        });

      });

      this.items = new cdb.admin.WMSBasemapLayersPaneItems(items);

    },

    render: function() {
      this.$el.html(this.template({ layers: this.options.layers }));
      return this;
    }
  });
