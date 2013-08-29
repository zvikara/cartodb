
  /**
   *  WMS pane for import a file
   */


  cdb.admin.WMSBasemapChooserPane = cdb.admin.BasemapChooserPane.extend({
    className: "basemap-pane",

    events: {
      'focusin input[type="text"]' : "_focusIn",
      'focusout input[type="text"]': "_focusOut",
      'keyup input[type="text"]'   : "_onInputChange",
      'paste input[type="text"]'   : "_onInputPaste"
    },

    initialize: function() {
      _.bindAll(this, "_errorChooser", "_onInputChange", "checkWMSTemplate");

      this.template = this.options.template || cdb.templates.getTemplate('table/views/basemap_chooser/basemap_chooser_pane');
      this.render();
    },

    render: function() {
      this.$el.html(this.template({
        placeholder: 'Insert your WMS base URL',
        error: 'Your WMS base URL is not valid.'
      }));
      return this;
    },

    // If url input change, hide uploader
    _onInputPaste: function(e) {
      // Hack necessary to get input value after a paste event
      // Paste event is fired before text is applied / added to the input
      setTimeout(this._onInputChange,100);
    },

    _onInputChange: function(e) {
      var $el = this.$("input[type='text']")
        , val = $el.val();

      // If form is submitted, go out!
      if (e && e.keyCode == 13) {
        return false;
      }

      if (val == "") {
        this._hideLoader();
        this._hideError();
        this.trigger('inputChange', '', this);
      } else {
        this.trigger('inputChange', val, this);
      }
    },

    /**
     * Hide loader
     */
    _hideLoader: function() {
      this.$el.find("div.loader").hide();
    },

    /**
     * Show loader
     */
    _showLoader: function() {
      this.$el.find("div.loader").show();
    },

    _hideError: function() {
      this.$el.find("input").removeClass("error");
      this.$("div.info").removeClass("error active")
    },

    _showError: function() {
      this.$el.find("input").addClass("error");
      this.$el.find("div.info").addClass("error active");
    },

    /**
     * return a https url if the current application is loaded from https
     */
    _fixHTTPS: function(url, loc) {
      loc = loc || location;

      // fix the url to https or http
      if (url.indexOf('https') !== 0 && loc.protocol === 'https:') {
        // search for mapping
        return url.replace(/http/, 'https');
      }
      return url;
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

    _lowerXYZ: function(url) {
      return url.replace(/\{S\}/g, "{s}")
        .replace(/\{X\}/g, "{x}")
        .replace(/\{Y\}/g, "{y}")
        .replace(/\{Z\}/g, "{z}");
    },

    /**
     * this function checks that the url is correct and returns a valid JSON
     * https://github.com/Vizzuality/cartodb-management/wiki/WMS-JSON-format
     */
    checkWMSTemplate: function(val) {
      var self = this;

      var _val = {
        wms_server: "http://basemap.nationalmap.gov/arcgis/services/USGSImageryTopo/MapServer/WMSServer",
        supported_formats: ["image/jpeg", "image/png"],
        layers: [
          { 
            name: "layer 1",
            attribution: "attribution message"
          },
          { 
            name: "layer 2",
            attribution: "attribution message"
          }
         ]
      }

      // Remove error
      this._hideError();

      // Start loader
      this._showLoader();

      // TODO: wms url (val) -> json (url)

        var errorTimeout = setTimeout(function() {
          debugger;
          // Handle error accordingly
          // alert("Houston, we have a problem.");
        }, 2000);

        $.ajax({
          type: "GET",
          url: url,
          dataType: 'jsonp',
          success: function(data) {
            clearTimeout(errorTimeout);
            self.trigger('successChooser');
          },
          error: function() {
            clearTimeout(errorTimeout);
            self._errorChooser();
          }
        });


      $.ajax({
        type: "GET",
        // url: url,
        url: val,
        dataType: 'jsonp',
        success: function(data) {
          self.trigger('successWMSChooser', _val);
        },
        error: function() {
          self._errorChooser();
        }
      });
    },

    /**
     * If the url is not valid
     */
    _errorChooser: function(e) {
      debugger;
      var $input = this.$el.find("input");

      // End loader
      this._hideLoader();

      // Show error
      this._showError();

      // Enable input
      $input.attr("disabled");

      // Enable dialog? nop!
      this.trigger('errorChooser');
    }
  });
