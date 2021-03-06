% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AllGenerics.R, R/GeneSetDb-methods.R
\name{collectionMetadata}
\alias{collectionMetadata}
\alias{geneSetURL}
\alias{geneSetCollectionURLfunction}
\alias{geneSetCollectionURLfunction<-}
\alias{featureIdType}
\alias{featureIdType<-}
\alias{org}
\alias{org<-}
\alias{addCollectionMetadata}
\title{Gene Set Collection Metadata}
\usage{
collectionMetadata(x, collection, name, ...)

geneSetURL(x, i, j, ...)

geneSetCollectionURLfunction(x, i, ...)

geneSetCollectionURLfunction(x, i) <- value

featureIdType(x, i, ...)

featureIdType(x, i) <- value

org(x, i, ...)

org(x, i) <- value

addCollectionMetadata(x, xcoll, xname, value, validate.value.fn = NULL,
  allow.add = TRUE)
}
\arguments{
\item{x}{Object to extract the collectionMetadata from}

\item{collection}{The geneset collection to to query}

\item{name}{The name of the metadata variable to get the value for}

\item{i}{The collection,name compound key identifier of the gene set}

\item{j}{The collection,name compound key identifier of the gene set}

\item{value}{The value of the metadata variable}

\item{xcoll}{The collection name}

\item{xname}{The name of the metadata variable}

\item{validate.value.fn}{If a function is provided, it is run on
\code{value} and msut return \code{TRUE} for addition to be made}

\item{allow.add}{If \code{FALSE}, this xcoll,xname should be in the
\code{GeneSetDb} already, and this will fail because something is
deeply wrong with the world}

\item{x}{\code{\link[=GeneSetDb]{GeneSetDb()}}}
}
\value{
A character vector of URLs for each of the genesets identified by
\code{i, j}. \code{NA} is returned for genesets \code{i,j} that are not found in \code{x}.

The updated \code{GeneSetDb}.
}
\description{
The design of the GeneSetDb is such that we assume that groups of gene sets
are usually defined together and will therefore share similar metadata.
These groups of gene sets will fall into the same "collection", and,
therefore, metadata for particular gene sets are tracked at the collection
level.

Types of metadata being referred to could be things like the organism
that a batch of gene sets were defined in, the type of feature identifiers
that a collection of gene sets are using (ie. \code{\link[GSEABase:EntrezIdentifier]{GSEABase::EntrezIdentifier()}})
or a URL pattern that combines the collection,name compound key that one
can browse to in order to find out more information about the gene set.

There are explicit helper functions that set and get these aforementioned
metadata, namely \code{\link[=org]{org()}}, \code{\link[=featureIdType]{featureIdType()}},
\code{\link[=geneSetCollectionURLfunction]{geneSetCollectionURLfunction()}}, and \code{\link[=geneSetURL]{geneSetURL()}}. Aribtrary
metadata can be stored at the collection level using the
\code{\link[=addCollectionMetadata]{addCollectionMetadata()}} function. More details are provided below.
}
\section{Gene Set URLs}{


A URL function can be defined per collection that takes the collection,name
compound key and generates a URL for the gene set that the user can browse
to for futher information. For instance, the
\code{\link[=geneSetCollectionURLfunction]{geneSetCollectionURLfunction()}} for the MSigDB collections are defined
like so:\preformatted{url.fn <- function(collection, name) {
  url <- 'http://www.broadinstitute.org/gsea/msigdb/cards/\%s.html'
  sprintf(url, name)
}
gdb <- getMSigGeneSetDb('h')
geneSetCollectionURLfunction(gdb, 'h') <- url.fn
}

In this way, a call to \code{geneSetURL(gdb, 'h', 'HALLMARK_ANGIOGENESIS')}
will return
http://www.broadinstitute.org/gsea/msigdb/cards/HALLMARK_ANGIOGENESIS.html.

This function is vectorized over \code{i} and \code{j}
}

\section{Feature ID Types}{


When defining a set of gene sets in a collection, the identifiers used must
be of the same type. Most often you'll probably be working with Entrez
identifiers, simply because that's what most of the annotations work with.

As such, you'd define that your collection uses geneset identifiers like
so:\preformatted{gdb <- getMSigGeneSetDb('h')
featureIdType(gdb, 'h') <- EntrezIdentifier()
## or, equivalently (but you don't want to use this)
gdb <- addCollectionMetadata(gdb, 'h', 'id_type', EntrezIdentifier())
}
}

\section{Organism}{


You're going to want to keep track of the organism the experiments were run
in that were used to define this collection of gene sets.\preformatted{gdb <- getMSigGeneSetDb('h')
org(gdb, 'h') <- 'Homo_sapiens'
}
}

\section{Adding arbitrary collectionMetadata}{


Adds arbitrary metadata to a gene set collection of a GeneSetDb

Note that this is not a replacement method! You must catch the returned
object to keep the one with the updated \code{collectionMetadata}. Although this
function is exported, I imagine this being used mostly through predefined
replace methods that use this as a utility function, such as the replacement
methods for \code{\link[=org]{org()}}, and \code{\link[=featureIdType]{featureIdType()}}.\preformatted{gdb <- getMSigGeneSetDb('h')
gdb <- addCollectionMetadata(gdb, 'h', 'foo', 'bar')
}
}

\examples{
gdb <- getMSigGeneSetDb('h')

## Gene Set URLs
geneSetURL(gdb, 'h', 'HALLMARK_ADIPOGENESIS')
geneSetURL(gdb, c('h', 'h'),
           c('HALLMARK_ADIPOGENESIS', 'HALLMARK_ANGIOGENESIS'))

## FeatureId TYpe
featureIdType(gdb, 'h')

## Organism
org(gdb, 'h')

## Arbitrary metadata
gdb <- addCollectionMetadata(gdb, 'h', 'foo', 'bar')
cmh <- collectionMetadata(gdb, 'h') ## print this to see
}
