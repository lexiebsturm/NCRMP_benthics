% Generated by roxygen2: do not edit by hand
% Please edit documentation in
%   R/NCRMP_DRM_calculate_disease_prevalence_colonies.R
\name{NCRMP_DRM_calculate_disease_prevalence_colonies}
\alias{NCRMP_DRM_calculate_disease_prevalence_colonies}
\title{Calculate disease prevalence & bleaching prevalence at the species/site, site, strata and domain levels}
\usage{
NCRMP_DRM_calculate_disease_prevalence_colonies(
  project,
  region,
  species_filter = "NULL"
)
}
\arguments{
\item{project}{A string indicating the project, NCRMP, MIR, or NCRMP and DRM combined ("NCRMP_DRM").}

\item{region}{A string indicating the region. Options are: "SEFCRI", "FLK", "Tortugas", "STX", "STTSTJ", "PRICO", and "GOM".}

\item{species_filter}{An optional concatenated string indicating whether to filter to a subset of species}
}
\value{
A list of dataframes including 1) bleaching and disease prevalence by species
and site, 2) bleaching and disease prevalence by site, 3) disease prevalence by
strata, 4) bleaching prevalence by strata, and 5) regional estimates for disease
and bleaching prevalence.
}
\description{
Calculates disease and bleaching prevalence for each species at each site,
at each site across all species, at each strata across all species, and
regional estimates for each year of a given region.
NCRMP utilizes a stratified random sampling design.
Regional estimates of disease and bleaching prevalence are weighted by the number of
grid cells of a stratum in the sample frame. Species-level outputs from
this function are utilized by [NCRMP_DRM_calculate_dis_ble_prevalence_species_domain()].
}
