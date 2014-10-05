define [
	"app"
], (App) ->
	App.directive "ipEditor", () ->
		return {
			scope: {
				ipLines: "="
				ipPath:  "@"
				ipEditorMode: "@"
				ipEditorOnChange: "="
				ipEditorOnBlur: "="
			}
			
			link: ($scope, $el, $attrs) ->			
				$editorEl = $($el).find(".ace-editor")
				editor = ace.edit($editorEl[0])
				editor.setShowPrintMargin(false)
				editor.getSession().setUseWrapMode(true)
				editor.getSession().setMode("ace/mode/#{$scope.ipEditorMode}")
				editor.renderer.setShowGutter(false)
				
				ignoreChanges = false
				previousLines = editor.getSession().getDocument().getAllLines()
				editor.on "change", (update) ->
					# Keep the editor pane as large as the contents so there is no scroll bar
					lines = editor.getSession().getScreenLength()
					lineHeight = editor.renderer.lineHeight
					height = lines * lineHeight
					$editorEl.height(height)
					$($el).height(height)
					editor.resize()
					
					lines = editor.getSession().getDocument().getAllLines()
					
					if $scope.ipEditorOnChange? and typeof($scope.ipEditorOnChange) == "function"
						$scope.ipEditorOnChange(update, lines)
					
					if !ignoreChanges
						op = Codec.aceDeltaToShareJs update.data, previousLines
						$scope.$emit "notebook.change", $scope.ipPath, op

					previousLines = lines
					
				editor.on "blur", () ->
					if $scope.ipEditorOnBlur? and typeof($scope.ipEditorOnBlur) == "function"
						$scope.ipEditorOnBlur()
						$scope.$apply()
				
				ignoreChanges = true
				editor.setValue($scope.ipLines.join("\n"), -1)
				ignoreChanges = false
				
				$scope.$on "notebook.change." + $scope.ipPath, (event, op) ->
					console.log "Got relevant op!", $scope.ipPath, op
					doc = editor.getSession().getDocument()
					ignoreChanges = true
					Codec.applyShareJsOpToAceDoc op, doc
					ignoreChanges = false
					
				$scope.$on "cell.focus", () ->
					console.log "FOCUSED", $scope.ipPath
					editor.resize()
					editor.focus()
				
			template: """
				<div class="ace-editor"></div>
			"""
		}
		
	Codec =
		aceDeltaToShareJs: (delta, lines) ->
			if delta.action == "insertText"
				if delta.text == "\n" and delta.range.start.row == delta.range.end.row - 1
					# Break this line at the insert point
					thisLine = lines[delta.range.start.row]
					ops = [{
						# Delete any text after the new line insert on this line
						p: [delta.range.start.row, delta.range.start.column]
						sd: thisLine.slice(delta.range.start.column)
					}, {
						# Create a new line below with the trailing text
						p: [delta.range.end.row]
						li: thisLine.slice(delta.range.start.column)
					}]
				else if (delta.range.start.row == delta.range.end.row)
					# Just a regular insert of text on one line
					ops = [{
						p: [delta.range.start.row, delta.range.start.column]
						si: delta.text
					}]
				else
					console.error "Unexpected insertText update", delta
					throw "Unexpected insertText update"
			else if delta.action == "removeText"
				if delta.text == "\n" and delta.range.start.row == delta.range.end.row - 1
					# Concat the line below to this one
					thisLine = lines[delta.range.start.row]
					nextLine  = lines[delta.range.end.row]
					ops = [{
						# Concat the next line to the end of this one
						p: [delta.range.start.row, thisLine.length]
						si: nextLine
					}, {
						# Delete the next line
						p: [delta.range.end.row]
						ld: nextLine
					}]
				else if (delta.range.start.row == delta.range.end.row)
					# Just a regular delete of text on one line
					ops = [{
						p: [delta.range.start.row, delta.range.start.column]
						sd: delta.text
					}]
				else
					console.error "Unexpected removeText update", delta
					throw "Unexpected removeText update"
			else if delta.action == "removeLines"
				ops = []
				# Remove from last to first to preserve indices
				for i in [(delta.lines.length - 1)..0]
					lineNo = delta.range.start.row + i
					line = delta.lines[i]
					
					ops.push {
						p: [ delta.range.start.row + i ]
						ld: line
					}
			else if delta.action == "insertLines"
				ops = []
				for i in [0..(delta.lines.length - 1)]
					lineNo = delta.range.start.row + 1
					line = delta.lines[i]
					
					ops.push {
						p: [ delta.range.start.row + i ]
						li: line
					}
			else
				throw "Unknown delta action: #{delta.action}"
			
			console.log "OP", delta, ops
			
			return ops
			
		applyShareJsOpToAceDoc: (op, doc) ->
			if op.si? # String insert
				doc.insert { row: op.p[0], column: op.p[1] }, op.si
			else if op.sd?
				Range = ace.require("ace/range").Range
				range = new Range(op.p[0], op.p[1], op.p[0], op.p[1] + op.sd.length)
				doc.remove range
			else if op.ld?
				lineNo = op.p[0]
				expectedLine = doc.getLine(lineNo)
				unless expectedLine == op.ld
					console.error("Expected deleted line to match document line", expectedLine, op.ld)
					throw "Expected deleted line to match document line"
				doc.removeLines(lineNo, lineNo)
			else if op.li?
				lineNo = op.p[0]
				line = op.li
				doc.insertLines(lineNo, [line])
			else
				throw "Unknown sharejs op type: #{JSON.stringify(op)}"
