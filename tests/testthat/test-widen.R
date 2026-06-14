test_that("same-day replicates are averaged into atomic numeric columns", {
  long <- bind_rows(
    make_long("pH", 7, NA_character_),
    make_long("pH", 8, NA_character_),
    make_long("Temperature", 20, "deg C")
  )
  wide <- widen_wq_data(long, "Tennessee")
  expect_identical(nrow(wide), 1L)
  expect_equal(wide$pH, 7.5)
  expect_equal(wide$Temperature, 20)
  expect_false(any(vapply(wide, is.list, logical(1))))
})

test_that("wide data leads with the id columns in display order", {
  wide <- widen_wq_data(make_long("pH", 7, NA_character_), "Tennessee")
  expect_identical(names(wide)[1:7],
                   c("state", "county", "site_id", "site_name", "lat", "lon", "date"))
  expect_identical(wide$state, "Tennessee")
})

test_that("sites and dates stay distinct rows", {
  long <- bind_rows(
    make_long("pH", 7, NA_character_, site_id = "S1"),
    make_long("pH", 8, NA_character_, site_id = "S2", site_name = "Second Creek"),
    make_long("pH", 9, NA_character_, site_id = "S1", date = as.Date("2024-07-01"))
  )
  wide <- widen_wq_data(long, "Tennessee")
  expect_identical(nrow(wide), 3L)
})

test_that("top sites are ranked by measurement count with labels", {
  long <- bind_rows(
    make_long("pH", c(7, 7.1, 7.2), NA_character_, site_id = "S1"),
    make_long("pH", 8, NA_character_, site_id = "S2", site_name = "Second Creek")
  )
  sites <- summarize_wq_sites(long)
  expect_identical(sites$site_id, c("S1", "S2"))
  expect_identical(sites$n_measurements, c(3L, 1L))
  expect_identical(sites$display_label[1], "First Creek (3 measurements)")
})

test_that("summarize_wq_sites caps at n_top", {
  long <- bind_rows(lapply(1:8, function(i) {
    make_long("pH", 7, NA_character_, site_id = paste0("S", i))
  }))
  expect_identical(nrow(summarize_wq_sites(long)), 5L)
  expect_identical(nrow(summarize_wq_sites(long, n_top = 2)), 2L)
})
