set more off
clear all
cls 

// Use this code to download, build, and save to the local computer
// data from the Institutional Characteristics survey at the US DOE's
// Integrated Postsecondary Education Data Stystem.

// Initial build: 			Spring 2017
// GitHub rebuild:			September 2017
// Original Author:			Adam Ross Nelson

/*#########################################################################

      This do file will place in c:\statadata "InstChar 02 to 16.dta"

	  This do file is maintained by Adam Ross Nelson JD PhD at
	  https://github.com/adamrossnelson/StataIPEDSAll
	  
	  Note: Requires pre-established directory c:\statadata
	  
	  Questions or comments via GitHub or Twitter @adamrossnelson
	  
##########################################################################*/

window stopbox rusure "Have you created c:\statadata ?`=char(13)'" ///
"Do you want to continue?`=char(13)'`=char(13)'Yes=continue; No=stop here."
window stopbox note "Okay, will now proceed."

// Utilize existing directory structure
cd c:/statadata

capture log close											// Close stray logs.
log using "IPEDSInstChar `c(current_date)'.txt", replace	// Open new log.
local sp char(13) char(10) char(13) char(10)				// Define spacer.
version 13									// Enforce version compatibility.
capture mkdir workspace						// Make a directory to store zip files.
cd workspace								// Move into working directory.

// Loop designed to download zip files and NCES provided Stata do files.
// Stata do files need cleaning (remove stray char(13) + char(10) + char(34)).
// ADM series (Admissions and Test Scores) Introduced in 2014
forvalues fname = 2014/2015 {
		// Copy and unzip data and do files.
	copy https://nces.ed.gov/ipeds/datacenter/data/ADM`fname'_Data_Stata.zip .
	unzipfile ADM`fname'_Data_Stata.zip, replace
	copy https://nces.ed.gov/ipeds/datacenter/data/ADM`fname'_Stata.zip .
	unzipfile ADM`fname'_Stata.zip
	
		// The NCES provided do files have some lines that need to be removed
		// before we can call them from this master -do-file.
	scalar fcontents = fileread("adm`fname'.do")
	scalar fcontents = subinstr(fcontents, "insheet", "// insheet", 1)
	scalar fcontents = subinstr(fcontents, "save", "// save", .)
	
		// Save edited do file.
	scalar byteswritten = filewrite("adm`fname'.do", fcontents, 1)
	di `sp'								// Spacing to assist reading output.
}

// Prepare the Admissions and Test Scores 2014 file.
import delimited adm2014_rv_data_stata.csv, clear
di "QUIET RUN OF adm2014.do"	// Provide uers with information for log file.
qui do adm2014					// Quietly run NCES provided do file.
gen isYr = 2014					// Add the isYr index for later merge.
order isYr, after(unitid)		// Order isYr after unitid, easier browsing.
saveold adm2014_rv_data_stata.dta, version(13) replace
di `sp'							// Spacer for the output.

// Prepare the Admissions and Test Scores 2015 file.
import delimited adm2015_data_stata.csv, clear
di "QUIET RUN OF adm2015.do"	// Provide uers with information for log file.
qui do adm2015					// Quietly run NCES provided do file.
gen isYr = 2015 				// Add the isYr index for later merge.
order isYr, after(unitid)		// Order isYr after unitid, easier browsing.
saveold adm2015_data_stata.dta, version(13) replace
di `sp'							// Spacer for the output.

// Loop designed to downlaod zip files and NCES provided Stata do files.
// Stata do files need cleaning (remove stray char(13) + char(10) + char(34)).
forvalues fname = 2002 / 2016 {
		// Copy, unzip, and import data.
	copy https://nces.ed.gov/ipeds/datacenter/data/IC`fname'_Data_Stata.zip .
	unzipfile IC`fname'_Data_Stata.zip, replace
		// File name conventions not consistent through the years. 2002-2007 
		// and 2009 no _rv_ file. 2008 and 2010-2013 _rv_ file available.	
	if `fname' == 2008 | (`fname' > 2009 & `fname' < 2015) {
		import delimited ic`fname'_rv_Data_Stata.csv, clear
	}
	else {
		import delimited ic`fname'_Data_Stata.csv, clear
	}
		// Add isYr for later panel merge. Order new variable.
	
	gen int isYr = `fname'
	order isYr, after(unitid)

		// Download NCES provided do files.
	copy https://nces.ed.gov/ipeds/datacenter/data/IC`fname'_Stata.zip .
	unzipfile IC`fname'_Stata.zip
		// Read do file into scalar for modification.
		// Remove default "insheet" command designed to import data.
		// Remove default "save" command designed to save data.
	scalar fcontents = fileread("ic`fname'.do")
	scalar fcontents = subinstr(fcontents, "insheet", "// insheet", 1)
	scalar fcontents = subinstr(fcontents, "save", "// save", .)
		// These lines clear erroneous code form the 2003 do file.
	scalar fcontents = subinstr(fcontents, "label define label_chfnm", "*label define label_chfnm Alpha", .)
		// Remove unexpected carriage returns and line feeds.
	scalar sstring = char(13) + char(10) + char(13) + char(10) + char(34)
	scalar fcontents = subinstr(fcontents, sstring, char(34), .)
	scalar sstring = char(13) + char(10) + char(34)
	scalar fcontents = subinstr(fcontents, sstring, char(34), .)
		// Save (and call) the revised and working do file.
	scalar byteswritten = filewrite("ic`fname'.do", fcontents, 1)
	di "QUIET RUN OF ic`fname'"	// Provide information for log file.
	qui do ic`fname'			// Quietyly run NCES provided do file.
	di `sp'						// Spacing to assist reading output.

		// Compress and save the resulting do file.
	compress
	saveold ic`fname'_data_stata.dta, version(13) replace
	di `sp'							// Spacer for the output.
}

// Loop through dta files created above. Assemble panel data set. Starts with
// most recent dta file. Procedure assumes most recent dta value lables will
// be most valid and reliable for the intended research or analytical purpose.
di `sp'												// Spacer for the output.
use ic2016_data_stata.dta, clear					// Open most recent file as the
forvalues yindex = 2015(-1)2002 {					// base and then, assemble the
	append using ic`yindex'_data_stata.dta, force	// panel data set.
	di `sp'											// Spacer for the output.
}
merge 1:1 unitid isYr using "adm2014_rv_data_stata.dta", ///
nogenerate update force
merge 1:1 unitid isYr using "adm2015_data_stata.dta", ///
nogenerate update force

// Move up file directory level.
// Compress, save resulting panel data set.
cd ..
compress
saveold "InstChar 02 to 16.dta", replace version(13)

/*######################################################################

      Now located in c:\statadata is "InstChar 02 to 16.dta"

	  This do file is maintained by Adam Ross Nelson JD PhD at
	  https://github.com/adamrossnelson/StataIPEDSAll
	  
	  Questions or comments via GitHub or Twitter @adamrossnelson
	  
	  Note regarding history of IC and ADM survey files. ADM series
	  introduced in 2014. Some variables formerly found in the IC
	  series moved to ADM series. This routine builds ADM and IC 
	  sets apart. Then merges the 2014 and 2015 ADM surveys.

########################################################################*/