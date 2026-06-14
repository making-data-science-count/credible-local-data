# Mapping between the student-facing parameter labels (the checkbox values
# in the UI) and the WQP characteristic names the data is actually recorded
# under.
#
# Why this exists: WQP characteristic names are exact-match. Most monitoring
# data is recorded under e.g. "Temperature, water" and "Dissolved oxygen
# (DO)", so querying plain "Temperature" or "Dissolved oxygen" silently
# returns nothing — and querying a name that is not in the WQX domain list
# at all (the old "Total nitrogen") fails the whole request with HTTP 400.
# Every name below was verified against
# https://www.waterqualitydata.us/Codes/characteristicname (June 2026).
#
# Only synonyms that measure the same quantity on the same basis are
# grouped; variants on a different reporting basis (e.g. "Nitrate as N" vs
# "Nitrate" as NO3) are intentionally NOT merged, because their values are
# not comparable.

wq_characteristic_map <- list(
  "pH"                     = "pH",
  "Turbidity"              = "Turbidity",
  "Temperature"            = c("Temperature, water", "Temperature"),
  "Dissolved oxygen"       = c("Dissolved oxygen (DO)", "Dissolved oxygen"),
  "Escherichia coli"       = "Escherichia coli",
  "Phosphorus"             = "Phosphorus",
  "Nitrate"                = "Nitrate",
  "Nitrite"                = "Nitrite",
  "Conductivity"           = c("Conductivity", "Specific conductance"),
  "Total dissolved solids" = "Total dissolved solids",
  "Alkalinity"             = c("Alkalinity", "Alkalinity, total"),
  "Hardness"               = c("Hardness", "Hardness, Ca, Mg", "Total hardness"),
  "Chloride"               = "Chloride",
  "Sulfate"                = "Sulfate",
  "Ammonia"                = "Ammonia",
  "Total nitrogen"         = "Total Nitrogen, mixed forms"
)

# Reverse lookup: characteristic name -> student-facing label.
.wq_label_lookup <- local({
  labels <- rep(names(wq_characteristic_map),
                lengths(wq_characteristic_map))
  stats::setNames(labels, unlist(wq_characteristic_map, use.names = FALSE))
})

# Expand selected labels into the full set of characteristic names to query.
# Unknown labels pass through unchanged (defensive; should not happen).
expand_wq_characteristics <- function(labels) {
  expanded <- lapply(labels, function(l) {
    if (l %in% names(wq_characteristic_map)) wq_characteristic_map[[l]] else l
  })
  unique(unlist(expanded, use.names = FALSE))
}

# Collapse characteristic names in fetched data back to the student-facing
# label, so synonymous characteristics land in one column after pivoting.
# Unknown characteristics pass through unchanged.
normalize_wq_parameter <- function(characteristic) {
  label <- unname(.wq_label_lookup[characteristic])
  label[is.na(label)] <- characteristic[is.na(label)]
  label
}
