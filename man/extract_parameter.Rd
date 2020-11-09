% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extract.R
\name{extract_parameter}
\alias{extract_parameter}
\title{Extract Samples for a Parameter from a Stan model}
\usage{
extract_parameter(param, samples, dates)
}
\arguments{
\item{param}{Character string indicating the parameter to extract}

\item{samples}{Extracted stan model (using \code{rstan::extract})}

\item{dates}{A vector identifying the dimensionality of the parameter to extract. Generally this will be
a date}
}
\value{
A data frame containing the parameter name, date, sample id and sample value
}
\description{
Extract Samples for a Parameter from a Stan model
}