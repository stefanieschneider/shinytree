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
      codes, get_code, connect = connect, simplify = FALSE
    )

    DBI::dbDisconnect(connect)
    names(results) <- codes

    return(results)
  }

  get_children <- function(codes, file) {
    if (length(codes) > 0) {
      results <- lapply(codes, function(x) x$children)

      return(get_codes(unlist(results), file))
    }
  }

  get_initial <- function(file) {
    codes <- get_codes(as.character(0:9), file)
    children <- get_children(codes, file)

    return(c(codes, children))
  }

  get_examples <- function(codes, file) {
    codes <- gsub("'", "''", gsub("...)$", "", codes))
    codes <- sprintf("code like '%s%%'", codes)
    codes <- paste(codes, collapse = " OR ")

    connect <- DBI::dbConnect(RSQLite::SQLite(), file)
    query <- paste("SELECT ex FROM database WHERE", codes)

    results <- DBI::dbGetQuery(connect, query)
    DBI::dbDisconnect(connect)

    results <- sapply(
      results[[1]], rjson::fromJSON, USE.NAMES = FALSE
    )

    return(unique(unlist(results)))
  }

  search_codes <- function(term, file) {
    connect <- DBI::dbConnect(RSQLite::SQLite(), file)

    query <- paste0(
      "SELECT code, p, c FROM database WHERE txt like '%",
      gsub("'", "''", term), "%' COLLATE NOCASE ORDER BY",
      " code LIMIT 100"
    )

    results <- DBI::dbGetQuery(connect, query)
    DBI::dbDisconnect(connect)

    if (nrow(results) > 0) {
      parents <- sapply(
        results[[2]], rjson::fromJSON, USE.NAMES = FALSE
      )

      children <- sapply(
        results[[3]], rjson::fromJSON, USE.NAMES = FALSE
      )

      results <- c(unlist(parents), results[[1]])
      results <- c(results, unlist(children))
    } else {
      results <- get_codes(gsub("'", "''", term), file)[[1]]

      if (!is.null(results)) {
        results <- c(results[["parent"]], results[["id"]])
      }
    }

    return(unique(results))
  }

  file_path <- system.file("extdata", package = "shinytree")

  file <- list.files(
    file_path, pattern = "sqlite$", full.names = TRUE
  )

  ui <- fluidPage(
    style = "background-color: #eeeeee; padding: 30px 15px;",
    column(4, treeOutput("tree", height = "400px"))
  )

  server <- function(input, output, session) {
    values <- reactiveValues(data = get_initial(file))

    observeEvent(input$tree_selected_id, {
      print(input$tree_selected_id)
      print(input$tree_selected_text)
      print(input$tree_selected_state)
      print(input$tree_selected_children)
    })

    observeEvent(input$tree_checked_id, {
      examples <- get_examples(input$tree_checked_id, file)
    })

    observeEvent(input$tree_search, {
      if (nchar(input$tree_search) > 2) {
        codes <- search_codes(input$tree_search, file)
        codes <- get_codes(codes, file = file)

        children_1 <- get_children(codes, file)
        children_2 <- get_children(children_1, file)

        values$data <- c(
          values$data, codes, children_1,
          children_2, values$data[1]
        )
      }

      if (nchar(input$tree_search) == 0) {
        values$data <- get_initial(file)
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
        plugins = c("search", "wholerow", "checkbox", "dnd"),
        options = list(
          "themes" = list("dots" = FALSE, "icons" = FALSE),
          "check_callback" = TRUE, "scrollbar" = TRUE
        )
      )
    })
  }

  shinyApp(ui, server)
}
