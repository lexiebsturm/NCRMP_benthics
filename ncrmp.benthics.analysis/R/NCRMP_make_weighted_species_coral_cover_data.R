
## Function to calculate weighted coral cover by species

# Purpose:
# creates csv files with weighted mean density & CVs.


## Tag: data analysis


# outputs created in this file --------------
# region_means
# strata_means
#


# CallS:
# analysis ready data

# output gets called by:
# NCRMP_colony_percent_cover
#



# NCRMP Caribbean Benthic analytics team: Groves, Viehman, Williams
# Last update: Mar 2025


##############################################################################################################################

#' Calculates weighted mean density & CVs of coral cover, by species
#'
#' Calculates weighted benthic cover data for individual coral species. NCRMP utilizes a stratified random
#' sampling design. Regional estimates of coral cover are weighted by the number of grid cells of a stratum
#' in the sample frame. Function calculates strata means, weighted strata means,
#' and weighted regional estimates for for coral cover from benthic cover data.
#' Support function called by [NCRMP_colony_percent cover()].
#'
#'
#'
#'
#' @param region A string indicating the region. Options are: "SEFCRI", "FLK", "Tortugas", "STX", "STTSTJ", "PRICO", and "FGB".
#' @param sppcvr A dataframe of site and species level percent cover data.
#' @param project A string indicating the project: "NCRMP" or "MIR".
#' @return A list of dataframes, including a dataframe of strata mean cover by coral species
#' and a dataframe of regional weighted mean cover by coral species
#' @importFrom magrittr "%>%"
#' @importFrom dplyr "mutate"
#' @importFrom dplyr "n"
#' @export
#'
#'
#'

NCRMP_make_weighted_species_coral_cover_data <- function(region, sppcvr, project = "NULL") {
  
  ####Load NTOT  ####
  ntot <- load_NTOT(region = region, inputdata = sppcvr,project = project)
  
  ####Filter Cover Cats####
    filter_cover_cats <- function(data){
      data %>%
        dplyr::filter(cover_group == "HARD CORALS") %>%
        dplyr::filter(!COVER_CAT_NAME %in% c("Solenastrea spp", "Siderastrea spp", "Scolymia spp", 
                                             "Agaricia spp", "Diploria spp", "Orbicella spp", 
                                             "Madracis spp", "Other coral", "Isophyllia spp", 
                                             "Porites spp", "Meandrina spp", "Pseudodiploria spp", 
                                             "Orbicella annularis species complex", "Tubastraea coccinea"))
    }
  
    #Filtered sppcvr dataset (reduce number of calls to above function)
    filtered_sppcvr <- filter_cover_cats(sppcvr)
     
  ####strata_means####
  strata_means <- filtered_sppcvr %>%
    dplyr::mutate(SPECIES_NAME = COVER_CAT_NAME, cvr = Percent_Cvr) %>%
    dplyr::group_by(REGION, YEAR, SPECIES_NAME, ANALYSIS_STRATUM) %>% 
    # sample variance of density in stratum
    dplyr::summarize(mean = mean(cvr),
                     svar = var(cvr),
                     N_LPI_CELLS_SAMPLED = length(PRIMARY_SAMPLE_UNIT),
                     .groups = "keep") %>%
    # replace zeros with very small number
    dplyr::mutate(svar=dplyr::case_when(svar==0 ~ 0.00000001,
                                        TRUE ~ svar)) %>%
    #variance of mean density in stratum
    dplyr::mutate(Var = svar/N_LPI_CELLS_SAMPLED,
                  # std dev of density in stratum
                  std = sqrt(svar),
                  #SE of the mean density in stratum
                  SE = sqrt(Var),
                  CV_perc = (SE/mean)*100,
                  CV = (SE/mean))
  
  ####region/population means####
  region_means <- strata_means %>%
    dplyr::left_join(ntot) %>% #add in ntot
    dplyr::mutate(wh_mean = wh*mean,
                  wh_var = wh^2*Var) %>%
    dplyr::group_by(REGION, YEAR, SPECIES_NAME) %>%
    dplyr::summarize(avCvr = sum(wh_mean),
                     Var = sum(wh_var,na.rm = TRUE),
                     SE = sqrt(Var),
                     CV_perc = (SE/avCvr)*100,
                     CV = (SE/avCvr),
                     n_sites = sum(N_LPI_CELLS_SAMPLED),
                     .groups = "keep") %>%
    dplyr::mutate(STRAT_ANALYSIS = "ALL_STRAT",
                  DEPTH_STRAT = "ALL_DEPTHS",
                  HABITAT_CD = "ALL_HABS") %>%  #add svar variable
    dplyr::select(REGION, YEAR, STRAT_ANALYSIS, SPECIES_NAME, avCvr, Var, SE, CV_perc, CV, n_sites, HABITAT_CD, DEPTH_STRAT)
  
  ####Strata Pres: Calculate n sites present for each species####
  strata_presence <- filtered_sppcvr %>%
    dplyr::mutate(SPECIES_NAME = COVER_CAT_NAME,
                  cvr = Percent_Cvr) %>%
    # remove sites where species not present
    dplyr::filter(cvr > 0) %>%
    dplyr::group_by(REGION, YEAR, SPECIES_NAME, ANALYSIS_STRATUM) %>%
    dplyr::summarize(n_sites = n(), .groups = "keep") %>%
    dplyr::ungroup()
  
  ####Region Presence####
  region_presence <- strata_presence %>%
    dplyr::group_by(REGION, YEAR, SPECIES_NAME) %>%
    dplyr::summarize(n_sites_present = sum(n_sites),
                     .groups = "keep") %>%
    dplyr::ungroup()
  
  ####Region Means####
  region_means <- dplyr::left_join(region_means, region_presence) %>%
    dplyr::select(REGION, YEAR, STRAT_ANALYSIS, SPECIES_NAME, avCvr, Var, SE, CV_perc, CV, n_sites_present, n_sites, HABITAT_CD, DEPTH_STRAT) %>%
    # drop rows with NA as species code
    tidyr::drop_na(SPECIES_NAME) %>%
    # exclude rows with -spp in name
    dplyr::filter(., !grepl('spp', SPECIES_NAME)) %>%
    dplyr::mutate(n_sites_present = tidyr::replace_na(n_sites_present, 0))
  
  ####Export####
  output <- list(
    "region_means" = region_means,
    "strata_means" = strata_means)
  
  return(output)
}

