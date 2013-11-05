
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

    template_base: '<div class="msg"><strong><%= title %></strong><% if (!valid) { %><p>This layer doesn\'t contain supported projections</p><% } %></div> <a href="#add_this" class="button grey smaller right<% if (!valid) { %> disabled<% } %>">Add this</a>',

    events: {
      'click a.button'   : "_onClickLayer"
    },

    initialize: function() {
      this.template = _.template(this.template_base);
    },

    _containsValidProjections: function() {

      var bounding_boxes = this.model.get("bounding_boxes");

      if (bounding_boxes && bounding_boxes.length == 0) return true;

      var valid = false;
      var noProjectionCount = 0;

      var self = this;

      _.each(bounding_boxes, function(bbox) {

        var projection = bbox.srs || bbox.crs;
        console.log(self.model.get("title"), bounding_boxes.length, projection);

        if (!projection) noProjectionCount++;

        if (projection.indexOf("3857") != -1 || projection.indexOf("900913") != -1) {
          valid = true;
          return;
        }
      });

      // if the layer doesn't contain any projection, let's consider
      // them valid
      if (noProjectionCount == bounding_boxes.length) valid = true;

      return valid;

    },

    _onClickLayer: function(e) {

      e.preventDefault(e);
      e.stopPropagation(e);

      if ($(e.target).hasClass("disabled")) return;

      var name = this.model.get("name") || this.model.get("title");
      var className = name.replace(/[^a-zA-Z ]/g, "").toLowerCase();

      var layer = new cdb.admin.TileLayer({
        urlTemplate: this.options.url,
        layers: name,
        className: className,
        bounding_boxes: this.model.get("bounding_boxes"),
        name: this.model.get("title") || this.model.get("name"),
        format: 'image/png', // TODO: be smart about the format
        transparent: true,
        type: "wms"
      });

      this.trigger('layer_choosen', layer);

    },

    render: function() {

      var valid = this._containsValidProjections();
      var options = _.extend(this.model.toJSON(), { valid : valid });
      this.$el.html(this.template(options));

      if (!valid) this.$el.addClass("invalid");

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

    _checkTileJson: function() {

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
