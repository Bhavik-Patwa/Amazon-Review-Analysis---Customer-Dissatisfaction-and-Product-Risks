# Looker Studio Dashboard

This folder contains the final Looker Studio reporting layer for the project.

[View the public dashboard](https://datastudio.google.com/reporting/3e156bff-b40c-420b-9b41-3ad89940716f)

## What this dashboard shows

The dashboard translates the project’s SQL, Python and NLP pipeline into a business-facing reporting layer across two levels :

- **Cross-category risk reporting** for dissatisfaction, product prioritization, price behavior, review trust and metadata readiness
- **Electronics-specific issue analysis** for validated dissatisfaction themes, premium/priority exposure and issue co-occurrence patterns

## Dashboard pages

- **Executive Risk & Customer Experience Overview**  
  High-level view of category dissatisfaction, product risk concentration and overall operational pressure.

- **Category Dissatisfaction & Risk Signals**  
  Compares dissatisfaction, rating polarization and average rating across the selected Amazon categories.

- **Price Band & Review Trust Analysis**  
  Examines how dissatisfaction varies across price tiers and how verified vs non-verified reviews differ in quality and helpfulness behavior.

- **Content & Metadata Readiness**  
  Shows which categories are reliable enough for pricing, NLP and content-driven interpretation.

- **Product Risk Prioritization**  
  Surfaces products that warrant intervention based on dissatisfaction rate, review volume and evidence strength.

- **Electronics Customer Dissatisfaction Themes**  
  Highlights the issue themes most strongly associated with dissatisfied Electronics reviews.

- **Electronics Risk by Price & Priority**  
  Shows which Electronics issues become more severe in premium and priority-product segments.

- **Electronics Dissatisfaction Pattern Relationships**  
  Maps issue co-occurrence and multi-issue patterns to reveal broader customer experience risks.


This dashboard is backed by :
- BigQuery reporting tables built from the project SQL pipeline
- category and product risk scoring logic from the behavioral analysis layer
- a validated Electronics NLP framework based on rule-based issue buckets
- explicit evidence, coverage and interpretation-strength fields carried into reporting

It is the final reporting surface for the project’s end-to-end analytical workflow.