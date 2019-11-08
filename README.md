
<!-- README.md is generated from README.Rmd. Please edit that file -->

# shinytree <img src="man/figures/example.png" align="right" width="225" />

[![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![Travis CI build
status](https://travis-ci.org/stefanieschneider/shinytree.svg?branch=master)](https://travis-ci.org/stefanieschneider/shinytree)
[![AppVeyor build
status](https://ci.appveyor.com/api/projects/status/github/stefanieschneider/shinytree?branch=master&svg=true)](https://ci.appveyor.com/project/stefanieschneider/shinytree)

## Overview

This R package creates tree widgets using the JavaScript library
[jsTree](https://github.com/vakata/jstree), e.g., in Shiny. The
[jsTree](https://github.com/vakata/jstree) library has been included.
shinytree is built on top of [Bootstrap](https://getbootstrap.com/) and
supports
[jQuery.NiceScroll](https://github.com/inuyaksa/jquery.nicescroll).
Please be aware that this R package is a more lightweight alternative to
[shinyTree](https://github.com/shinyTree/shinyTree) and thus does not
implement methods to create or convert trees or tree-like structures.

If `search` is added as a plugin, two additional functions are
automatically activated: one button to select search results; another
one to reset the tree, i.e., collapse all opened leaves and remove a
currently active search.

## Installation

You can install the development version of shinytree from
[GitHub](https://github.com/stefanieschneider/shinytree):

``` r
# install.packages("devtools")
devtools::install_github("stefanieschneider/shinytree")
```

## Usage

``` r
if (interactive()) {
  library(shiny)
  library(shinytree)

  get_codes <- function(codes, file) {
    get_code <- function(code, connect) {
      value <- tryCatch(
        {
          query <- sprintf(
            "SELECT * FROM database WHERE code = '%s'",
            gsub("'", "''", code, ignore.case = TRUE)
          )

          result <- DBI::dbGetQuery(connect, query)

          parent <- rjson::fromJSON(result[["p"]])
          parent <- tail(parent, n = 1)

          if (length(parent) == 0) parent <- "#"

          children <- rjson::fromJSON(result[["c"]])
          text <- rjson::fromJSON(result[["txt"]])$en
          n_ex <- rjson::fromJSON(result[["n_ex"]])

          text <- paste0("<code>", code, "</code> ", text)

          result <- list(
            id = code, parent = parent,
            children = children, text = text
          )

          if (n_ex == 0) {
            result[["state"]] <- list("disabled" = TRUE)
          }

          return(result)
        }, error = function(error) {
          cat(sprintf("Error for code %s.", code))

          return(NULL)
        }, warning = function(warning) {
          cat(sprintf("Warning for code %s.", code))

          return(NULL)
        }
      )

      return(value)
    }

    connect <- DBI::dbConnect(RSQLite::SQLite(), file)

    results <- sapply(
      codes, get_code, connect = connect,
      simplify = FALSE, USE.NAMES = FALSE
    )

    DBI::dbDisconnect(connect)
    names(results) <- codes

    return(results)
  }

  get_children <- function(codes, file) {
    results <- unlist(lapply(codes, function(x) x$children))

    return(get_codes(results, file = file))
  }

  search_codes <- function(query, file) {
    connect <- DBI::dbConnect(RSQLite::SQLite(), file)

    query <- paste0(
      "SELECT code, p, c FROM database WHERE txt like '%",
      gsub("'", "''", query), "%' COLLATE NOCASE ORDER BY",
      " code LIMIT 100"
    )

    results <- DBI::dbGetQuery(connect, query)
    DBI::dbDisconnect(connect)

    parents <- sapply(results[[2]], rjson::fromJSON)
    children <- sapply(results[[3]], rjson::fromJSON)

    results <- c(unlist(unname(parents)), results[[1]])
    results <- c(results, unlist(unname(children)))

    return(unique(results))
  }

  file_path <- system.file("extdata", package = "shinytree")

  file <- list.files(
    file_path, pattern = "sqlite$", full.names = TRUE
  )[1]

  ui <- fluidPage(
    style = "background-color: #eeeeee; padding: 30px 15px;",
    column(4, treeOutput("tree", height = "400px"))
  )

  server <- function(input, output, session) {
    values <- reactiveValues(
      data = {
        codes <- get_codes(as.character(0:9), file)
        children <- get_children(codes, file)

        c(codes, children)
      }
    )

    observeEvent(input$tree_selected_id, {
      print(input$tree_selected_id)
      print(input$tree_selected_text)
      print(input$tree_selected_state)
      print(input$tree_selected_children)
    })

    observeEvent(input$tree_checked_id, {
      print(input$tree_checked_id)
    })

    observeEvent(input$tree_search, {
      if (nchar(input$tree_search) > 2) {
        codes <- search_codes(input$tree_search, file)
        codes <- get_codes(codes, file = file)

        children_1 <- get_children(codes, file)
        children_2 <- get_children(children_1, file)

        values$data <- c(
          values$data, codes, children_1, children_2
        )
      }
    })

    observeEvent(input$tree_opened_id, {
      children <- input$tree_opened_children
      codes <- names(values$data) %in% children

      children <- get_children(values$data[codes], file)
      codes <- names(children) %in% names(values$data)

      if (sum(!codes) > 0) {
        values$data <- c(values$data, children[!codes])
      }
    })

    output$tree <- renderTree({
      tree(
        unique(values$data[order(names(values$data))]),
        plugins = c("search", "wholerow", "checkbox"),
        options = list(
          "themes" = list("dots" = FALSE, "icons" = FALSE),
          "check_callback" = TRUE, "scrollbar" = TRUE
        )
      )
    })
  }

  shinyApp(ui, server)
}
```

## Contributing

Please report issues, feature requests, and questions to the [GitHub
issue tracker](https://github.com/stefanieschneider/shinytree/issues).
We have a [Contributor Code of
Conduct](https://github.com/stefanieschneider/shinytree/blob/master/CODE_OF_CONDUCT.md).
By participating in shinytree you agree to abide by its terms.
