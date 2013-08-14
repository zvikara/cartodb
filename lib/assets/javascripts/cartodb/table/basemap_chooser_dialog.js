
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

    _MAPBOX: {
      version: 3,
      https: 'https://dnv9my2eseobd.cloudfront.net',
      base: 'http://a.tiles.mapbox.com/'
    },

    _WAITING_INPUT_TIME: 1000,

    events: {
      "keydown input": "_checkEnter",
      "focusin input": "_focusIn",
      "focusout input": "_focusOut",
      "keyup input[type='text']" : "_onInputChange",
      "paste input[type='text']" : "_onInputPaste",
      "click .ok.button": "ok",
      "click .cancel": "_cancel",
      "click .close": "_cancel"
    },

    initialize: function() {
      _.bindAll(this, "_checkTileJson", "_successChooser", "_successWMSChooser", "_errorChooser", "_showLoader",
        "_hideLoader", "_onInputPaste", "_onInputChange");

      _.extend(this.options, {
        title: this._TEXTS.title,
        description: this._TEXTS.description,
        clean_on_hide: true,
        cancel_button_classes: "margin15",
        ok_button_classes: "button grey",
        ok_title: this._TEXTS.ok,
        modal_type: "compressed",
        width: 512,
        modal_class: 'basemap_chooser_dialog'
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
      this.mapboxPane.bind('inputChange', this._checkOKButton);

      // ZXY
      this.zxyPane = new cdb.admin.ZXYBasemapChooserPane();
      this.zxyPane.bind('inputChange', this._checkOKButton);

      // WMS
      this.wmsPane = new cdb.admin.WMSBasemapChooserPane();
      this.wmsPane.bind('inputChange', this._checkOKButton);

      // Create TabPane
      this.basemap_panes = new cdb.ui.common.TabPane({
        el: $content.find(".basemap-panes")
      });
      this.basemap_panes.addTab('mapbox', this.mapboxPane);
      this.basemap_panes.addTab('zxy', this.zxyPane);
      this.basemap_panes.addTab('wms', this.wmsPane);
      this.basemap_panes.bind('tabEnabled', this._onTabClick, this);

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
    //   UI   //
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

    _onTabClick: function() {
      this.$el.find("input").val("");
      this._hideError();
      this._checkOKButton();
    },

    _onInputPaste: function(e) {
      // Hack necessary to get input value after a paste event
      // Paste event is fired before text is applied / added to the input
      setTimeout(this._onInputChange,100);
    },

    _onInputChange: function(e) {
      var $el = this.basemap_panes.activePane.$el.find("input[type='text']")
        , val = $el.val();

      // If form is submitted, go out!
      if (e && e.keyCode == 13) {
        return false;
      }

      if (val == "") {
        this._hideLoader();
        this._hideError();
        this._checkOKButton();
      } else {
        this._checkOKButton();
      }
    },

    /**
     * Check enter keydown
     */
    _checkEnter: function(ev) {
      // If it is a enter... nothing
      var code = (ev.keyCode ? ev.keyCode : ev.which);
      if (code == 13) {
        this.killEvent(ev);
        this.ok();
      }
    },


    /**
     * Style box when user focuses in/out over the input
     */
    _focusIn: function(ev) {
      $(ev.target)
        .closest('div.input')
        .addClass('active')
    },
    _focusOut: function(ev) {
      $(ev.target)
        .closest('div.input')
        .removeClass('active')
    },


    /**
     * If the url is not valid
     */
    _errorChooser: function(e) {
      var $input = this.$el.find("input");

      // End loader
      this._hideLoader();

      // Show error
      this._showError();

      // Enable input
      $input.attr("disabled");

      // Enable dialog? nop!
      this.$("a.button.ok").removeClass("disabled");
      this.model.set("enabled", true);
    },


    /**
     * If the url is valid
     */
    _successChooser: function(data) {
      // End loader
      this._hideLoader();

      // Check if the respond is an array
      // In that case, get only the first
      if (_.isArray(data) && _.size(data) > 0) {
        data = _.first(data);
      }

      var layer = new cdb.admin.TileLayer({
        urlTemplate: data.tiles[0],
        attribution: data.attribution || null,
        maxZoom: data.maxzoom || 21,
        minZoom: data.minzoom || 0,
        name: data.name || ''
      });

      // Set the className from the urlTemplate of the basemap
      layer.set("className", layer._generateClassName(data.tiles[0]));

      // do not save before add because the layer collection
      // has the correct url
      this.options.baseLayers.add(layer);
      layer.save();

      // Remove error
      this._hideError();

      this.hide();
      this.options.ok && this.options.ok(layer);
    },

    _successWMSChooser: function() {
      this._hideLoader();

      this.basemap_panes.removeTab('wms');
      this.wmsNewPane = new cdb.admin.WMSBasemapChooserPane({template: cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_wms_pane')});
      this.basemap_panes.addTab('wms', this.wmsNewPane);

      this.$el.find(".scrollpane").jScrollPane();

      this.model.set("enabled", true);
    },

    _showError: function() {
      this.$el.find("input").addClass("error");
      this.$el.find("div.info").addClass("error active");
    },

    _hideError: function() {
      this.$el.find("input").removeClass("error");
      this.$("div.info").removeClass("error active")
    },

    /**
     * Show loader
     */
    _showLoader: function() {
      this.$el.find("div.loader").show();
    },


    /**
     * Hide loader
     */
    _hideLoader: function() {
      this.$el.find("div.loader").hide();
    },

    /**
     * return a https url if the current application is loaded form https
     */
    _fixHTTPS: function(url, loc) {
      loc = loc || location;

      // fix the url to https or http
      if (url.indexOf('https') !== 0 && loc.protocol === 'https:') {
        // search for mapping
        var i = url.indexOf('mapbox.com');
        if (i != -1) {
            return this._MAPBOX_HTTPS + url.substr(i + 'mapbox.com'.length);
        }
        return url.replace(/http/, 'https');
      }
      return url;
    },


    transformMapboxUrl: function(url) {
      // http://d.tiles.mapbox.com/v3/{user}.{map}/3/4/3.png
      // http://a.tiles.mapbox.com/v3/{user}.{map}/page.html
      var reg1 = /http:\/\/[a-z]?\.?tiles\.mapbox.com\/v(\d)\/(.*?)\//;

      // https://tiles.mapbox.com/{user}/edit/{map}?newmap&preset=Streets#3/0.00/-0.09
      var reg2 = /https?:\/\/tiles\.mapbox\.com\/(.*?)\/edit\/(.*?)(\?|#)/;


      var match = '';

        // Check first expresion
      match = url.match(reg1);
      if (match && match[1] && match[2]) {
        return this._MAPBOX.base + "v" + match[1] + "/" + match[2] + "/{z}/{x}/{y}.png";
      }

      // Check second expresion
      match = url.match(reg2);
      if (match && match[1] && match[2]) {
        return this._MAPBOX.base + "v" + this._MAPBOX.version + "/" + match[1] + "." + match[2] + "/{z}/{x}/{y}.png";
      }

      return url;
    },

    /**
     * this function checks that the url is correct and tries to get the tilejson
     */
    _checkTileJson: function(ev, tile) {
      var $input = this.$el.find('input'),
        url = this._lowerXYZ($input.val()),
        self = this,
        type = 'json',
        subdomains = ['a', 'b', 'c'];

      // Remove error
      this._hideError();

      // Start loader
      this._showLoader();

      // Disable input
      $input.attr("disabled");

      if(tile === 'wms') {
        this._successWMSChooser();
      } else {
        // Detects the URL's tile (mapbox, xyz or json)
        if (url.indexOf('{x}') < 0 && url.indexOf('tiles.mapbox.com') != -1) {

          type = "mapbox";
          url = this.transformMapboxUrl(url);

        } else if (url.indexOf("{x}") != -1) {

          type = 'xyz';

          url = url.replace(/\{s\}/g, function() {
              return subdomains[Math.floor(Math.random() * 3)]
          })
          .replace(/\{x\}/g, "0")
          .replace(/\{y\}/g, "0")
          .replace(/\{z\}/g, "0");

        } else if (url && url.indexOf('http') == -1 && url.match(/(.*?)\.(.*)/) != null && url.match(/(.*?)\.(.*)/).length == 3) {
          type = 'mapbox_id';

        } else { // If not, check https
          url = this._fixHTTPS(url);
        }

        if (type == 'mapbox') {

          this._successChooser({ tiles: [url] });

        } else if (type == "xyz") {

          var image = new Image();

          image.onload = function(e) {
            self._successChooser({
              tiles: [self._lowerXYZ($input.val())]
            })
          }

          image.onerror = this._errorChooser;
          image.src = url;

        } else if (type == "mapbox_id") {
          
          var image = new Image();

          image.onload = function(e) {
            self._successChooser({
              tiles: [self._lowerXYZ($input.val())]
            })
          }

          image.onerror = this._errorChooser;

          var match = url.match(/(.*?)\.(.*)/);
          url = this._MAPBOX.base + "v" + this._MAPBOX.version + "/" + match[1] + "." + match[2] + "/0/0/0.png";

          image.src = url;

        } else { // type json

          $.ajax({
            type: "GET",
            url: url,
            dataType: 'jsonp',
            success: this._successChooser,
            error: this._errorChooser
          });
        }
      }
    },

    _lowerXYZ: function(url) {
      return url.replace(/\{S\}/g, "{s}")
        .replace(/\{X\}/g, "{x}")
        .replace(/\{Y\}/g, "{y}")
        .replace(/\{Z\}/g, "{z}");
    },

    /**
     * Click on OK button
     */
    ok: function(ev) {

      if (ev && ev.preventDefault) ev.preventDefault();

      var val = this.basemap_panes.activePane.$el.find("input[type='text']").val();

      if (this.model.get("enabled")) {
        this.model.set("enabled", false);
        this._checkTileJson(ev, this.basemap_panes.activeTab);
      }
    }
  });