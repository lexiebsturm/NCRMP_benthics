## Function to calculate weighted coral density, species richness, mortality and disease prevalence by strata and protected area

# Purpose:
# support function to calculate weighted coral density, species richness, mortality and disease prevalence


## Tag: data analysis


# outputs created in this file --------------
# density_strata
# richness_strata
# mortality_strata
# dis_prev_strata
# size_strata
# and Domain estimates for each of the above metric

# Weighting scheme:
# STRAT + PROT
# STRAT (Carib/FGB)


# Calls:
# analysis ready data

# output gets called by:
# NCRMP_calculate_species_richness_diversity.R
# NCRMP_DRM_calculate_colony_density.R
# NCRMP_DRM_calculate_mortality.R
# NCRMP_DRM_calculate_disease_prevalence.R
# NCRMP_DRM_calculate_mean_colony_size

# NCRMP Caribbean Benthic analytics team: Groves, Viehman, Williams
# Last update: Jul 2026


##############################################################################################################################

#' Creates weighted coral demographic data
#'
#' Calculates weighted coral demographic data. NCRMP utilizes a stratified random
#' sampling design. Regional estimates of measures like density, mortality,
#' bleaching prevalence, etc. are weighted by the number of grid cells of a stratum
#' in the sample frame. Function produces strata means, weighted strata means,
#' and weighted regional estimates for various measures from coral demographic data.
#' Support function called by various other functions that run data summary calculations
#' such as [NCRMP_DRM_calculate_colony_density()] and [NCRMP_DRM_calculate_mortality()].
#'
#'
#'
#' @param project A string indicating the project, "NCRMP" or NCRMP and DRM combined ("NCRMP_DRM").
#' @param inputdata A dataframe A dataframe of coral demographic data. Can be in various forms.
#' @param region A string indicating the region.  Options are: "SEFCRI", "FLK", "Tortugas", "STX", "STTSTJ", "PRICO", and "FGB".
#' @param datatype A string indicating the datatype. String is based on the inputdata supplied.
#' @return A list of dataframes. Output varies by datatype.
#' @importFrom magrittr "%>%"
#' @export
#'
#'

