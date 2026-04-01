## Contributing to CREDIBLE Local Data

### What You Need

- **GitHub Desktop** installed (download at https://desktop.github.com/)
- **RStudio** or **Positron** (either works)
- **R packages** installed: `shiny`, `shinydashboard`, `DT`, `tidyverse`, `dataRetrieval`, `janitor`, `lubridate`
- A **GitHub account** with access to the repo

### 1. Clone or Pull the Latest Code

If you haven't cloned the repo yet:

1. Open **GitHub Desktop**
2. Click **File → Clone Repository**
3. Search for or paste `making-data-science-count/credible-local-data`
4. Choose where to save it on your computer and click **Clone**

If you already have it cloned, open the repo in GitHub Desktop and click **Fetch origin**, then **Pull origin** if there are new changes.

### 2. Open the Project

Open `credible-local-data.Rproj` in RStudio or open the folder in Positron. This sets your working directory correctly.

### 3. Run the App Locally

Click **Run App** in RStudio, or run in the console:

```r
shiny::runApp("app.R")
```

Make sure everything works before you start editing.

### 4. Make Your Changes

The main file is **`app.R`** — almost everything lives there. Edit, save, and re-run the app to check your work.

### 5. Stage, Commit, and Push

Back in **GitHub Desktop**, you'll see your changed files listed on the left.

1. Check the boxes next to the files you want to include
2. Write a short summary of your changes in the **Summary** field at the bottom left
3. Click **Commit to main**
4. Click **Push origin** at the top to send your changes to GitHub

### 6. Deploy

The app is deployed at **https://ed-analytics.shinyapps.io/credible-local-data/**. To deploy your changes:

1. In RStudio, open `app.R`
2. Click the **Publish** button (blue icon near Run App)
3. Select the **ed-analytics** account and confirm

You'll need to be authorized on the `ed-analytics` shinyapps.io account to deploy.
