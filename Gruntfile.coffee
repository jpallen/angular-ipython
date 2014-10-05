module.exports = (grunt) ->
	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-contrib-clean'
	grunt.loadNpmTasks 'grunt-execute'
	
	grunt.initConfig
		execute:
			app:
				src: "app.js"

		coffee:
			client:
				expand: true,
				flatten: false,
				cwd: 'public/coffee',
				src: ['**/*.coffee'],
				dest: 'public/js/',
				ext: '.js'
		
			app:
				src: "app.coffee"
				dest: "app.js" 

		clean:
			app: ["public/js"]
			
	grunt.registerTask "run", ["clean", "coffee", "execute"]