## Function to calculate colony mean (old and new) mortality at the site and strata level

# Purpose:
# creates csv files with mean mortality.


## Tag: data analysis


# outputs created in this file --------------
# old_mortality_site
# new_mortality_site
# Domain estimates



# CallS:
# analysis ready data

# output gets called by:
# Analysis Rmarkdown, etc.
#

# NCRMP Caribbean Benthic analytics team: Groves, Viehman, Williams
# Last update: Jun 2025


##############################################################################################################################

#' Creates colony mortality summary dataframes
#'
#' Calculates mean old and recent coral mortality at each site, strata, and
#' region from the NCRMP or NCRMP+DRM coral demographic data.
#' Means are also calculated for each species at each strata and for the region.
#' Regional estimates of mortality are weighted by the number of grid cells
#' of a stratum in the sample frame.
#'
#'
#'
#'
#'
#' @param project A string indicating the project, NCRMP ("NCRMP") or NCRMP and DRM combined ("NCRMO_DRM").
#' @param region A string indicating the region. Options include: "FLK", "SEFCRI", "Tortugas", "STX", "STTSTJ", and "FGB".
#' @param species_filter An optional string indicating whether to filter to a subset of species.
#' @return A list of dataframes including 1) mean old mortality at each site, 2)
#' mean recent mortality at each site, 3) mean old mortality in each strata, 4)
#' mean recent mortality in each strata, 5) mean old mortality for each species in
#' each strata, 6) mean recent mortality for each species in each strata, 7)
#' regional estimate for old mortality, 8) regional estimate for recent mortality,
#' 9) regional estimate for old mortality for each species, 10) regional
#' estimate for recent mortality for each species.
#' @importFrom magrittr "%>%"
#' @export
#'
#'
#'

