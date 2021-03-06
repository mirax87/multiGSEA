#' Creates a "geneset smart" ComplexHeatmap::Heatmap
#'
#' Encapsulates many common "moves" you'll make when trying to make a heatmap,
#' especially if you are trying to show geneset activity across a panel of
#' samples.
#'
#' @section Renaming Heatmap Rows:
#' This function leverages [rename_rows()] so that you can better customize the
#' output of your heatmaps by tweaking its rownames.
#'
#' If you are plotting a **gene-level** heatmap (ie. `aggregate.by == "none"``)
#' and the `rownames()` are gene identifieres, but you want the rownames of the
#' heatmap to be gene symbols. You can perform this renaming using the
#' `rename.rows` parameter.
#'
#' * If `rename.rows` is `NULL`, then nothing is done.
#' * If `rename.rows` is a `string`, then we assume that `x` has an associated
#'   metadata `data.frame` over its rows and that `rename.rows` names one of
#'   its columns, ie. `DGEList$genes[[rename.rows]]` or
#'   `fData(ExpressionSet)[[rename.rows]]`. The values in that column will
#'   be swapped out for `x`'s rownames
#' * If `rename.rows` is a two-column data.frame, the first column is assumed
#'   to be `rownames(x)` and the second is what you want to rename it to.
#'
#' Maybe you are aggregating the expression scores into geneset scores, and
#' you don't want the rownames of the heatmap to be `collection;;name` (or just
#' `name` when `rm.collection.prefx = TRUE`), you can pass in a two column
#' `data.frame`, where the first column is `collection;name` and the second
#' is the name you want to rename that to. There is an example of this in
#' the "Examples" section here.
#'
#' @export
#' @importFrom circlize colorRamp2
#' @importFrom ComplexHeatmap Heatmap
#' @importFrom viridis viridis
#'
#' @param x the data matrix
#' @param gdb `GeneSetDb` object that holds the genesets to plot. Defaults to
#'   `NULL`, which will plot all rows in `x`.
#' @param col a colorRamp(2) function
#' @param aggregate.by the method used to generate single-sample geneset
#'   scores. Default is `none` which plots heatmap at the gene level
#' @param split introduce row-segmentation based on genesets or collections?
#'   Defaults is `TRUE` which will create split heatmaps based on
#'   collection if `aggregate.by != 'none'`, or based on gene sets
#'   if `aggregate.by == "none"`.
#' @param scores If `aggregate.by != "none"` you can pass in a precomupted
#'   [scoreSingleSamples()] result, otherwise one will be
#'   computed internally. Note that if this is a `data.frame` of
#'   pre-computed scores, the `gdb` is largely irrelevant (but still
#'   required).
#' @param rm.dups if `aggregate.by == 'none'`, do we remove genes that
#'   appear in more than one geneset? Defaults to `FALSE`
#' @param recenter do you want to mean center the rows of the heatmap matrix
#'   prior to calling [ComplexHeatmap::Heatmap()]?
#' @param rescale do you want to standardize the row variance to one on the
#'   values of the heatmap matrix prior to calling
#'   [ComplexHeatmap::Heatmap()]?
#' @param rename.rows defaults to `NULL`, which induces no action. Specifying
#'   a paramter here assumes you want to rename the rows of the heatmap.
#'   Please refer to the "Renaming Rows" section for details.
#' @param zlim A `length(zlim) == 2` numeric vector that defines the min and max
#'   values from `x` for the `colorRamp2` call. If the heatmap that is being
#'   drawn is "0-centered"-ish, then this defines the real values of the
#'   fenceposts. If not, then these define the quantiles to trim off the top
#'   or bottom.
#' @param transpose Flip display so that rows are columns. Default is `FALSE`.
#' @param ... parameters to send down to [scoreSingleSamples()] or
#'   [ComplexHeatmap::Heatmap()].
#' @return A `Heatmap` object.
#'
#' @examples
#' library(ComplexHeatmap)
#' vm <- exampleExpressionSet()
#' gdb <- exampleGeneSetDb()
#' col.anno <- ComplexHeatmap::HeatmapAnnotation(
#'   vm$targets[, c("Cancer_Status", "PAM50subtype")],
#'   col = list(
#'     Cancer_Status = c(normal = "grey", tumor = "red"),
#'     PAM50subtype = c(Basal = "purple", Her2 = "green", LumA = "orange")))
#' mgh <- mgheatmap(vm, gdb, aggregate.by='ewm', split=TRUE,
#'                  top_annotation = col.anno, show_column_names = FALSE,
#'                  column_title = "Gene Set Activity in BRCA subset")
#'
#' # Maybe you want the rownames of the matrix to use spaces instead of "_"
#' rr <- geneSets(gdb)[, "name", drop = FALSE]
#' rr$newname <- gsub("_", " ", rr$name)
#' mg2 <- mgheatmap(vm, gdb, aggregate.by='ewm', split=TRUE,
#'                  top_annotation = col.anno, show_column_names = FALSE,
#'                  column_title = "Gene Set Activity in BRCA subset",
#'                  rename.rows = rr)
mgheatmap <- function(x, gdb = NULL, col=NULL,
                      aggregate.by=c('none', 'ewm', 'zscore'),
                      split=TRUE, scores=NULL,
                      name=NULL, rm.collection.prefix=TRUE,
                      rm.dups=FALSE, recenter=TRUE, rescale=FALSE,
                      rename.rows = NULL, zlim = NULL, transpose = FALSE, ...) {
  X <- as_matrix(x)

  if (is.null(gdb)) {
    # make a one geneset GeneSetDb
    faux.gs <- list(allgenes = rownames(x))
    gdb <- GeneSetDb(faux.gs, collectionName = "faux")
  }
  stopifnot(is(gdb, "GeneSetDb"))

  # split.by <- match.arg(split.by)
  drop1.split <- missing(split)
  stopifnot(is.logical(split) && length(split) == 1L)
  if (!is.null(scores)) stopifnot(is.data.frame(scores))
  if (!missing(zlim) && !is.null(zlim)) {
    stopifnot(
      is.numeric(zlim),
      length(zlim) == 2L,
      zlim[1] < zlim[2])
  }

  stopifnot(
    ncol(X) > 1L,
    !any(is.na(X)))

  if (is.null(scores)) {
    aggregate.by <- match.arg(aggregate.by)
  } else {
    stopifnot(
      is.character(aggregate.by),
      length(aggregate.by) == 1L,
      aggregate.by %in% scores$method)
  }

  gdbc <- suppressWarnings(conform(gdb, X, ...))
  gdbc.df <- as.data.frame(gdbc) ## keep only genes that matched in gdb.df
  gdbc.df$key <- encode_gskey(gdbc.df)

  if (aggregate.by != 'none') {
    if (is.null(scores)) {
      X <- scoreSingleSamples(gdb, X, methods=aggregate.by, as.matrix=TRUE, ...)
    } else {
      xs <- scores[scores[['method']] == aggregate.by,,drop=FALSE]
      xs$key <- encode_gskey(xs)
      X <- acast(xs, key ~ sample, value.var="score")
    }
    ## If we want to split, it (only?) makes sense to split by collection
    split <- if (split) split_gskey(rownames(X))$collection else NULL
  }

  if (aggregate.by == 'none') {
    ridx <- if (rm.dups) unique(gdbc.df$featureId) else gdbc.df$featureId
    X <- X[ridx,,drop=FALSE]
    split <- if (split) gdbc.df$key else NULL
  }

  if (recenter || rescale) {
    X <- t(scale(t(X), center=recenter, scale=rescale))
    isna <- which(is.na(X), arr.ind = TRUE)
    if (nrow(isna) > 0L) {
      na.rows <- unique(isna[, "row"])
      if (length(na.rows) == nrow(X)) {
        stop("All rows removed after `scale`")
      }
      warning(length(na.rows), " features NA'd during `scale`, ",
              "these are removed", immediate. = TRUE)
      X <- X[-na.rows,,drop = FALSE]
      split <- split[-na.rows]
    }
  }

  # What kind of colorscale are we going to use?
  # If this is 0-centered ish, we use a red-white-blue scheme, otherwise
  # we use viridis.
  if (is.null(col)) {
    # Is 0 close to the center of the score distribution?
    mean.X <- mean(X)
    zero.center <- mean.X >= -0.2 && mean.X <= 0.2
    if (zero.center) {
      if (missing(zlim)) {
        fpost <- quantile(abs(X), 0.975)
        zlim <- c(-fpost, fpost)
      } else if (is.null(zlim)) {
        zlim <- c(min(X), max(X))
      } else {
        stopifnot(zlim[1L] < 0, zlim[2L] > 0)
      }
      col <- colorRamp2(
        c(zlim[1L], 0, zlim[2L]),
        c('#1F294E', 'white', '#6E0F11'))
    } else {
      if (missing(zlim)) {
        fpost <- quantile(X, c(0.025, 0.975))
      } else if (is.null(zlim)) {
        fpost <- c(min(X), max(X))
      } else {
        stopifnot(all(zlim >= 0), all(zlim <= 1))
        fpost <- quantile(X, zlim)
      }
      breaks <- quantile(X, seq(0, 1, by = 0.25))
      if (fpost[1L] > breaks[2L] || fpost[2L] < breaks[4L]) {
        stop("Illegal values for zlim")
      }
      breaks[1] <- fpost[1]
      breaks[5] <- fpost[2]
      col <- colorRamp2(breaks, viridis::viridis(5))
    }
  }
  stopifnot(is.function(col))

  if (drop1.split && !is.null(split) && length(unique(split)) == 1L) {
    split <- NULL
  }

  if (rm.collection.prefix) {
    if (aggregate.by != 'none') {
      rownames(X) <- split_gskey(rownames(X))$name
    } else {
      if (!is.null(split)) split <- split_gskey(split)$name
    }
  }

  ## Catch Heatmap arguments in `...` and build a list do do.call() them down
  ## into the function call.
  dot.args <- list(...)
  hm.args.default <- as.list(formals(Heatmap))

  if (is.null(name)) {
    name <- if (aggregate.by == 'none') 'value' else 'score'
  }
  hm.args <- dot.args[intersect(names(dot.args), names(hm.args.default))]
  hm.args[['matrix']] <- X
  hm.args[['col']] <- col
  hm.args[['split']] <- split
  hm.args[['name']] <- name

  H <- do.call(ComplexHeatmap::Heatmap, hm.args)

  if (!is.null(rename.rows)) {
    has.meta <- is(x, "DGEList") ||
      is(x, "EList") ||
      is(x, "SummarizedExperiment") ||
      is(x, "eSet")
    is.string <- is.character(rename.rows) && length(rename.rows) == 1L
    if (aggregate.by == "none") {
      if (has.meta && is.string) {
        metadf <- fdata(x, as.df = TRUE)
        metadf <- data.frame(rn = rownames(x), to = metadf[[rename.rows]],
                             stringsAsFactors = FALSE)
        if (!is.null(metadf$to)) {
          rr <- rename_rows(H@matrix, rename.rows, rowmeta.df = metadf)
        } else {
          warning("rename.rows column not found in metadata for x")
        }
      } else {
        rr <- rename_rows(H@matrix, rename.rows)
      }
      rownames(H@matrix) <- rownames(rr)
    } else {
      if (!(is.data.frame(rename.rows) && ncol(rename.rows) == 2)) {
        warning("rename.rows parameter must be a 2 column data.frame when ",
                "aggregate.by != 'none'", immediate. = TRUE)
      } else {
        if (rm.collection.prefix && any(grepl(";", rename.rows[[1]]))) {
          rr <- rename.rows
          rr[[1L]] <- sub("^.*;;?", "", rename.rows[[1L]])
          rename.rows <- rbind(rename.rows, rr)
        }
        H@matrix <- rename_rows(H@matrix, rename.rows)
      }
    }
  }
  H
}