NCRMP_make_weighted_demo_data <- function(project, inputdata, region, datatype, species_filter){
  
  #### Define regional groups   ####
  FL <- c("SEFCRI", "FLK", "Tortugas")
  FGB <- "FGB"
  Carib <- c("STTSTJ", "STX", "PRICO")

  #### Get NTOT   ####
  if(datatype == "mortality_species" | datatype == "size_species"){
    ntot <- load_NTOT_species(region = region, inputdata = inputdata, project = project)
  }else{
    ntot <- load_NTOT(region = region, inputdata = inputdata, project = project)
  }

  #### Richness   ####
  if (datatype == "richness") {
    
    inputdata <- inputdata %>%
      mutate(
        ANALYSIS_STRATUM = if (region %in% FL) {
          paste(STRAT, "/ PROT =", PROT)
        } else {
          STRAT
        }
      )
    grouping_vars <- if (region %in% FL) {
      c("YEAR", "ANALYSIS_STRATUM", "STRAT", "PROT")
    } else {
      c("YEAR", "ANALYSIS_STRATUM", "STRAT")
    }
    
    richness_est <- inputdata %>%
      group_by(across(all_of(grouping_vars))) %>%
      summarise(
        avspr = mean(SPP_RICHNESS, na.rm = TRUE),
        svar = var(SPP_RICHNESS, na.rm = TRUE),
        n = n_distinct(PRIMARY_SAMPLE_UNIT),
        .groups = "drop") %>%
      mutate(
        svar = ifelse(svar == 0, 1e-8, svar),
        Var = svar / n,
        std = sqrt(svar),
        SE = sqrt(Var) ) %>%
      full_join(ntot, by = c("YEAR", "ANALYSIS_STRATUM", "STRAT")) %>%
      mutate(
        whavspr = wh * avspr,
        whvar = wh^2 * Var,
        n = tidyr::replace_na(n, 0),
        PROT = if (!"PROT" %in% colnames(.)) NA else PROT,
        RUG_CD = NA
      )
    # Strata estimates
    richness_strata <- richness_est %>%
      select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, RUG_CD, PROT, NTOT, n, avspr, Var, SE) %>%
      mutate(RUG_CD = as.factor(RUG_CD))
    
    #Domain level estimates
    Domain_est <- richness_est %>%
      group_by(REGION, YEAR) %>%
      summarise(
        avSpr = sum(whavspr, na.rm = TRUE),
        Var = sum(whvar, na.rm = TRUE),
        SE = sqrt(Var),
        n_sites = sum(n),
        n_strat = n_distinct(ANALYSIS_STRATUM),
        ngrtot = sum(NTOT, na.rm = TRUE),
        .groups = "drop"
      )
    
    return(list(
      richness_strata = richness_strata,
      Domain_est = Domain_est
    ))
  }
  

  #### HELPER: Calculate weighted density ####
  calc_density <- function(data){
    data %>%
      dplyr::summarise(
        avden = mean(DENSITY), # compute average density
        svar = var(DENSITY), # comp stratum variance
        n = length(unique(PRIMARY_SAMPLE_UNIT))) %>% #calculate N
      # convert 0 for stratum variance so that the sqrt is a small # but not a 0
      dplyr::mutate(svar = dplyr::case_when(svar == 0 ~ 0.00000001, TRUE ~ svar)) %>%
      dplyr::mutate(Var=svar/n, #variance of mean density in stratum
                    std = sqrt(svar), # std dev of density in stratum
                    SE=sqrt(Var), #SE of the mean density in stratum
                    CV_perc=(SE/avden)*100) %>%
      dplyr::full_join(., ntot) %>% # Merge ntot with coral_est_spp
      # stratum estimates
      dplyr::mutate(whavden = wh * avden,
                    whvar = wh^2 * Var,
                    n = tidyr::replace_na(n, 0),
                    # Add the following to match FL format
                    PROT = 0,
                    RUG_CD = NA)  %>% dplyr::ungroup()
  }

  ####Density####
  if(datatype == "density"){
    if(region %in% FL) {
      # Calculate avdns, svar, n and std
      density_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT) %>% 
        calc_density()
    }

    if(region %in% FGB | region %in% Carib) {
      # Calculate avdns, svar, n and std
      density_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT) %>% 
        calc_density()
    }

    # Reformat output
    # strata_means
    density_strata <-  density_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, n, avden, Var, SE, CV_perc)


    calc_domain_estimates <- function(data){
      data %>%
        dplyr::summarise(avDen = sum(whavden, na.rm = T), 
                         Var = sum(whvar, na.rm = T),    
                         SE=sqrt(Var),
                         CV_perc=(SE/avDen)*100,
                         n_sites = sum(n),
                         n_strat = length(unique(ANALYSIS_STRATUM)),
                         ngrtot = sum(NTOT) )  %>%
        dplyr::ungroup()
    }


    if(project == "NCRMP" || project == "NULL" || project == "NCRMP_DRM") {

      ## Domain Estimates
      # region/population means
      Domain_est <- density_est %>%
        dplyr::group_by(REGION, YEAR) %>%
        calc_domain_estimates()
    
      #Export
      output <- list(
        "density_strata" = density_strata,
        "Domain_est" = Domain_est)

      return(output)
    } #end NCRMP/NULL/NCRMP_DRM


    if(project == "MIR"){

      ## Domain Estimates
      # region/population means
      Domain_est <- density_est %>%
        dplyr::group_by(REGION, YEAR) %>%
        calc_domain_estimates()

      Domain_est_PROT <- density_est %>%
        dplyr::group_by(REGION, YEAR, PROT) %>%
        calc_domain_estimates()

      #Export
      output <- list(
        "density_strata" = density_strata,
        "Domain_est" = Domain_est,
        "Domain_est_PROT" = Domain_est_PROT)

      return(output)
    } #end MIR
  } #end density


  #### Calculate mortality ####

  calc_mortality <- function(data){
    data %>%
      dplyr::summarise(
        avmort = mean(avsitemort), # compute average mortality
        svar = var(avsitemort), # compute stratum variance
        n = length(unique(PRIMARY_SAMPLE_UNIT)), .groups = "keep") %>%
      # convert 0 for stratum variance so that the sqrt is a small # but not a 0
      dplyr::mutate(svar = dplyr::case_when(svar == 0 ~ 0.00000001, TRUE ~ svar)) %>%
      dplyr::mutate(Var=svar/n, #variance of mean density in stratum
                    std = sqrt(svar), # std dev of density in stratum
                    SE=sqrt(Var), #SE of the mean density in stratum
                    CV_perc=(SE/avmort)*100) %>%
      dplyr::full_join(., ntot) %>% # Merge ntot with coral_est_spp
      # stratum estimates
      dplyr::mutate(whavmort = wh * avmort,
                    whvar = wh^2 * Var,
                    n = tidyr::replace_na(n, 0),
                    # Add the following to match FL format
                    PROT = NA,
                    RUG_CD = NA)  %>%
      dplyr::ungroup()
  }

  if(datatype == "mortality"){

    if(region %in% FL) {

      # Calculate avmort, svar, n and std
      mortality_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT, MORT_TYPE) %>%  
        calc_mortality()
    }

    if(region %in% FGB | region %in% Carib) {

      # Calculate avdns, svar, n and std
      mortality_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, MORT_TYPE) %>%  
        calc_mortality()
    }

    # Reformat output
    # strata_means
    mortality_strata <-  mortality_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, n, avmort, Var, SE, CV_perc)

    ## Domain Estimates
    # region/population means
    Domain_est <- mortality_est %>%
      dplyr::group_by(REGION, YEAR) %>%
      dplyr::summarise(avMort = sum(whavmort, na.rm = T), # This accounts for strata with 0 species of interest present
                       Var = sum(whvar, na.rm = T),    # This accounts for strata with N = 1
                       SE=sqrt(Var),
                       CV_perc=(SE/avMort)*100,
                       n_sites = sum(n),
                       n_strat = length(unique(ANALYSIS_STRATUM)),
                       ngrtot = sum(NTOT), .groups = "keep" )  %>%
      dplyr::ungroup()

    #Export
    output <- list(
      "mortality_strata" = mortality_strata,
      "Domain_est" = Domain_est)

    return(output)
  } #end mortality


  #### Calculate mortality by species ####

  calc_mort_by_species <- function(data){
    data %>%
    dplyr::summarise(
      avmort = mean(avsitemort), # compute average mortality
      svar = var(avsitemort), # compute stratum variance
      n = length(unique(PRIMARY_SAMPLE_UNIT)), .groups = "keep") %>%
    # convert 0 for stratum variance so that the sqrt is a small # but not a 0
    dplyr::mutate(svar = dplyr::case_when(svar == 0 ~ 0.00000001, TRUE ~ svar)) %>%
    dplyr::mutate(Var=svar/n, #variance of mean density in stratum
                    std = sqrt(svar), # std dev of density in stratum
                    SE=sqrt(Var), #SE of the mean density in stratum
                    CV_perc=(SE/avmort)*100) %>%
      dplyr::full_join(., ntot) %>% # Merge ntot with coral_est_spp
      dplyr::mutate(whavmort = wh * avmort,
                    whvar = wh^2 * Var,
                    n = tidyr::replace_na(n, 0),
                    # Add the following to match FL format
                    PROT = NA,
                    RUG_CD = NA)  %>%
      dplyr::ungroup()
  }

  #### Mortality Species ####
  if(datatype == "mortality_species"){

    if(region %in% FL) {

      # Calculate avmort, svar, n and std
      mortality_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT, MORT_TYPE, SPECIES_CD, SPECIES_NAME) %>%  
        calc_mort_by_species()
    }

    if(region %in% FGB | region %in% Carib) {

      mortality_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, MORT_TYPE, SPECIES_CD, SPECIES_NAME) %>%  
        calc_mort_by_species()
    }

    # Reformat output
    # strata_means
    mortality_strata_species <-  mortality_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, SPECIES_CD, SPECIES_NAME, n, avmort, Var, SE, CV_perc)

    # ntot check - sum of weights should = 1
    ntot_check <- mortality_est %>%
      dplyr::group_by(YEAR, SPECIES_CD) %>%
      dplyr::summarize(wh_sum = sum(wh))

    ## Domain Estimates
    # region/population means
    Domain_est_species <- mortality_est %>%
      dplyr::group_by(REGION, YEAR, SPECIES_CD, SPECIES_NAME) %>%
      dplyr::summarise(avMort = sum(whavmort, na.rm = T), # This accounts for strata with 0 species of interest present
                       Var = sum(whvar, na.rm = T),    # This accounts for strata with N = 1
                       SE=sqrt(Var),
                       CV_perc=(SE/avMort)*100,
                       n_sites = sum(n),
                       n_strat = length(unique(ANALYSIS_STRATUM)),
                       ngrtot = sum(NTOT), .groups = "keep" )  %>%
      dplyr::ungroup()

    #Export
    output <- list(
      "mortality_strata_species" = mortality_strata_species,
      "Domain_est_species" = Domain_est_species,
      "ntot_check" = ntot_check)

    return(output)
  } #end mortaility by species

  #### Diversity helper function ####
  diversity_helper_function <- function(data){
    data %>%
    dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT) %>% 
      dplyr::summarise(
        # compute average diversity
        avSimp = mean(Simpson, na.rm = T),
        avInvSimp = mean(Inv_Simpson, na.rm = T),
        avShannon = mean(Shannon, na.rm = T),
        # compute stratum variance
        svar_Simp = var(Simpson, na.rm = T),
        svar_InvSimp = var(Inv_Simpson, na.rm = T),
        svar_Shan = var(Shannon, na.rm = T),
        n = length(Simpson)) %>%
      # convert 0 for stratum variance so that the sqrt is a small # but not a 0
      dplyr::mutate(svar_Simp = dplyr::case_when(svar_Simp == 0 ~ 0.00000001,
                                                 TRUE ~ svar_Simp),
                    svar_InvSimp = dplyr::case_when(svar_InvSimp == 0 ~ 0.00000001,
                                                    TRUE ~ svar_InvSimp),
                    svar_Shan = dplyr::case_when(svar_Shan == 0 ~ 0.00000001,
                                                 TRUE ~ svar_Shan)) %>%
      dplyr::mutate(Var_Simp =svar_Simp/n,
                    Var_InvSimp = svar_InvSimp,
                    Var_Shan = svar_Shan,
                    std_Simp = sqrt(svar_Simp),
                    std_InvSimp = sqrt(svar_InvSimp),
                    std_Shan = sqrt(svar_Shan),
                    SE_Simp = sqrt(Var_Simp),
                    SE_InvSimp = sqrt(Var_InvSimp),
                    SE_Shan = sqrt(Var_Shan))
  }
  
  #### Diversity Ntot Helper Function ####
  diversity_ntot_helper <- function(data){
    data %>%
      dplyr::mutate(whavSimp = wh * avSimp,
                    whavInvSimp = wh * avInvSimp,
                    whavShan = wh * avShannon,
                    whvar_Simp = wh^2 * Var_Simp,
                    whvar_InvSimp = wh^2 * Var_InvSimp,
                    whvar_Shan = wh^2 * Var_Shan,
                    n = tidyr::replace_na(n, 0)) 
  }
  #### Diversity   ####
  if(datatype == "diversity"){
    
    if(region %in% FL) {
      
      # Calculate avdiv, svar, n and std
      diversity_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
        diversity_helper_function()
      
      diversity_est <- diversity_est %>%
        # Merge ntot with diversity_est
        dplyr::full_join(., ntot) %>%
        # stratum estimates
        diversity_ntot_helper() %>%
        dplyr::ungroup()
    }
    
    if(region %in% FGB | region %in% Carib) {
      # Calculate avdiv, svar, n and std
      diversity_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        diversity_helper_function()
      
      diversity_est <- diversity_est %>%
        # Merge ntot with diversity_est
        dplyr::full_join(., ntot) %>%
        diversity_ntot_helper() %>%
        # stratum estimates
        dplyr::mutate(PROT = NA,
                      RUG_CD = NA)  %>%  dplyr::ungroup()
    }
  
    # Reformat output
    
    diversity_strata <-  diversity_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, NTOT, n,
                    avSimp, avInvSimp, avShannon, Var_Simp, Var_InvSimp, Var_Shan,
                    SE_Simp, SE_InvSimp, SE_Shan)
    # REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, n, avmort, Var, SE, CV_perc
    
    ## Domain Estimates
    Domain_est <- diversity_est %>%
      dplyr::group_by(REGION, YEAR) %>%
      dplyr::summarise(avSimp = sum(whavSimp, na.rm = T),
                       avInvSimp = sum(whavInvSimp, na.rm = T),
                       avShan = sum(whavShan, na.rm = T),
                       Var_Simp = sum(whvar_Simp, na.rm = T),
                       Var_InvSimp = sum(whvar_InvSimp, na.rm = T),
                       Var_Shan = sum(whvar_Shan, na.rm = T),
                       SE_Simp = sqrt(Var_Simp),
                       SE_InvSimp = sqrt(Var_InvSimp),
                       SE_Shan = sqrt(Var_Shan),
                       n_sites = sum(n),
                       n_strat = length(unique(ANALYSIS_STRATUM)),
                       ngrtot = sum(NTOT), .groups = "keep" )  %>%
      dplyr::ungroup()
    
    # Create list to export
    output <- list(
      "diversity_strata" = diversity_strata,
      "Domain_est_div" = Domain_est)
    
    return(output)
  }


  ####Calculate Disease####

  calc_disease <- function(data){
    data %>%
      dplyr::summarise(# compute average density
        avDprev = mean(DIS_PREV),
        avBprev = mean(BLE_PREV),
        # compute stratum variance
        svarD = var(DIS_PREV),
        svarB = var(BLE_PREV),
        # calculate N
        n_sites = length(PRIMARY_SAMPLE_UNIT)) %>%
      # convert 0 for stratum variance so that the sqrt is a small # but not a 0
      dplyr::mutate(svarD = dplyr::case_when(svarD == 0 ~ 0.00000001, TRUE ~ svarD)) %>%
      dplyr::mutate(stdD = sqrt(svarD))%>%
      # convert 0 for stratum variance so that the sqrt is a small # but not a 0
      dplyr::mutate(svarB = dplyr::case_when(svarB == 0 ~ 0.00000001, TRUE ~ svarB)) %>%
      dplyr::mutate(stdB = sqrt(svarB)) %>%
      dplyr::full_join(., ntot) %>% # Merge ntot with coral_est_spp
      # stratum estimates
      dplyr::mutate(whavDprev = wh * avDprev,
                    whavBprev = wh * avBprev,
                    whsvarD = wh^2 * svarD,
                    whsvarB = wh^2 * svarB,
                    whstdD = wh * stdD,
                    whstdB = wh * stdB,
                    n_sites = tidyr::replace_na(n_sites, 0))  %>%
      dplyr::ungroup()
  }
  
  if(datatype == "disease"){

    if(region %in% FL) {

      # Calculate avprev, svar, n and std
      disease_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT) %>%  
        calc_disease()
    }

    if(region %in% FGB |
       region %in% Carib) {

      # Calculate avprev, svar, n and std
      disease_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT) %>%  
        calc_disease()
    }

    # Reformat output
    disease_est <- disease_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avDprev, svarD, stdD, whavDprev, whsvarD, whstdD,
                    avBprev, svarB, stdB, whavBprev, whsvarB, whstdB)

    dis_prev_strata <-  disease_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avDprev, svarD, stdD)

    ble_prev_strata <-  disease_est %>%
      dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, avBprev, svarB, stdB)

    ## Domain Estimates
    Domain_est <- disease_est %>%
      dplyr::group_by(REGION, YEAR) %>%
      dplyr::summarise(avDisPrev = sum(whavDprev, na.rm = T), # This accounts for strata with 0 species of interest present
                       avBlePrev = sum(whavBprev, na.rm = T),
                       VarD = sum(whsvarD, na.rm = T),
                       VarB = sum(whsvarB, na.rm = T),# This accounts for strata with N = 1
                       SE_D=sqrt(VarD),
                       SE_B=sqrt(VarB),
                       n_sites = sum(n_sites),
                       n_strat = length(unique(ANALYSIS_STRATUM)),
                       ngrtot = sum(NTOT) )  %>%
      dplyr::ungroup()

    # Create list to export
    output <- list(
      "dis_prev_strata" = dis_prev_strata,
      'ble_prev_strata' = ble_prev_strata,
      "Domain_est" = Domain_est)

    return(output)
  } #end disase

  
  ####Helper Function: Calculate Size ####
  calc_size <- function(data){
  data %>%
    dplyr::summarise(
      # compute average size
      avcm2 = mean(avg_cm2),
      avcm3 = mean(avg_cm3),
      av_maxdiam = mean(avg_maxdiam),
      # compute stratum variance
      svarcm2 = var(avg_cm2),
      svarcm3 = var(avg_cm3),
      svar_maxdiam = var(avg_maxdiam),
      # calculate N
      n_sites = length(PRIMARY_SAMPLE_UNIT)
    ) %>%
    # convert 0 for stratum variance so that the sqrt is a small # but not a 0
    dplyr::mutate(svarcm2 = dplyr::case_when(svarcm2 == 0 ~ 0.00000001, TRUE ~ svarcm2)) %>%
    dplyr::mutate(stdcm2 = sqrt(svarcm2)) %>%
    # convert 0 for stratum variance so that the sqrt is a small # but not a 0
    dplyr::mutate(svarcm3 = dplyr::case_when(svarcm3 == 0 ~ 0.00000001, TRUE ~ svarcm3)) %>%
    dplyr::mutate(stdcm3 = sqrt(svarcm3)) %>%
    # convert 0 for stratum variance so that the sqrt is a small # but not a 0
    dplyr::mutate(svar_maxdiam = dplyr::case_when(svar_maxdiam == 0 ~ 0.00000001, TRUE ~ svar_maxdiam)) %>%
    dplyr::mutate(std_maxdiam = sqrt(svar_maxdiam)) %>%
    # Merge ntot with data
    dplyr::full_join(., ntot) %>%
    # stratum estimates
    dplyr::mutate(
      whavcm2 = wh * avcm2,
      whavcm3 = wh * avcm3,
      whav_maxdiam = wh * av_maxdiam,
      whsvarcm2 = wh^2 * svarcm2,
      whsvarcm3 = wh^2 * svarcm3,
      whsvar_maxdiam = wh^2 * svar_maxdiam,
      whstdcm2 = wh * stdcm2,
      whstdcm3 = wh * stdcm3,
      whstd_maxdiam = wh * std_maxdiam,
      n_sites = tidyr::replace_na(n_sites, 0)
    ) %>%
    dplyr::ungroup()
}

  #### Datatype = Size ####
  if(datatype == "size"){

    if(region %in% FL && project == "NCRMP"){
        # Calculate av, svar, n and std
        size_est <- inputdata %>%
          # group by analysis level strata
          dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
          dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT) %>%  
          calc_size()
    }
      if(region %in% FL && project == "NCRMP_DRM"){
        # Calculate av, svar, n and std
        size_est <- inputdata %>%
          # group by analysis level strata
          dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
          dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, PROT) %>%  
          dplyr::summarise(
            av_maxdiam = mean(avg_maxdiam), # compute average size
            svar_maxdiam = var(avg_maxdiam),# compute stratum variance
            n_sites = length(PRIMARY_SAMPLE_UNIT)) %>% # calculate N
          dplyr::mutate(svar_maxdiam = dplyr::case_when(svar_maxdiam == 0 ~ 0.00000001, TRUE ~ svar_maxdiam)) %>%
          dplyr::mutate(std_maxdiam = sqrt(svar_maxdiam)) %>%
          dplyr::full_join(., ntot) %>% # Merge ntot with coral_est_spp
          # stratum estimates
          dplyr::mutate(whav_maxdiam = wh * av_maxdiam,
                        whsvar_maxdiam = wh^2 * svar_maxdiam,
                        whstd_maxdiam = wh * std_maxdiam,
                        n_sites = tidyr::replace_na(n_sites, 0))  %>%
          dplyr::ungroup()
      }

    if(region %in% FGB | region %in% Carib) {

      size_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT) %>%  
        calc_size()
    }

    # Reformat output
    if(project == "NCRMP"){
      size_est <- size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avcm2, svarcm2, stdcm2, whavcm2, whsvarcm2, whstdcm2,
                      avcm3, svarcm3, stdcm3, whavcm3, whsvarcm3, whstdcm3, av_maxdiam, svar_maxdiam, std_maxdiam, whav_maxdiam, whsvar_maxdiam, whstd_maxdiam)

      size_est_cm2_strata <-  size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avcm2, svarcm2, stdcm2)

      size_est_cm3_strata <-  size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, avcm3, svarcm3, stdcm3)

      size_est_maxdiam_strata <-  size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, av_maxdiam, svar_maxdiam, std_maxdiam)

      ## Domain Estimates
      Domain_est <- size_est %>%
        dplyr::group_by(REGION, YEAR) %>%
        dplyr::summarise(avCm2 = sum(whavcm2, na.rm = T), # This accounts for strata with 0 species of interest present
                         avCm3 = sum(whavcm3, na.rm = T),
                         avMaxdiam = sum(whav_maxdiam, na.rm = T),
                         Var_cm2 = sum(whsvarcm2, na.rm = T),
                         Var_cm3 = sum(whsvarcm3, na.rm = T),# This accounts for strata with N = 1
                         Var_maxdiam = sum(whsvar_maxdiam, na.rm = T),
                         SE_cm2=sqrt(Var_cm2),
                         SE_cm3=sqrt(Var_cm3),
                         SE_maxdiam=sqrt(Var_maxdiam),
                         n_sites = sum(n_sites),
                         n_strat = length(unique(ANALYSIS_STRATUM)),
                         ngrtot = sum(NTOT) )  %>%
        dplyr::ungroup()
    }

    if(project == "NCRMP_DRM"){

      size_est <- size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, av_maxdiam, svar_maxdiam, std_maxdiam, whav_maxdiam, whsvar_maxdiam, whstd_maxdiam)

      size_est_maxdiam_strata <-  size_est %>%
        dplyr::select(REGION, YEAR, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, av_maxdiam, svar_maxdiam, std_maxdiam)

      ## Domain Estimates
      Domain_est <- size_est %>%
        dplyr::group_by(REGION, YEAR) %>%
        dplyr::summarise(avMaxdiam = sum(whav_maxdiam, na.rm = T),
                         Var_maxdiam = sum(whsvar_maxdiam, na.rm = T),
                         SE_maxdiam=sqrt(Var_maxdiam),
                         n_sites = sum(n_sites),
                         n_strat = length(unique(ANALYSIS_STRATUM)),
                         ngrtot = sum(NTOT) )  %>%
        dplyr::ungroup()
    }

    # Create list to export
    if(project == "NCRMP"){
      output <- list(
        "size_est_cm2_strata" = size_est_cm2_strata,
        'size_est_cm3_strata' = size_est_cm3_strata,
        "size_est_maxdiam_strata" = size_est_maxdiam_strata,
        "Domain_est" = Domain_est)
    }
    if(project == "NCRMP_DRM"){
      output <- list(
        "size_est_maxdiam_strata" = size_est_maxdiam_strata,
        "Domain_est" = Domain_est)
    }
    return(output)
  } #End size


  ### Helper: Size Species ####

  calc_size_species <- function(data) {
    data%>%
      dplyr::summarise(# compute average size
        avcm2 = mean(avg_cm2, na.rm = T), # needed because the DRM data doesn't collect perp diameter, and the area and volume measurements can't be calculated
        avcm3 = mean(avg_cm3, na.rm = T), # needed because the DRM data doesn't collect perp diameter, and the area and volume measurements can't be calculated
        av_maxdiam = mean(avg_maxdiam),
        # compute stratum variance
        svarcm2 = var(avg_cm2, na.rm = T), # needed because the DRM data doesn't collect perp diameter, and the area and volume measurements can't be calculated
        svarcm3 = var(avg_cm3, na.rm = T), # needed because the DRM data doesn't collect perp diameter, and the area and volume measurements can't be calculated
        svar_maxdiam = var(avg_maxdiam),
        n_sites = length(PRIMARY_SAMPLE_UNIT)) %>%# calculate N
      dplyr::mutate(svarcm2 = dplyr::case_when(svarcm2 == 0 ~ 0.00000001,TRUE ~ svarcm2)) %>%
      dplyr::mutate(stdcm2 = sqrt(svarcm2))%>%
      dplyr::mutate(svarcm3 = dplyr::case_when(svarcm3 == 0 ~ 0.00000001, TRUE ~ svarcm3)) %>%
      dplyr::mutate(stdcm3 = sqrt(svarcm3)) %>%
      dplyr::mutate(svar_maxdiam = dplyr::case_when(svar_maxdiam == 0 ~ 0.00000001, TRUE ~ svar_maxdiam)) %>%
      dplyr::mutate(std_maxdiam = sqrt(svar_maxdiam)) %>%
      dplyr::full_join(., ntot) %>%# Merge ntot with coral_est_spp
      # stratum estimates
      dplyr::mutate(whavcm2 = wh * avcm2,
                    whavcm3 = wh * avcm3,
                    whav_maxdiam = wh * av_maxdiam,
                    whsvarcm2 = wh^2 * svarcm2,
                    whsvarcm3 = wh^2 * svarcm3,
                    whsvar_maxdiam = wh^2 * svar_maxdiam,
                    whstdcm2 = wh * stdcm2,
                    whstdcm3 = wh * stdcm3,
                    whstd_maxdiam = wh * std_maxdiam,
                    n_sites = tidyr::replace_na(n_sites, 0))  %>%
      dplyr::ungroup()
  }

  #### Size Species ####
  if(datatype == "size_species"){

    if(region %in% FL && project == "NCRMP_DRM"){
        # with DRM area and volume are not calculated because perpendicular diameter isn't collected by DRM
        size_est <- inputdata %>%
          # group by analysis level strata
          dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
          dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, SPECIES_CD, SPECIES_NAME) %>%  
          dplyr::summarise(
            av_maxdiam = mean(avg_maxdiam), # compute average size
            svar_maxdiam = var(avg_maxdiam),# compute stratum variance
            n_sites = length(PRIMARY_SAMPLE_UNIT)) %>%  # calculate N
          dplyr::mutate(svar_maxdiam = dplyr::case_when(svar_maxdiam == 0 ~ 0.00000001, TRUE ~ svar_maxdiam)) %>%
          dplyr::mutate(std_maxdiam = sqrt(svar_maxdiam)) %>%
          dplyr::full_join(., ntot) %>%# Merge ntot with coral_est_spp
          # stratum estimates
          dplyr::mutate(whav_maxdiam = wh * av_maxdiam,
                        whsvar_maxdiam = wh^2 * svar_maxdiam,
                        whstd_maxdiam = wh * std_maxdiam,
                        n_sites = tidyr::replace_na(n_sites, 0))  %>%
          dplyr::ungroup()
      }

    if(region %in% FL && project == "NCRMP"){

        # Calculate av, svar, n and std
        size_est <- inputdata %>%
          # group by analysis level strata
          dplyr::mutate(ANALYSIS_STRATUM = paste(STRAT, "/ PROT =", PROT, sep = " ")) %>%
          dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, SPECIES_CD, SPECIES_NAME) %>%  
          calc_size_species()
      }

    if(region %in% FGB | region %in% Carib) {

      # Calculate av, svar, n and std
      size_est <- inputdata %>%
        # group by analysis level strata
        dplyr::mutate(ANALYSIS_STRATUM = STRAT) %>%
        dplyr::group_by(YEAR, ANALYSIS_STRATUM, STRAT, SPECIES_CD, SPECIES_NAME) %>%  
        calc_size_species()
    }
    
    # Reformat output
    if(project == "NCRMP"){

      size_est_species <- size_est %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avcm2, svarcm2, stdcm2, whavcm2, whsvarcm2, whstdcm2,
                      avcm3, svarcm3, stdcm3, whavcm3, whsvarcm3, whstdcm3, av_maxdiam, svar_maxdiam, std_maxdiam, whav_maxdiam, whsvar_maxdiam, whstd_maxdiam)

      size_est_cm2_strata_species <-  size_est_species %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites, avcm2, svarcm2, stdcm2)

      size_est_cm3_strata_species <-  size_est_species %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, avcm3, svarcm3, stdcm3)

      size_est_maxdiam_strata_species <-  size_est_species %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, av_maxdiam, svar_maxdiam, std_maxdiam)

      # ntot check - should add up to 1
      ntot_check <- size_est_species %>%
        dplyr::group_by(YEAR, SPECIES_CD) %>%
        dplyr::summarize(wh_sum = sum(wh))

      ## Domain Estimates
      Domain_est_species <- size_est_species %>%
        dplyr::group_by(REGION, YEAR, SPECIES_CD, SPECIES_NAME) %>%
        dplyr::summarise(avCm2 = sum(whavcm2, na.rm = T), # This accounts for strata with 0 species of interest present
                         avCm3 = sum(whavcm3, na.rm = T),
                         avMaxdiam = sum(whav_maxdiam, na.rm = T),
                         Var_cm2 = sum(whsvarcm2, na.rm = T),
                         Var_cm3 = sum(whsvarcm3, na.rm = T),# This accounts for strata with N = 1
                         Var_maxdiam = sum(whsvar_maxdiam, na.rm = T),
                         SE_cm2=sqrt(Var_cm2),
                         SE_cm3=sqrt(Var_cm3),
                         SE_maxdiam=sqrt(Var_maxdiam),
                         n_sites = sum(n_sites),
                         n_strat = length(unique(ANALYSIS_STRATUM)),
                         ngrtot = sum(NTOT) )  %>%
        dplyr::ungroup()
    }

    if(project == "NCRMP_DRM"){

      size_est_species <- size_est %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT,  PROT, NTOT, ngrtot, wh, n_sites,
                      av_maxdiam, svar_maxdiam, std_maxdiam, whav_maxdiam, whsvar_maxdiam, whstd_maxdiam)

      size_est_maxdiam_strata_species <-  size_est_species %>%
        dplyr::select(REGION, YEAR, SPECIES_CD, SPECIES_NAME, ANALYSIS_STRATUM, STRAT, PROT, NTOT, ngrtot, wh, n_sites, av_maxdiam, svar_maxdiam, std_maxdiam)

      # ntot check - should add up to 1
      ntot_check <- size_est_species %>%
        dplyr::group_by(YEAR, SPECIES_CD) %>%
        dplyr::summarize(wh_sum = sum(wh))

      ## Domain Estimates
      Domain_est_species <- size_est_species %>%
        dplyr::group_by(REGION, YEAR, SPECIES_CD, SPECIES_NAME) %>%
        dplyr::summarise(avMaxdiam = sum(whav_maxdiam, na.rm = T),
                         Var_maxdiam = sum(whsvar_maxdiam, na.rm = T),
                         SE_maxdiam=sqrt(Var_maxdiam),
                         n_sites = sum(n_sites),
                         n_strat = length(unique(ANALYSIS_STRATUM)),
                         ngrtot = sum(NTOT) )  %>%
        dplyr::ungroup()
    }

    ####Export####
    if(project == "NCRMP"){
      output <- list(
        "size_est_cm2_strata_species" = size_est_cm2_strata_species,
        'size_est_cm3_strata_species' = size_est_cm3_strata_species,
        "size_est_maxdiam_strata_species" = size_est_maxdiam_strata_species,
        "Domain_est_species" = Domain_est_species,
        "ntot_check" = ntot_check)
    }
    if(project == "NCRMP_DRM"){
      output <- list(
        "size_est_maxdiam_strata_species" = size_est_maxdiam_strata_species,
        "Domain_est_species" = Domain_est_species,
        "ntot_check" = ntot_check)
    }
    return(output)
  }
}



