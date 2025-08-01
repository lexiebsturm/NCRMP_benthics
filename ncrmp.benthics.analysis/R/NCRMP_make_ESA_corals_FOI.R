## Function to calculate FOI at the species and region level for the most recent sampling year.

# Purpose:
# creates csv files


## Tag: data analysis


# outputs created in this file --------------
# FOI
#
#

# CallS:
# Invert and ESA corals analysis ready data

# output gets called by:
# Tech memo Rmarkdown
#

# NCRMP Caribbean Benthic analytics team: Groves, Viehman, Williams, Sturm
# Last update: Jun 2025


##############################################################################################################################

#' Calculate ESA FOI
#'
#' Calculates frequency of occurrence of ESA corals from the benthic assessment
#' diver's data, for only the most recent year of data for all regions. Summaries
#' are for both all ESA's and each ESA species.
#'
#'
#'
#'
#' @return A list of dataframes including 1) FOI for each region in the most
#' recent year for all ESA corals, and 2) FOI for each region in the most recent
#' year for each ESA coral species.
#' @importFrom magrittr "%>%"
#' @export
#'
#'

NCRMP_make_ESA_corals_FOI <- function(){
  ####Map values helper function####
  # converts species value to 1 if observed as present (P/PT/PS), 0 else
  map_values <- function(x) {
    dplyr::case_when(
      x %in% c("PS", "PT", "P") ~ 1,
      x == "A" ~ 0,
      TRUE ~ 0
    )
  }
  
  # Helper: Converts species value to 1 if surveyed at all (+ A), 0 otherwise
  map_values_2 <- function(x) {
    dplyr::case_when(
      x %in% c("PS", "PT", "P", "A") ~ 1,
      TRUE ~ 0
    )
  }
  
  #### Combine all the datasets####
  #Note: SEFCRI_2024 has RUGOSITY_CD dropped 
  data <- dplyr::bind_rows(USVI_2023_inverts_ESAcorals,
                           PRICO_2023_inverts_ESAcorals,
                           FLK_2024_inverts_ESAcorals,
                           Tortugas_2024_inverts_ESAcorals,
                           FGBNMS_2024_inverts_ESAcorals,
                           SEFCRI_2022_inverts_ESAcorals,
                           FLK_2022_inverts_ESAcorals,
                           Tortugas_2022_inverts_ESAcorals,
                           SEFCRI_2024_inverts_ESAcorals
                           %>% dplyr::select(-RUGOSITY_CD))


  ####Helper function that sums ESA species ####
  sum_esa_species <- function(data){
    data %>%
      dplyr::summarise(OANN = sum(O_ANNULARIS),
                       OFRA = sum(O_FRANKSI),
                       OFAV = sum(O_FAVEOLATA),
                       APAL = sum(A_PALMATA),
                       ACER = sum(A_CERVICORNIS),
                       DCYL = sum(D_CYLINDRUS),
                       MFER = sum(M_FEROX),
                       .groups = "keep")
  }
  
  #### Helper Function that pivots data longer####
  # this function includes the param values_to
  pivot_longer_function <- function(data, values_to){
    data %>%
      tidyr::pivot_longer(., cols = OANN:MFER,
                          names_to= "species",
                          values_to = values_to)
  }
  
  #### Create presence counts by species by region/year ####
  esa_spp <- data%>%
    #Calc totals by species by region
    dplyr::mutate(
      O_ANNULARIS = map_values(O_ANNULARIS),
      O_FRANKSI = map_values(O_FRANKSI),
      O_FAVEOLATA = map_values(O_FAVEOLATA),
      A_PALMATA = map_values(A_PALMATA),
      A_CERVICORNIS = map_values(A_CERVICORNIS),
      D_CYLINDRUS = map_values(D_CYLINDRUS),
      M_FEROX = map_values(M_FEROX)
    ) %>%
    dplyr::group_by(REGION, YEAR) %>%
    summarise_esa_species() %>%
    pivot_longer_function(values_to = "N") 


  #### get total # of sites surveyed for each speciesn####
  # calculate NAs by species (not counted)
  esa_Nsites <-  data %>%
    #Calc totals by species by region
    dplyr::mutate(
      O_ANNULARIS = map_values_2(O_ANNULARIS),
      O_FRANKSI = map_values_2(O_FRANKSI),
      O_FAVEOLATA = map_values_2(O_FAVEOLATA),
      A_PALMATA = map_values_2(A_PALMATA),
      A_CERVICORNIS = map_values_2(A_CERVICORNIS),
      D_CYLINDRUS = map_values_2(D_CYLINDRUS),
      M_FEROX = map_values_2(M_FEROX)
    ) %>%
    dplyr::group_by(REGION, YEAR) %>%
    summarise_esa_species() %>%
    pivot_longer_function(values_to = "Nsites") 

  ##### Join presence and denominator to calculate FOI####
  FOI_species <- esa_spp %>%
    dplyr::full_join(esa_Nsites) %>%
    dplyr::mutate(foi = N/Nsites)

  #### Region level presence w any ESA coral observed on site = 1 ####
  esa_reg <- data%>%
    #Calc totals by species by region
    dplyr::mutate(
      O_ANNULARIS = map_values(O_ANNULARIS),
      O_FRANKSI = map_values(O_FRANKSI),
      O_FAVEOLATA = map_values(O_FAVEOLATA),
      A_PALMATA = map_values(A_PALMATA),
      A_CERVICORNIS = map_values(A_CERVICORNIS),
      D_CYLINDRUS = map_values(D_CYLINDRUS),
      M_FEROX = map_values(M_FEROX)
    ) %>%
    dplyr::mutate(N_esa = O_ANNULARIS+O_FRANKSI+O_FAVEOLATA+A_PALMATA+A_CERVICORNIS+D_CYLINDRUS+M_FEROX) %>%
    dplyr::mutate(esa_present = dplyr::case_when(N_esa > 0 ~ 1, TRUE ~ 0)) %>%
    dplyr::group_by(REGION, YEAR) %>%
    dplyr::summarise(N_esa = sum(esa_present), .groups = "keep")

  ####Get num of sites####
  Nsites<- esa_Nsites %>%
    dplyr::group_by(REGION, YEAR) %>%
    dplyr::arrange(desc(Nsites), .by_group = TRUE) %>%
    dplyr::summarise(Nsites=dplyr::first(Nsites))

  FOI_region <- esa_reg %>%
    dplyr::full_join(Nsites) %>%
    dplyr::mutate(foi = N_esa/Nsites)

  ####Export####
  output <- list("FOI_region" = FOI_region,
                 "FOI_species" = FOI_species)

  return(output)
}

