# CB-Digital-Grinnell

Home for all things related to Digital.Grinnell using CollectionBuilder.  This repo began as a clone and independent copy of `https://github.com/isu-digital/digitalcollections.lib`.    

## Resources from August 19, 2026, Discussion with Iowa State University

ISU is all-in on Azure!  

Their production site is:  `https://digitalcollections.lib.iastate.edu`. 

Their approach uses an Azure Blob for object storage and they have no true "preservation" store at this point.  They also use a `$web` blob container in the same Azure Storage Account to hold their collection code instead of creating multiple Azure Static Web Apps (brilliant!).  Each collection is an aptly named branch of this central repo, and each has a like-named body of code inside the `$web` blob container.  Code is simply copied into the appropriate `$web` folder for deployment.  They do not yet employ GitHub actions for deployment, but hope to in the near future.  

### AV Approach

ISU uses `Aviary` with embedded iframes in their site for AV content as well as oral histories.  That's how they got around the Azure sync'd transcript issue I have encountered in the past (and worked around by putting oral history audio/video into DigitalOcean).  

Idaho uses YouTube to do the same.  

### Search

ISU has a custom search data json generator, a Flask app, coupled with MongoDB and ElasticSearch for cross-collection search capabilities.  

This solution is due for overhaul under an IMLS grant early in 2027.  For now I'm committed to trying to make `PageFind` work for DG at Grinnell.  If that fails, the ISU solution using `ElasticSearch` will do.  

