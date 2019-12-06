#' Helper Functions for Using Shinytree in Shiny
#'
#' These functions are like most \code{fooOutput()} and \code{renderFoo()}
#' functions in the \pkg{shiny} package. The former is used to create a
#' container for a tree, and the latter is used in the server logic to
#' render the tree.
#'
#' @param outputId The \code{output} slot that will be used to access the
#' values.
#' @param width The width of the input container, e.g., \code{'100\%'}; see
#' \link{validateCssUnit}.
#' @param height The height of the input container, e.g., \code{'200px'}; see
#' \link{validateCssUnit}.
#'
#' @examples
#' \donttest{
#' inst/examples/tree.R
#' }
#'
#' @importFrom htmlwidgets shinyWidgetOutput
#' @export
treeOutput <- function(outputId, width = "100%", height = "100%") {
  shinyWidgetOutput(
    outputId, "tree", width, height, package = "shinytree"
  )
}

#' @param expr An expression to create a tree widget (via \code{tree()}),
#' or a data object to be passed to \code{tree()} to create a tree widget.
#' @param env The environment in which to evaluate \code{expr}.
#' @param quoted Is \code{expr} a quoted expression (with \code{quote()})?
#' This is useful if you want to save an expression in a variable.
#'
#' @importFrom htmlwidgets shinyRenderWidget
#'
#' @rdname treeOutput
#' @export
renderTree <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr) # force quoted
  shinyRenderWidget(expr, treeOutput, env, quoted = TRUE)
}

#' @importFrom shiny getDefaultReactiveDomain
callJS <- function() {
  message <- Filter(
    function(x) !is.symbol(x), as.list(parent.frame(1))
  )

  session <- getDefaultReactiveDomain()
  method <- paste0("tree:", message$method)

  session$sendCustomMessage(method, message)
}

.onLoad <- function(libname, pkgname) {
  shiny::registerInputHandler("shinytree.data", function(data, ...) {
    if ("type" %in% names(data[[1]])) {
      data <- matrix(unlist(data), ncol = 5, byrow = TRUE)
    } else {
      data <- matrix(unlist(data), ncol = 4, byrow = TRUE)
    }

    data <- data.frame(data, stringsAsFactors = FALSE)

    colnames(data)[1:4] <- c("id", "text", "icon", "parent")
    data$text <- gsub("^[^>]*>(.*)<\\/span>.*", "\\1", data$text)

    data[, c("id", "parent", "text")]
  })
}
