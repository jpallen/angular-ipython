define [
	"app"
	"directives/ipEditor"
	"controllers/MarkdownCellController"
], (App) ->
	App.controller "NotebookController", ($scope, $http) ->
		$http.get("/data/XKCD_plots.ipynb")
			.success (notebook) ->
				# Strip newlines
				for worksheet in notebook.worksheets
					for cell in worksheet.cells
						if cell.source?
							cell.source = cell.source.join("").split("\n")
						if cell.input?
							cell.input = cell.input.join("").split("\n")
				
				socket = new BCSocket(null, {reconnect: true})
				share = new sharejs.Connection(socket)
				
				doc = share.get('ipython', 'xkcd');
				doc.subscribe()
				doc.whenReady () ->
					if (!doc.type)
						doc.create('json0', notebook)
					console.log('doc ready, data: ', doc.getSnapshot())	
					$scope.notebook = doc.getSnapshot()
					$scope.$apply()
					
				doc.on "after op", (ops, local) ->
					if !local
						for op in ops
							if op.p[0] == "worksheets" and op.p[2] == "cells"
								if (op.si? or op.sd?) # Insert or remove text
									# Get the row and column from the end of the path to create an op that is local to the cell
									path = op.p.slice(0, -2)
									op.p = op.p.slice(-2)
								else if op.ld? or op.li? # Insert or remove lines
									# Get the line index
									path = op.p.slice(0, -1)
									op.p = op.p.slice(-1)
								$scope.$broadcast "notebook.change." + path.join("."), op
					
				queuedOps = []
				$scope.$on "notebook.change", (e, path, ops) ->
					for op in ops
						op.p = path.split(".").concat(op.p)
					queuedOps = queuedOps.concat(ops)
					setTimeout () ->
						if queuedOps.length > 0
							console.log "Submitting Op", queuedOps
							doc.submitOp queuedOps
							queuedOps = []
					, 0
					
		
	angular.bootstrap(document.body, ["ipython"])