NCRMP_DRM_calculate_mortality <- function(project, region, species_filter = "NULL"){

  #### get demo data ####
      demo_data <- load_NCRMP_DRM_demo_data(project = project, region = region, species_filter = species_filter)
      list2env(demo_data, envir = environment())

   #### Helper Functions ####
      
          #clean old mort data
          clean_old_mortality_data <- function(data) {
            data %>%
              dplyr::filter(N == 1,
                            SUB_REGION_NAME != "Marquesas",
                            SUB_REGION_NAME != "Marquesas-Tortugas Trans",
                            OLD_MORT != "NA",
                            OLD_MORT <= 100) %>%
              dplyr::mutate(PROT = as.factor(PROT),
                            PRIMARY_SAMPLE_UNIT = as.factor(PRIMARY_SAMPLE_UNIT))
          }

          #clean rec mort data
          clean_rec_mortality_data <- function(data) {
            data %>%
              dplyr::filter(N == 1,
                            SUB_REGION_NAME != "Marquesas",
                            SUB_REGION_NAME != "Marquesas-Tortugas Trans",
                            RECENT_MORT != "NA",
                            RECENT_MORT <= 100) %>%
              dplyr::mutate(PROT = as.factor(PROT),
                            PRIMARY_SAMPLE_UNIT = as.factor(PRIMARY_SAMPLE_UNIT))
          }
        
        #calculate avsitemort 
        #this includes a param called column variable, which refs the col name like "OLD_MORT"
          #it also has a mort type param called mort_type, which refers to either recent or old mortality
          calculate_avsitemort  <- function(data, column, mort_type){
          data %>%
            dplyr::summarise(avsitemort = mean({{ column }}), .groups = "keep") %>%
            dplyr::mutate(MORT_TYPE = mort_type) %>%
            dplyr::ungroup()
        }
          
  ####Calculate mean Old mortality####

      if (project == "NCRMP_DRM" || (project == "NCRMP" && (region == "SEFCRI" || region == "Tortugas"))) {
            dat1_1stage <- dat_1stage %>%
              clean_old_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>%
              calculate_avsitemort(OLD_MORT, "Old")
            
            dat1_2stage <- dat_2stage %>%
              clean_old_mortality_data() %>%
              # when data is two stage (two transects or more) calculate transect mean before site mean.
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, STATION_NR, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>%
              dplyr::summarise(transect_mort = mean(OLD_MORT), .groups = "keep") %>%
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>%
              calculate_avsitemort(transect_mort, "Old")
            
            old_mortality_site <- rbind(dat1_1stage, dat1_2stage)

          } else {

            old_mortality_site <- dat_1stage %>%
              clean_old_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(OLD_MORT, "Old")
          }

          #### Apply weighting scheme and calculate strata and regional means ####
          weighted_demo  <- NCRMP_make_weighted_demo_data(project, inputdata = old_mortality_site, region, datatype = "mortality")
          list2env(weighted_demo, envir = environment())

          #mutate mort type
          old_mortality_strata <- mortality_strata %>% dplyr::mutate(MORT_TYPE = "Old")
          Domain_est_old_mort <- Domain_est %>% dplyr::mutate(MORT_TYPE = "Old")


          ####Calculate mean Recent mortality####
          if (project == "NCRMP_DRM" || (project == "NCRMP" && (region == "SEFCRI" || region == "Tortugas"))) {
            
            dat1_1stage <- dat_1stage %>%
              clean_rec_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(RECENT_MORT, "Recent") 

            dat1_2stage <- dat_2stage %>%
              clean_rec_mortality_data() %>%
              # when data is two stage (two transects or more) calculate transect mean before site mean.
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, STATION_NR, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>% #No need to include region, will be added from ntot in wh. function
              dplyr::summarise(transect_mort = mean(RECENT_MORT)) %>%
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>%
              calculate_avsitemort(transect_mort, "Recent") 

            recent_mortality_site <- rbind(dat1_1stage, dat1_2stage)

          } else {
            recent_mortality_site <- dat_1stage %>%
              clean_rec_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(RECENT_MORT, "Recent") 
          }

          #### Apply weighting scheme and calculate strata and regional means ####
          weighted_data  <- NCRMP_make_weighted_demo_data(project, inputdata = recent_mortality_site, region, datatype = "mortality")
          list2env(weighted_data, envir = environment())

          rec_mortality_strata <- mortality_strata %>% dplyr::mutate(MORT_TYPE = "Recent")
          Domain_est_rec_mort <- Domain_est %>% dplyr::mutate(MORT_TYPE = "Recent")
          
          
          #### Old mortality for each species####
          #### regions with 2 stage data ####
          if (project == "NCRMP_DRM" || (project == "NCRMP" && (region == "SEFCRI" || region == "Tortugas"))) {

            dat1_1stage <- dat_1stage %>%
              clean_old_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>%
              calculate_avsitemort(OLD_MORT, "Old") 


            dat1_2stage <- dat_2stage %>%
              clean_old_mortality_data() %>%
              # when data is two stage (two transects or more) calculate transect mean before site mean.
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, STATION_NR, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>%
              dplyr::summarise(transect_mort = mean(OLD_MORT), .groups = "keep") %>%
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>%
              calculate_avsitemort(transect_mort, "Old") 

            #bind the stage 2 and 1 data together
            old_mortality_species_site <- rbind(dat1_1stage, dat1_2stage)

            #### regions w out 2 stage data ####
          } else {

            old_mortality_species_site <- dat_1stage %>%
              clean_old_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(REGION, SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(OLD_MORT, "Old") 
          }

          #### Apply weighting scheme and calculate strata and regional means ####
          weighted_data  <- NCRMP_make_weighted_demo_data(project, inputdata = old_mortality_species_site, region, datatype = "mortality_species")
          list2env(weighted_data, envir = environment())

          #### create specific datasets ####
          old_mortality_species_strata <- mortality_strata_species %>% dplyr::mutate(MORT_TYPE = "Old")
          Domain_est_old_mort_species <- Domain_est_species %>% dplyr::mutate(MORT_TYPE = "Old")
          ntot_check_old_mort_species <- ntot_check

          #### Recent mortality by species ####
          #### regions w 2 stage data ####
          if (project == "NCRMP_DRM" || (project == "NCRMP" && (region == "SEFCRI" || region == "Tortugas"))) {

            dat1_1stage <- dat_1stage %>%
              clean_rec_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(RECENT_MORT, "Recent") 


            dat1_2stage <- dat_2stage %>%
              clean_rec_mortality_data() %>%
              # when data is two stage (two transects or more) calculate transect mean before site mean.
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, STATION_NR, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>% #No need to include region, will be added from ntot in wh. function
              dplyr::summarise(transect_mort = mean(RECENT_MORT)) %>%
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>%
              calculate_avsitemort(transect_mort, "Recent") 
          
            recent_mortality_species_site <- rbind(dat1_1stage, dat1_2stage)

            #### regions without 2 stage data ####
          } else {

            recent_mortality_species_site <- dat_1stage %>%
              clean_rec_mortality_data() %>%
              # calculate site level mortality
              dplyr::group_by(SURVEY, YEAR, SUB_REGION_NAME, PRIMARY_SAMPLE_UNIT, LAT_DEGREES, LON_DEGREES, STRAT, HABITAT_CD, PROT, SPECIES_CD, SPECIES_NAME) %>% #No need to include region, will be added from ntot in wh. function
              calculate_avsitemort(RECENT_MORT, "Recent") 
          }

          
          #### Apply weighting scheme and calculate strata and regional means ####
          weighted_data  <- NCRMP_make_weighted_demo_data(project, inputdata = recent_mortality_species_site, region, datatype = "mortality_species")
          list2env(weighted_data, envir = environment())

          #### Create specific datasets ####
          rec_mortality_species_strata <- mortality_strata_species %>% dplyr::mutate(MORT_TYPE = "Recent")
          Domain_est_rec_mort_species <- Domain_est_species %>% dplyr::mutate(MORT_TYPE = "Recent")
          ntot_check_rec_mort_species <- ntot_check
          

         ####Export####
          output <- list(
            "old_mortality_site" = old_mortality_site,
            "recent_mortality_site" = recent_mortality_site,
            "old_mortality_strata" =old_mortality_strata,
            "rec_mortality_strata" = rec_mortality_strata,
            "old_mortality_species_strata" = old_mortality_species_strata,
            "rec_mortality_species_strata" = rec_mortality_species_strata,
            "Domain_est_old_mort" = Domain_est_old_mort,
            "Domain_est_rec_mort" = Domain_est_rec_mort,
            "Domain_est_old_mort_species" = Domain_est_old_mort_species,
            "Domain_est_rec_mort_species" = Domain_est_rec_mort_species,
            "ntot_check_rec_mort_species" = ntot_check_rec_mort_species,
            "ntot_check_old_mort_species" = ntot_check_old_mort_species)

          return(output)
}


