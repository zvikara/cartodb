
  /**
   * Shows a dialog to choose another base map
   * 
   * new BaseMapChooser()
   *
   */

  cdb.admin.BaseMapAdder = cdb.admin.BaseDialog.extend({

    _TEXTS: {
      title:  _t("Add your basemap"),
      description: _t("Add your MapBox, ZXY or WMS maps"),
      ok:     _t("Add basemap")
    },

    _WAITING_INPUT_TIME: 1000,

    events: function(){
      return _.extend({},cdb.admin.BaseDialog.prototype.events);
    },

    initialize: function() {
      _.bindAll(this, "_successChooser", "_errorChooser", "_checkOKButton");

      _.extend(this.options, {
        title: this._TEXTS.title,
        description: this._TEXTS.description,
        clean_on_hide: true,
        cancel_button_classes: "margin15",
        ok_button_classes: "button grey",
        ok_title: this._TEXTS.ok,
        modal_type: "compressed",
        width: 512,
        modal_class: 'basemap_chooser_dialog',
      });

      this.constructor.__super__.initialize.apply(this);

      this.model = new cdb.core.Model({ enabled: true, url:'' });
    },

    render_content: function() {
      var $content = this.$content = $("<div>");
      this.temp_content = cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_dialog');
      $content.append(this.temp_content());

      // Render file tabs
      this.render_basemap_tabs($content);

      return $content;
    },

    render_basemap_tabs: function($content) {
      // Basemap tabs
      this.basemap_tabs = new cdb.admin.Tabs({
        el: $content.find('.basemap-tabs'),
        slash: true
      });
      this.addView(this.basemap_tabs);

      // MapBox
      this.mapboxPane = new cdb.admin.MapboxBasemapChooserPane();
      this.mapboxPane.bind('successChooser', this._successChooser, this);
      this.mapboxPane.bind('errorChooser', this._errorChooser);
      this.mapboxPane.bind('inputChange', this._checkOKButton);

      // ZXY
      this.zxyPane = new cdb.admin.ZXYBasemapChooserPane();
      this.zxyPane.bind('successChooser', this._successChooser, this);
      this.zxyPane.bind('errorChooser', this._errorChooser);
      this.zxyPane.bind('inputChange', this._checkOKButton);

      // WMS
      this.wmsPane = new cdb.admin.WMSBasemapChooserPane();
      this.wmsPane.bind('chooseWMSLayers', this._chooseWMSLayers, this);
      this.wmsPane.bind('errorChooser', this._errorChooser);
      this.wmsPane.bind('inputChange', this._checkOKButton);


      // Create TabPane
      this.basemap_panes = new cdb.ui.common.TabPane({
        el: $content.find(".basemap-panes")
      });
      this.basemap_panes.addTab('mapbox', this.mapboxPane);
      this.basemap_panes.addTab('zxy', this.zxyPane);
      this.basemap_panes.addTab('wms', this.wmsPane);
      this.basemap_panes.bind('tabEnabled', this._checkOKButton, this);

      this.basemap_tabs.linkToPanel(this.basemap_panes);
      this.addView(this.basemap_panes);
      $content.append(this.basemap_panes.render());

      this.basemap_panes.active('mapbox');
    },

    //////////////
    //   HELP   //
    //////////////
    getURL: function() {
      return this.basemap_panes.activePane.$el.find("input[type='text']").val();
    },

    //////////////
    //   UI     //
    //////////////

    // Check 
    _checkOKButton: function() {
      var $ok = this.$("a.ok");
      var action = 'addClass';

      var url = this.getURL();

      if (url) {
        action = 'removeClass';
      } else {
        action = 'addClass';
      }

      $ok
        [action]('disabled')
    },

    _chooseWMSLayers: function(data) {
      this.basemap_panes.activePane._hideLoader();

      this.basemap_panes.removeTab('wms');
      this.wmsNewPane = new cdb.admin.WMSBasemapLayersPane({template: cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_wms_pane')});
      this.basemap_panes.addTab('wms', this.wmsNewPane);

      this.$el.find(".scrollpane").jScrollPane();

      this.model.set("enabled", true);
    },

    _successWMSChooser: function(data) {
      // End loader
      this.basemap_panes.activePane._hideLoader();

      // Check if the respond is an array
      // In that case, get only the first
      if (_.isArray(data) && _.size(data) > 0) {
        data = _.first(data);
      }

      var layer = new cdb.admin.TileLayer.wms(data.wms_server, {
        layers: data.layers[0],
        format: data.supported_formats[0]
      });

      // Set the className from the urlTemplate of the basemap
      layer.set("className", layer._generateClassName(data.layers[0]));

      // do not save before add because the layer collection
      // has the correct url
      this.options.baseLayers.add(layer);
      layer.save();

      // Remove error
      this.basemap_panes.activePane._hideError();

      this.hide();
      this.options.ok && this.options.ok(layer);
    },

    /**
     * If the url is valid
     */
    _successChooser: function(layer, name) {
      // End loader
      this.basemap_panes.activePane._hideLoader();

      // Set the className from the urlTemplate of the basemap
      layer.set("className", layer._generateClassName(name));

      // do not save before add because the layer collection
      // has the correct url
      this.options.baseLayers.add(layer);
      layer.save();

      // Remove error
      this.basemap_panes.activePane._hideError();

      this.hide();
      this.options.ok && this.options.ok(layer);
    },

    _errorChooser: function() {
      this.model.set("enabled", true);
    },

    _ok: function(ev) {
      if (ev && ev.preventDefault) ev.preventDefault();

      var val = this.basemap_panes.activePane.$el.find("input[type='text']").val();

      if (this.model.get("enabled")) {
        this.model.set("enabled", false);

        this.basemap_panes.activePane.checkTileJson(val);
      }
    }
  });