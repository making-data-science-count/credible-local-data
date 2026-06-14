test_that("ug/L converts to mg/L and merges with existing mg/l rows", {
  long <- make_long("Phosphorus", c(500, 0.5, 0.7), c("ug/l", "mg/l", "mg/L"))
  res <- standardize_wq_units(long)
  expect_identical(res$n_dropped, 0L)
  expect_equal(res$data$value, c(0.5, 0.5, 0.7))
  # case variants of mg/L count as one unit, so nothing is dropped
  expect_identical(nrow(res$data), 3L)
})

test_that("deg F converts to deg C", {
  long <- make_long("Temperature", c(212, 32, 20), c("deg F", "deg F", "deg C"))
  res <- standardize_wq_units(long)
  expect_identical(res$n_dropped, 0L)
  expect_equal(res$data$value, c(100, 0, 20))
  expect_identical(unique(res$data$unit), "deg C")
})

test_that("mS/cm scales to uS/cm and umho/cm is renamed without rescaling", {
  long <- make_long("Conductivity", c(0.5, 250, 300), c("mS/cm", "umho/cm", "uS/cm"))
  res <- standardize_wq_units(long)
  expect_identical(res$n_dropped, 0L)
  expect_equal(res$data$value, c(500, 250, 300))
  expect_identical(unique(res$data$unit), "uS/cm")
})

test_that("minority units that cannot be converted are dropped and counted", {
  long <- make_long("Temperature", c(20, 21, 22, 295), c("deg C", "deg C", "deg C", "K"))
  res <- standardize_wq_units(long)
  expect_identical(res$n_dropped, 1L)
  expect_identical(unique(res$data$unit), "deg C")
})

test_that("the modal unit is chosen per parameter independently", {
  long <- bind_rows(
    make_long("Temperature", c(20, 70), c("deg C", "K")),
    make_long("pH", c(7, 8, 9), c(NA, NA, "std units"))
  )
  res <- standardize_wq_units(long)
  # Temperature: tie between deg C and K resolves deterministically (first
  # key alphabetically from table()); pH: NA majority keeps the NA rows
  ph_rows <- res$data[res$data$parameter == "pH", ]
  expect_identical(nrow(ph_rows), 2L)
  expect_true(all(is.na(ph_rows$unit)))
})

test_that("uniform units pass through untouched", {
  long <- make_long("Chloride", c(10, 20), c("mg/l", "mg/l"))
  res <- standardize_wq_units(long)
  expect_identical(res$n_dropped, 0L)
  expect_equal(res$data$value, c(10, 20))
})
