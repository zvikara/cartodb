var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');



module.exports = Backbone.collection.extend({

  url: '/api/v1/imports',

  model: ,

  initialize: function() {

  },

  parse: function(r) {
    console.log(r);
  }

});
