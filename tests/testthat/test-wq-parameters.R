test_that("every characteristic maps to exactly one label", {
  chars <- unlist(wq_characteristic_map, use.names = FALSE)
  expect_identical(anyDuplicated(chars), 0L)
})

test_that("expansion includes the names data is actually recorded under", {
  expect_in(c("Temperature, water", "Temperature"),
            expand_wq_characteristics("Temperature"))
  expect_in("Dissolved oxygen (DO)", expand_wq_characteristics("Dissolved oxygen"))
  expect_in("Specific conductance", expand_wq_characteristics("Conductivity"))
})

test_that("the invalid 'Total nitrogen' name is never sent to the API", {
  expanded <- expand_wq_characteristics("Total nitrogen")
  expect_false("Total nitrogen" %in% expanded)
  expect_in("Total Nitrogen, mixed forms", expanded)
})

test_that("expansion deduplicates and passes unknown labels through", {
  expect_identical(expand_wq_characteristics(c("pH", "pH")), "pH")
  expect_identical(expand_wq_characteristics("Mystery"), "Mystery")
})

test_that("normalization collapses synonyms to their label", {
  expect_identical(
    normalize_wq_parameter(c("Temperature, water", "Specific conductance", "pH")),
    c("Temperature", "Conductivity", "pH")
  )
})

test_that("normalization passes unknown characteristics through", {
  expect_identical(normalize_wq_parameter("Zinc"), "Zinc")
})

test_that("every mapped characteristic normalizes back to its own label", {
  for (lbl in names(wq_characteristic_map)) {
    expect_true(all(normalize_wq_parameter(wq_characteristic_map[[lbl]]) == lbl),
                info = lbl)
  }
})
