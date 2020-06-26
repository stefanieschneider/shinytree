#' @title Create a Tree Widget Using the JavaScript Library jsTree
#'
#' @description Create a tree widget using the JavaScript library jsTree.
#'
#' @param data A list with a tree-like structure, either in the standard or the
#' alternative format; see \url{https://www.jstree.com/docs/json/}.
#' @param options A list of initialization options, e.g., to control the looks
#' of jsTree; see \url{https://www.jstree.com/api/}.
#' @param plugins A list of plugins to enable further functionality of jsTree;
#' see \url{https://www.jstree.com/plugins/}.
#' @param width The width of the input container, e.g., \code{'100\%'}; see
#' \link{validateCssUnit}.
#' @param height The height of the input container, e.g., \code{'200px'}; see
#' \link{validateCssUnit}.
#'
#' @return A tree widget that can be added to a UI definition.
#'
#' @references See \url{https://www.jstree.com/} for the full documentation.
#'
#' @importFrom utils modifyList
#' @import rmarkdown
#'
#' @export
tree <- function(
  data, options = list(), plugins = NULL, width = NULL, height = NULL
) {
  options <- modifyList(getOption("jsTree.options", list()), options)

  search <- "search" %in% plugins; menu <- "menu" %in% plugins
  if (search | menu) options[["force_text"]] <- FALSE

  if (is.list(data)) {
    data <- lapply(data, remove_values, search = search, menu = menu)
  } else {
    stop("Object `data` is not of type `list`.")
  }

  options[["data"]] <- unname(data, force = TRUE)
  if (is.null(options$loading)) options$loading <- FALSE

  dependencies <- list(
    rmarkdown::html_dependency_jquery()
    # rmarkdown::html_dependency_bootstrap("default")
  )

  htmlwidgets::createWidget(
    "tree", list(options = options, plugins = plugins),
    width = width, height = height, dependencies = dependencies
  )
}

remove_values <- function(x, search = FALSE, menu = FALSE) {
  button <- "<button class=\"%s\"><i class=\"%s\"></i></button>"

  valid_keys <- c(
    "id", "parent", "text", "state", "li_attr", "a_attr",
    "type", "opened", "disabled", "selected"
  )

  if (search) {
    title <- trimws(gsub(".*>", "", x[["text"]]))

    x[["text"]] <- sprintf(
      "<span title=\"%s\">%s</span>", title, x[["text"]]
    )
  }

  if (is.null(x[["state"]]) & grepl("</i>", x[["text"]])) {
    x[["state"]] <- list("disabled" = TRUE)
  } else {
    if (menu) {
      new_button <- sprintf(button, "add", "fa fa-plus-circle")
      x[["text"]] <- paste0(x[["text"]], new_button)
    }
  }

  if (menu) {
    new_button <- sprintf(button, "remove", "fa fa-minus-circle")
    x[["text"]] <- paste0(x[["text"]], new_button)
  }

  return(x[names(x) %in% valid_keys])
}
