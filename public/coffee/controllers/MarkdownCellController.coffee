define [
	"app"
], (App) ->
	App.controller "MarkdownCellController", ($scope, $sce) ->
		$scope.switchToInput = () ->
			$scope.mode = "input"
			setTimeout () ->
				$scope.$broadcast "cell.focus"
			, 0
		$scope.switchToOutput = () ->
			$scope.mode = "output"
		$scope.switchToOutput()
		
		$scope.onCellChange = (change, lines) ->
			$scope.renderMarkdown(lines.join("\n"))
			$scope.$apply()
			
		$scope.html = ""
		$scope.renderMarkdown = (markdown) ->
			$scope.html = $sce.trustAsHtml(marked(markdown))
			
			