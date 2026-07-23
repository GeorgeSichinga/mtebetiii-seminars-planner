from django.core.management.base import BaseCommand
from core.models import Topic

TOPICS = [
    ("capstone", 1, "Research Question & Data Strategy",
     "Defining empirical strategies and data collection methodology."),
    ("capstone", 2, "Final Applied Mini-Project",
     "Executing an end-to-end data analysis workflow in chosen tool."),

    ("python", 1, "Python for Data Analysis (Pandas/NumPy)",
     "Series, DataFrames, indexing, and array computations."),
    ("python", 2, "Data Cleaning & Exploratory Analysis",
     "Handling missing data, grouping, aggregations, and transforming columns."),
    ("python", 3, "Visualization (Matplotlib/Seaborn)",
     "Designing informative charts and spatial/trend visualizations."),
    ("python", 4, "Intro to Scikit-Learn",
     "Supervised learning pipelines for regression and classification."),
    ("python", 5, "Geospatial & Remote Sensing Workflows",
     "Working with spatial data vectors and environmental datasets."),

    ("r", 1, "R & Tidyverse Foundations",
     "RStudio orientation, vectors, data frames, and dplyr wrangling."),
    ("r", 2, "Data Visualization with ggplot2",
     "Building layered publication-quality charts and economic plots."),
    ("r", 3, "Linear Regression & Model Diagnostics",
     "Fitting lm() models, diagnostic plots, and heteroskedasticity corrections."),
    ("r", 4, "Reproducible Research with R Markdown",
     "Dynamic document generation combining code, outputs, and text."),
    ("r", 5, "Intro to Machine Learning in R",
     "Basic decision trees and classification models."),

    ("stata", 1, "Data Management Basics",
     "Importing, cleaning, merging, reshaping, and labeling variables."),
    ("stata", 2, "Descriptive Statistics & Tabulation",
     "Summary tables, cross-tabulations, and data exploration."),
    ("stata", 3, "OLS Regression Fundamentals",
     "Running linear regressions, interpreting coefficients, and robust standard errors."),
    ("stata", 4, "Panel Data Setup & Pooled OLS",
     "Structuring panel data using xtset and baseline panel models."),
    ("stata", 5, "Fixed Effects vs. Random Effects",
     "Implementing xtreg, FE vs RE specification, and Hausman testing."),
    ("stata", 6, "Instrumental Variables (2SLS)",
     "Addressing endogeneity with ivregress and diagnostic tests."),
    ("stata", 7, "Publication-Ready Tables",
     "Exporting formatted regression and summary tables using esttab/outreg2."),
]


class Command(BaseCommand):
    help = "Seeds the default topic catalogue (Stata, R, Python, Capstone tracks)."

    def handle(self, *args, **options):
        created_count = 0
        for track, order, title, description in TOPICS:
            _, created = Topic.objects.get_or_create(
                track=track,
                order=order,
                title=title,
                defaults={"description": description},
            )
            if created:
                created_count += 1
        self.stdout.write(self.style.SUCCESS(
            f"Seeded topics. {created_count} new topic(s) created, "
            f"{len(TOPICS) - created_count} already existed."
        ))
