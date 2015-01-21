var $ = require('jquery');
var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');

/**
 *  Onboarding view
 *
 *  It includes:
 *  - onboard map (rendered when element is visible)
 *  - welcome text (visible checking local storage)
 *
 */


module.exports = cdb.core.View.extend({

  tagName: 'div',
  className: 'OnBoarding',

  events: {
    'click .js--welcomeButton': '_hideWelcome'
  },

  initialize: function() {
    this.user = this.options.user;
    this.localStorage = this.options.localStorage;
    this.template = cdb.templates.getTemplate('new_dashboard/views/onboarding');
    this._resizeMap();
    this._initBindings();
  },

  render: function() {
    this.$el.append(
      this.template({
        renderContent: !this.localStorage.get('dashboard.welcome'), 
        username: this.user.get('name') || this.user.get('username')
      })
    );

    this._checkWelcome();

    return this;
  },

  _checkWelcome: function() {
    if (!this.localStorage.get('dashboard.welcome')) {
      this._showWelcome();
    }
  },

  _showWelcome: function(e) {
    if (e) e.preventDefault();
    $('body').addClass('is-inDialog');
  },

  _hideWelcome: function(e) {
    if (e) e.preventDefault();
    this.localStorage.set({ 'dashboard.welcome': true });
    $('body').removeClass('is-inDialog');
    this.$('.OnBoarding-welcome').animate({
      opacity: 0
    }, 500, function() {
      $(this).remove();
    });
  },

  _renderMap: function() {
    if (this.map) return;

    var layer = L.tileLayer('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png');

    this.map = L.map(this.$('.js-onboarding-map')[0], {
      scrollWheelZoom: false,
      zoomControl: false,
      center: [40.7127837, -74.0059413],
      zoom: 6,
      maxZoom: 15
    });

    this.map.addLayer(layer);
  },

  _destroyMap: function() {
    if (this.map) {
      this.map.remove();
    }
  },

  _initBindings: function() {
    _.bindAll(this, '_resizeMap');
    $(window).on('resize', this._resizeMap);
  },

  _resizeMap: function() {
    this.$el.height( window.innerHeight - 164 );
  },

  show: function() {
    this.$el.show();
    // We need to have element visible in order
    // to render leaflet map properly
    this._renderMap();
  },

  hide: function() {
    this.$el.hide();
  },

  clean: function() {
    this._destroyMap();
    $(window).off('resize', this._resizeMap);
    cdb.core.View.prototype.clean.call(this);
  }

});