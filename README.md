# TiledRSoXS
A somewhat general IgorPro based browser for Tiled.  Built for RSoXS, but useful in general.  Please report any issues to egann@bnl.gov.

# Installation:  
1) Download or clone the TiledRSoXS.ipf file from this repository (https://github.com/NSLS-II-SST/TiledRSoXS).
2) Do the following in a command line terminal either locally or on a remote machine like the NSLS II JupyterHub.  These steps should only need to be done once, the first time TiledRSoXS is being set up in Igor on this particular computer.
   - Install Tiled[client]: ``pyrhon3 -m pip install "tiled[client]"``
   - Run: ``tiled profile create --name nsls https://tiled.nsls2.bnl.gov/``
   - Run: ``tiled login --profile nsls``
   - You will be prompted for your BNL login credentials and a Duo two-factor push, similar to logging into other BNL webpages.
   - Run: ``tiled api_key create``
   - An api_key will be generated that looks like ``4efed#####3945``
3) If not already done, install Igor.  Download the Igor json XOP (https://docs.byte-physics.de/json-xop/) and place it in Igor extensions (64 bit).  Open Igor 64-bit.
4) Each time Igor is started, go to File --> Open File --> Procedure.  Open the TiledRSoXS.ipf file that was downloaded in step 1.  If the file does not automatically compile, hit the Compile button on the TiledRSoXS.ipf window.  Then, go to RSoXS --> TiledRSoXS.
5) During the first time this is set up, you will be prompted for your api_key.  Paste the key that you got at the end of step 2.
6) Use the double arrow to move to the most recent data.  Scans can be filtered at the top using various keys such as sample_id, plan, etc. and their corresponding values, and then clicking Add.

# Accessing Tiled from web browser
If needed, Tiled can be accessed directly from a web browser at https://tiled.nsls2.bnl.gov/.
