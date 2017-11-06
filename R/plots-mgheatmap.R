##' Create a "geneset smart" heatmap.
##'
##' @export
##' @importFrom circlize colorRamp2
##' @importFrom ComplexHeatmap Heatmap
##'
##' @param the \code{GeneSetDb} object that holds the genesets to plot
##' @param x the data matrix
##' @param col a colorRamp(2) funciton
##' @param aggregate.by the method used to generate single-sample geneset
##'   scores. Default is \code{none} which plots heatmap at the gene level
##' @param split introduce row-segmentation based on genesets or collections?
##'   Defaults is \code{TRUE} which will create split heatmaps based on
##'   collection if \code{aggregate.by= != 'none'}, or based on gene sets
##'   if \code{aggregate.by == "none"}.
##' @param scores If \code{aggregate.by != "none"} you can pass in a precomupted
##'   \code{\link{singleSampleGeneSet}} result, otherwise one will be
##'   computed internally. Note that if this is a \code{data.frame} of
##'   pre-computed scores, the \code{gdb} is largely irrelevant (but still
##'   required).
##' @param rm.dups if \code{aggregate.by == 'none'}, do we remove genes that
##'   appear in more than one geneset? Defaults to \code{FALSE}
##' @param recenter do you want to mean center the rows of the heatmap matrix
##'   prior to calling \code{\link[ComplexHeatmap]{Heatmap}}?
##' @param rescale do you want to standardize the row variance to one on the
##'   values of the heatmap matrix prior to calling
##'   \code{\link[ComplexHeatmap]{Heatmap}}?
##' @param ... parameters to send down to \code{\link{scoreSingleSample}} or
##'   \code{\link[ComplexHeatmap]{Heatmap}}.
##' @return list(heatmap=ComplexHeatmap, matrix=X)
##'
##' @examples
##'
##' vm <- exampleExpressionSet()
##' gdb <- exampleGeneSetDb()
##' mgh <- mgheatmap(gdb, vm, aggregate.by='ewm', split=TRUE)
mgheatmap <- function(gdb, x, col=NULL,
                      aggregate.by=c('none', 'ewm', 'zscore'),
                      # split.by=c('none', 'geneset', 'collection'),
                      split=TRUE, scores=NULL,
                      name=NULL, rm.collection.prefix=TRUE,
                      rm.dups=FALSE, recenter=TRUE, rescale=TRUE,
                      ...) {
  stopifnot(is(gdb, "GeneSetDb"))
  # split.by <- match.arg(split.by)
  drop1.split <- missing(split)
  stopifnot(is.logical(split) && length(split) == 1L)
  if (!is.null(scores)) stopifnot(is.data.frame(scores))

  X <- as_matrix(x)
  stopifnot(ncol(X) > 1)
  if (is.null(col)) {
    col <- colorRamp2(c(-2, 0, 2), c('#1F294E', 'white', '#6E0F11'))
  }
  stopifnot(is.function(col))

  if (is.null(scores)) {
    aggregate.by <- match.arg(aggregate.by)
  } else {
    stopifnot(
      is.character(aggregate.by),
      length(aggregate.by) == 1L,
      aggregate.by %in% scores$method)
  }


  gdbc <- suppressWarnings(conform(gdb, X, min.gs.size=2L))
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

  if (recenter || rescale) {
    X <- t(scale(t(X), center=recenter, scale=rescale))
  }

  if (aggregate.by == 'none') {
    ridx <- if (rm.dups) unique(gdbc.df$featureId) else gdbc.df$featureId
    X <- X[ridx,,drop=FALSE]
    split <- if (split) gdbc.df$key else NULL
  }

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
  H
}

# mgheatmap <- function(x, ...) {
#   ## I'm not a bad person, I just want to keep this S3 so end users can
#   ## use the data.frame results in dplyr chains.
#   UseMethod("mgheatmap")
# }
#
# mgheatmap.sss_frame <- function(x, col=NULL, aggregate.by=x$method[1L],
#                                 split=TRUE, name=NULL,
#                                 rm.collection.prefix=TRUE, recenter=TRUE,
#                                 rescale=TRUE, ...) {
#   stopifnot(
#     is.character(aggregate.by),
#     length(aggregate.by) == 1L,
#     aggregate.by %in% x$method)
#
#   x$key <- encode_gskey(x)
#   xs <- subset(x, method == aggregate.by)
#   X <- acast(xs, key ~ sample, value.var="score")
#   mgheatmap(X, )
# }
#
# mgheatmap.default <- function()