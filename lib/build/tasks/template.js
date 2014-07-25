
  /**
   *  Template task config
   */

  exports.task = function() {

    return {
      'process-html-template': {
        'options': {
          'data': {
            'title': 'My blog post',
            'author': 'Mathias Bynens',
            'content': 'Lorem ipsum dolor sit amet.',
            'url': '<%= pkg.version %>'
          }
        },
        'files': {
          '../../public/assets/<%= pkg.version %>/pages/404.html': ['../../app/assets/statics/error.html.tpl']
        }
      }
    }

  }


