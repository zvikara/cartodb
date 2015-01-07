
  /**
   *  Generate static image
   *
   *  new cdb.admin.StaticImageDialog({
   *    vis: visualization_model,
   *    user: user_model
   *  })
   *
   */

cdb.admin.StaticImageDialog = cdb.admin.BaseDialog.extend({

  events: {
    'click .ok':      '_ok',
    'click .cancel':  '_cancel',
    'click .close':   '_cancel'
  },

  _TEXTS: {
    title:       _t('Configure export options'),
    description: _t("The image will be centered using the map's current center"),
    ok:          _t('Export image')
  },

  initialize: function() {

    // Generate new model
    this.vis = this.options.vis;
    this.user = this.options.user;
    this.model = _.clone(this.vis);

    delete this.model.id;

    // Extend options
    _.extend(this.options, {
      title: this._TEXTS.title,
      description: this._TEXTS.description,
      width: 352,
      clean_on_hide: true,
      capture_width: this.options.width,
      capture_height: this.options.height,
      template_name: 'table/views/static_image_dialog',
      ok_title: this._TEXTS.ok,
      ok_button_classes: 'button grey',
      modal_class: 'static_image_dialog'
    });

    this.constructor.__super__.initialize.apply(this);
  },

  render: function() {
    this.$el.append(this.template_base( _.extend( this.options )));

    this.$(".modal").css({ width: this.options.width });
    this.render_content();

    if (this.options.modal_class) {
      this.$el.addClass(this.options.modal_class);
    }

    return this;
  },

  /**
   * Render the content for the metadata dialog
   */
  render_content: function() {
    var self = this;

    // Tags
    _.each(this.model.get('tags'), function(li) {
      this.$("ul").append("<li>" + li + "</li>");
    }, this);

    this.$("ul").tagit({
      allowSpaces:      true,
      onBlur: function() {
        self.$('ul').removeClass('focus')
      },
      onFocus: function() {
        self.$('ul').addClass('focus')
      },
      onSubmitTags: this.ok
    });

    // jScrollPane
    setTimeout(function() {
      self.$('.metadata_list').jScrollPane({ verticalDragMinHeight: 20 });

      // Gradients
      var gradients = new cdb.common.ScrollPaneGradient({
        list: self.$('.metadata_list')
      });
      self.$('.metadata_list').append(gradients.render().el);
      self.addView(gradients);
    },0);

    return false;
  },

  _keydown: function(e) {
    if (e.keyCode === 27) this._cancel();
  },

  _getURL: function() {

    var endpoint = "http://santiago-st.cartodb-staging.com/api/v1/map";

    var layergroup_id = this.options.layergroup_id;

    var file_format = "png";

    var zoom        = this.vis.map.get("zoom");
    var lat         = this.vis.map.get("center")[0];
    var lng         = this.vis.map.get("center")[1];

    var width       = this.$el.find('input[name="width"]').val();
    var height      = this.$el.find('input[name="height"]').val();
 
    var path = [
      endpoint,
      'static',
      'center',
      layergroup_id,
      zoom,
      lat,
      lng,
      width,
      height
    ].join('/');

    return path + '.' + file_format;

  },

  _ok: function(e) {
    this.killEvent(e);

    var url = this._getURL();

    var win = window.open(url, '_blank');

  },

  _showConfirmation: function() {
    this.$("section.modal:eq(0)")
    .animate({
      top:0,
      opacity: 0
    }, 300, function() {
      $(this).slideUp(300);
    });


    this.$(".modal.confirmation")
    .css({
      top: '50%',
      marginTop: this.$(".modal.confirmation").height() / 2,
      display: 'block',
      opacity: 0
    })
    .delay(200)
    .animate({
      marginTop: -( this.$(".modal.confirmation").height() / 2 ),
      opacity: 1
    }, 300);
  },

  // Clean methods
  _destroyCustomElements: function() {
    // Destroy tagit
    this.$('ul').tagit('destroy');
    // Destroy jscrollpane
    this.$('.metadata_list').data() && this.$('.metadata_list').data().jsp && this.$('.metadata_list').data().jsp.destroy();
  },

  clean: function() {
    this._destroyCustomElements();
    cdb.admin.BaseDialog.prototype.clean.call(this);
  }

});
