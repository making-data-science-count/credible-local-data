# How long a search will probably take, for the estimate shown under the
# county picker while the student is still choosing.
#
# Counties are the only choice with a real, predictable cost, so the number
# belongs at the moment that choice is being made rather than as a surprise
# afterwards.

# Above this many counties the estimate turns into a warning. Soft: nothing
# is blocked, because a teacher comparing eight counties is a legitimate
# lesson, and the app should not decide it isn't.
wq_county_soft_cap <- 5

# Fitted to the measured medians in tests/benchmark-results.csv. 4.7s per
# county plus 1.2s per extra year reproduces every point we have:
#   1 county  / 1yr -> 4.7  (measured 4.6)
#   3 counties/ 1yr -> 14.1 (measured 14.1)
#   1 county  / 5yr -> 9.5  (measured 9.5)
# Parameter count is deliberately not a term: 5 -> 16 parameters moved the
# median by half a second.
#
# This is a typical time, not a promise. A cache hit is far faster and a WQP
# stall is far slower, which is why the loading card stages its copy by
# elapsed time instead of counting down to this number.
wq_time_estimate <- function(n_counties, n_years) {
  4.7 * n_counties + 1.2 * (n_years - 1)
}

# Deliberately vague at the top end: past ~a minute the spread between a
# clean run and a stalled one is wider than the estimate itself, so a
# precise-sounding "97 seconds" would be false precision.
format_estimate <- function(secs) {
  if (secs < 20) {
    paste0("about ", round(secs), " seconds")
  } else if (secs < 60) {
    paste0("about ", round(secs / 10) * 10, " seconds")
  } else if (secs < 90) {
    "about a minute"
  } else {
    paste0("about ", round(secs / 60), " minutes")
  }
}

# The year slider gives c(start, end); treat anything else as a single year
# so the estimate never errors while inputs are still initializing.
selected_year_span <- function(years) {
  if (is.null(years) || length(years) != 2) 1L else as.integer(years[2] - years[1] + 1L)
}
