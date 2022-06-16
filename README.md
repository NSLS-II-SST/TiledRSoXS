# TiledRSoXS
A somewhat general IgorPro based browser for Tiled.  Built for RSoXS, but useful in general

todo:  
1.) ~~primary and monitor selection should be with a list box~~

2.) ~~baseline and metadata display...~~
  ~~graphs for baselines,~~  for now no graphs  ~~to see changes in some values?~~
  ~~listbox display of metadata... columns for different scans?~~
  
3.) ~~QANT import.  all the data is there, just need to copy it to the right folder for QANT to see it.~~

4.) NIKA integration??  not convinced it is needed, but perhaps mask / beam centering tools?

5.) live mode.
  disable paging buttons and search? always load the last n-10 scans, select the most recent scan (allow selection of others, but most recent is required)
  update the scan list every 2 seconds, monitors, primary and images every 5 seconds
  
6.) smart loading depending on which tab is selected... skip images if not in the images tab, skip monitors unless on primary or monitors tab

# Installation:  
For now, just load the procedure file, and a menu item will be added RSoXS->TiledRSoXS which will launch tiled RSoXS.  It is of limited use at the moment, because it requires 1.) an apikey - you are on your own generating that.  and 2.) tunneling into the tiled server (assuming you are using NSLS-II).  I will not be providing support for either of these necessary steps, unfortunately.  Soon it will be opened up such that both of these requirements will be easier.  For now, this can be used within the NSLS-II network and assuming you have finangled an apikey yourself, (or of course you have your own tiled server that you control)
