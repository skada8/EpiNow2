#' Updates Forecast Horizon Based on Input Data and Target
#'
#' @description `r lifecycle::badge("stable")`
#' Makes sure that a forecast is returned for the user specified
#' time period beyond the target date.
#' @inheritParams setup_target_folder
#' @inheritParams estimate_infections
#' @return Numeric forecast horizon adjusted for the users intention
#' @export
update_horizon <- function(horizon, target_date, reported_cases) {
  if (horizon != 0) {
    horizon <- horizon + as.numeric(as.Date(target_date) - max(reported_cases$date))
  }
  return(horizon)
}

#' Save Observed Data
#'
#' @description `r lifecycle::badge("stable")`
#' Saves observed data to a target location if given.
#' @inheritParams setup_target_folder
#' @inheritParams epinow
#' @return NULL
#' @export
save_input <- function(reported_cases, target_folder) {
  if (!is.null(target_folder)) {
    latest_date <- reported_cases[confirm > 0][date == max(date)]$date

    saveRDS(latest_date, paste0(target_folder, "/latest_date.rds"))
    saveRDS(reported_cases, paste0(target_folder, "/reported_cases.rds"))
  }
  return(invisible(NULL))
}



#' Save Estimated Infections
#'
#' @description `r lifecycle::badge("stable")`
#' Saves output from `estimate_infections` to a target directory.
#' @param estimates List of data frames as output by `estimate_infections`
#' @param samples Logical, defaults to TRUE. Should samples be saved
#' @param return_fit Logical, defaults to TRUE. Should the fit stan object
#' be returned.
#' @seealso estimate_infections
#' @inheritParams setup_target_folder
#' @inheritParams  estimate_infections
#' @return NULL
#' @export
save_estimate_infections <- function(estimates, target_folder = NULL,
                                     samples = TRUE, return_fit = TRUE) {
  if (!is.null(target_folder)) {
    if (samples) {
      saveRDS(estimates$samples, paste0(target_folder, "/estimate_samples.rds"))
    }
    saveRDS(estimates$summarised, paste0(target_folder, "/summarised_estimates.rds"))
    if (return_fit) {
      saveRDS(estimates$fit, paste0(target_folder, "/model_fit.rds"))
      saveRDS(estimates$args, paste0(target_folder, "/model_args.rds"))
    }
  }
  return(invisible(NULL))
}


#' Save Forecast Infections
#'
#' @description `r lifecycle::badge("experimental")`
#' Saves the output from `forecast_infections` to a target directory.
#' @param forecast A list of data frames as output by `forecast_infections`
#' @inheritParams save_estimate_infections
#' @seealso forecast_infections
#' @return NULL
#' @export
save_forecast_infections <- function(forecast, target_folder = NULL, samples = TRUE) {
  if (!is.null(target_folder)) {
    if (samples) {
      saveRDS(forecast$samples, paste0(target_folder, "/forecast_samples.rds"))
    }
    saveRDS(forecast$summarised, paste0(target_folder, "/summarised_forecast.rds"))
  }
  return(invisible(NULL))
}


