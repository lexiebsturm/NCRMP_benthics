
**For information on how to use this package, please visit:** https://mse-nccos-noaa.github.io/NCRMP_benthics/ 

# Introduction 

The ncrmp.benthic.analysis package is designed to use benthic data collected from the Atlantic regions of the National Coral Reef Monitoring Program (NCRMP) to complete the following:

1. Compute summary statistics such as coral density, percent cover, species richness, old and recent mortality, disease prevalence, diadema density, and presence/absence of ESA species from the site to the regional level. 

2. House all current NCRMP benthic data ranging from analysis ready data to regional domain estimates in a standardized format. This includes all metrics listed in item #1 calculated at the site, strata and regional level as well as most recent sampling grids and NTOT files. 

Citation: Groves, Mateski, Krampitz, Sturm, and Viehman, 2025. ncrmp.benthic.analysis (R package version 1.0.0.0002). [date accessed ]. https://github.com/MSE-NCCOS-NOAA/NCRMP_benthics

# Installation using devtools: 

1. Download the zipped R package using the green "Clone or download" button. Unzip the file to the location of your choice. If you do not unzip the file, the following steps will not work!

2. In R studio, open the ncrmp.benthics.analysis R project in the folder of the same name and use the following code to install the package. You must be in the ncrmp.benthics.analysis R project. If you aleady have devtools installed you can skip the first line. 

```
install.packages('devtools')

devtools::install()
```
3. Exit the ncrmp.benthics.analysis R project and check your R library to confirm the package installed. At this point you can either delete the files from the zipped folder or retain them if you are interested in the analysis code. 

4. From your current project, use the following code to load and use the package. 

```
library(ncrmp.benthics.analysis) 
```
5. To update the package (when new data is added), repeat steps 1-4. If you are having trouble, try deleting the old version first before intalling the new one. 

Note: Requires R version 3.4.1 or higher.

## Note: 

This package currently uses Atlantic benthic data only. See https://github.com/jeremiaheb/rvc#reef-visual-census-statistical-package-in-r for Atlantic fish R package.

Where indicated in file names by NCRMP_FRRP or NCRMP_DRM, NCRMP and Distrubrance Response Monitoring (DRM; formerly known as Florida Reef Resilience Program or FRRP) data from 2014 to present have been combined. We are in the process of changing the naming convention from FRRP to DRM but at present DRM and FRRP are used interchageably. Please be patient while we complete this transition. 

This package assumes some familiarity with NCRMP sampling methods and analysis ready (AR) data formats. NCEI and CoRIS archived AR data, data dictionaries and sampling protocols can be found on the NCRMP project page, https://coastalscience.noaa.gov/project/national-coral-reef-monitoring-program-biological-socioeconomic/ under "Products, Datasets and Reports". See also: https://www.coris.noaa.gov/monitoring/.

Use of this data requires citation, please see https://coastalscience.noaa.gov/project/national-coral-reef-monitoring-program-biological-socioeconomic/ for the correct citation for individual archive packages. 

For more information on the specific functions within the package, please see the vignette. 

For questions or collaborations, please contact the repository owner, Shay Viehman, shay.viehman@noaa.gov 



# Legal Disclaimer
This repository is a software product and is not official communication of the National Oceanic and Atmospheric Administration (NOAA), or the United States Department of Commerce (DOC). All NOAA GitHub project code is provided on an 'as is' basis and the user assumes responsibility for its use. Any claims against the DOC or DOC bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation, or favoring by the DOC. The DOC seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by the DOC or the United States Government.

# License 

Software code created by U.S. Government employees is not subject to copyright in the United States (17 U.S.C. §105). The United States/Department of Commerce reserve all rights to seek and obtain copyright protection in countries other than the United States for Software authored in its entirety by the Department of Commerce. To this end, the Department of Commerce hereby grants to Recipient a royalty-free, nonexclusive license to use, copy, and create derivative works of the Software outside of the United States.


# [Section 508](https://oceanservice.noaa.gov/accessibility-statement.html)

The National Ocean Service is committed to making its website accessible to the widest possible audience, including people with disabilities, in accordance with Section 508 of the Rehabilitation Act (29 U.S.C. 794d).

Section 508 is a federal law that requires agencies to provide individuals with disabilities equal access to electronic information and data comparable to those who do not have disabilities, unless an undue burden would be imposed on the agency.

The Section 508 standards are the technical requirements and criteria that are used to measure conformance within this law. More information on Section 508 and the technical standards can be found at Section508.gov.
