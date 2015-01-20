var cdb = require('cartodb.js');
cdb.admin = require('cdb.admin');



module.exports = cdb.core.Model.extend({

  defaults: {
    queue_id: '',
    state:    ''
  },

  url: '/api/v1/imports',

  idAttribute: 'item_queue_id',

  

  initialize: function() {

  },

  parse: function(r) {
    console.log(r);
  }

});