#' Estimate Cases by Report Date
#'
#' @description `r lifecycle::badge("questioning")`
#' Either extracts or converts reported cases from an input data table. For output from
#' `estimate_infections` this is a simple filtering step but for output from `forecast_infection`
#' this is currently an approximate convolution. This step is likely to be updated/deprecated
#' in new releases as `forecast_infections` evolves to be based on `stan` functionality.
#' @inheritParams setup_target_folder
#' @inheritParams save_estimate_infections
#' @inheritParams save_forecast_infections
#' @inheritParams estimate_infections
#' @return A list of samples and summarised estimates of estimated cases by date of report
#' @export
#' @importFrom data.table := rbindlist
estimates_by_report_date <- function(estimates, forecast, delays, CrIs = c(0.2, 0.5, 0.9),
                                     target_folder = NULL, samples = TRUE) {
  if (is.null(forecast)) {
    estimated_reported_cases <- list()
    if (samples) {
      estimated_reported_cases$samples <- estimates$samples[variable == "reported_cases"][
        ,
        .(date, sample, cases = value, type = "gp_rt")
      ]
    }
    estimated_reported_cases$summarised <- estimates$summarised[variable == "reported_cases"][
      ,
      type := "gp_rt"
    ][, variable := NULL][, strat := NULL]
  } else {
    report_cases_with_forecast <- function(model) {
      reported_cases <- report_cases(
        case_estimates = estimates$samples[variable == "infections"][type != "forecast"][
          ,
          .(date, sample, cases = as.integer(value))
        ],
        case_forecast = forecast$samples[type == "case" &
          forecast_type == model][
          ,
          .(date, sample, cases = as.integer(value))
        ],
        delays = delays,
        CrIs = CrIs,
        type = "sample"
      )
      return(reported_cases)
    }

    estimated_reported_cases <- list()
    if (samples) {
      reported_cases_rt <- report_cases_with_forecast(model = "rt")
      reported_cases_cases <- report_cases_with_forecast(model = "case")
      reported_cases_ensemble <- report_cases_with_forecast(model = "ensemble")

      estimated_reported_cases$samples <- data.table::rbindlist(list(
        reported_cases_rt$samples[, type := "rt"],
        reported_cases_cases$samples[, type := "case"],
        reported_cases_ensemble$samples[, type := "ensemble"],
        estimates$samples[variable == "reported_cases"][
          ,
          .(date, sample, cases = value, type = "gp_rt")
        ]
      ), use.names = TRUE)
    }

    estimated_reported_cases$summarised <- data.table::rbindlist(list(
      reported_cases_rt$summarised[, type := "rt"],
      reported_cases_cases$summarised[, type := "case"],
      reported_cases_ensemble$summarised[, type := "ensemble"],
      estimates$summarised[variable == "reported_cases"][, type := "gp_rt"][
        ,
        variable := NULL
      ][, strat := NULL]
    ), use.names = TRUE)
  }

  if (!is.null(target_folder)) {
    if (samples) {
      saveRDS(estimated_reported_cases$samples, paste0(target_folder, "/estimated_reported_cases_samples.rds"))
    }
    saveRDS(estimated_reported_cases$summarised, paste0(target_folder, "/summarised_estimated_reported_cases.rds"))
  }
  return(estimated_reported_cases)
}



#' Copy Results From Dated Folder to Latest
#'
#' @description `r lifecycle::badge("questioning")`
#' Copies output from the dated folder to a latest folder. May be undergo changes in later releases.
#' @param latest_folder Character string containing the path to the latest target folder.
#' As produced by `setup_target_folder`.
#' @inheritParams setup_target_folder
#' @return NULL
#' @export
copy_results_to_latest <- function(target_folder = NULL, latest_folder = NULL) {
  if (!is.null(target_folder)) {
    ## Save all results to a latest folder as well
    suppressWarnings(
      if (dir.exists(latest_folder)) {
        unlink(latest_folder)
      }
    )

    suppressWarnings(
      dir.create(latest_folder)
    )

    suppressWarnings(
      file.copy(file.path(target_folder, "."),
        latest_folder,
        recursive = TRUE
      )
    )
  }
  return(invisible(NULL))
}


#' Construct Output
#'
#' @description `r lifecycle::badge("stable")`
#' Combines the output produced internally by `epinow` into a single list.
#' @param estimated_reported_cases A list of dataframes as produced by
#' `estimates_by_report_date`.
#' @param plots A list of plots as produced by `report_plots`
#' @param summary A list of summary output as produced by `report_summary`
#' @inheritParams save_estimate_infections
#' @inheritParams save_forecast_infections
#'
#' @return A list of output as returned by `epinow`
#' @export
construct_output <- function(estimates, forecast = NULL,
                             estimated_reported_cases,
                             plots = NULL,
                             summary = NULL,
                             samples = TRUE) {
  out <- list()
  out$estimates <- estimates
  if (!samples) {
    out$estimates$samples <- NULL
  }
  if (!is.null(forecast)) {
    out$forecast <- forecast
    if (!samples) {
      out$forecast$samples <- NULL
    }
  }
  out$estimated_reported_cases <- estimated_reported_cases
  out$summary <- summary

  if (!is.null(plots)) {
    out$plots <- plots
  }
  return(out)
}
