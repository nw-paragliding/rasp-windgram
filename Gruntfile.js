/*global module:false*/
module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({

    timestamp: new Date().getTime(),
    pkg: grunt.file.readJSON('package.json'),

    copy: {
      css: {
        expand: true,
        src: 'wwwroot\\v2\\*.css',
        dest: 'publish\\wwwroot\\v2\\',
      },
      json: {
        expand: true,
        src: 'wwwroot\\v2\\json\\*.json',
        dest: 'publish\\wwwroot\\v2\\',
      },
      lib: {
        expand: true,
        src: 'wwwroot/v2/lib/*',
        dest: 'publish\\wwwroot\\v2\\',
      },
    },

    replace: {
      html: {
        src: ['wwwroot/v2/*.html'],
        dest: 'publish/wwwroot/v2/',             
        replacements: [{
          from: '{{timestamp}}',
          to: '<%= timestamp %>'
        }]
      },
      js: {
        src: ['wwwroot/v2/js/*.js'],
        dest: 'publish/wwwroot/v2/js/',             
        replacements: [{
          from: '{{timestamp}}',
          to: '<%= timestamp %>'
        }]
      }
    }

  });

  // These plugins provide necessary tasks.
  grunt.loadNpmTasks('grunt-contrib-concat');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-qunit');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-text-replace');

  // Default task.
  grunt.registerTask('default', ['copy', 'replace']);

};
