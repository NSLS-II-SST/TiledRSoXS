#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <Resize Controls>
#include <Rewrite Control Positions>

function init_tiled_rsoxs()
	dfref foldersave = getdataFolderDFR()
	setdatafolder root:
	newdatafolder /o/s Packages
	newdatafolder /o/s RSoXS_Tiled
	get_apikey()
	string /g baseurl = "https://tiled.nsls2.bnl.gov/api/"
	string /g activeurl = "rsoxs"
	string /g output = ""
	string /g preurl = "node/search/"
	string /g posturl = "?fields=metadata&page%5Boffset%5D=0&page%5Blimit%5D=100&omit_links=true"
	variable /g offset = 0
	variable /g max_result
	variable /g num_page = 30
	variable /g search_type = 5
	string /g key_search = "sample_id"
	string /g value_search = "P3HT"
	string /g comparison_type_search = "<"
	string /g primary_color="BlueRedGreen"
	string /g monitor_color="BlueRedGreen"
	string /g primary_x_axis="time"
	
	
	string /g colortab = "Terrain"
	variable /g logimage = 1
	variable /g min_val = 100
	variable /g max_val = 100000
	variable /g xmin_pct = 0
	variable /g xmax_pct = 100
	variable /g ymin_pct = 0
	variable /g ymax_pct = 100
	variable /g primary_plot_indv_axes
	variable /g monitor_plot_indv_axes
	variable /g monitor_plot_subxoffset
	variable /g primary_plot_logy
	variable /g monitor_plot_logy
	variable /g primary_plot_logx
	//string /g monitor_list = ""
	//string /g primary_list = ""
	
	make /n=(0,6) /t /o Plans_list
	make /n=(0) /o plans_sel_wave
	make /n=6 /t/o plans_col_wave = {"scan_id","plan","sample","pnts","time","uid"}
	make /n=0 /t/o search_list, plotted_monitors, plotted_primary, image_list, primary_list_wave, monitor_list_wave, metadata_display, baseline_display
	make /n=(0,4) /t /o search_settings
	make /n=0 /o search_sel_list, image_sel_list, primary_sel_list, monitor_sel_list
	
	dowindow /k RSoXSTiled
	Execute "RSoXSTiled()"
	setdatafolder foldersave

end

function update_list()
	svar /z output = root:Packages:RSoXS_Tiled:output
	dfref FOLDERSAVE = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	string url = get_url_search()
	if(strlen(url)>5)
		//output = FetchURL(url)
		URLRequest /z/time=1 url=url, method=get
		if(v_flag)
			// try again - server seems to ocassionally hickup
			URLRequest /z/time=1 url=url, method=get
			if(v_flag)
				setdatafolder foldersave 
				return v_flag
				
			endif
		endif
		output = S_serverResponse
		JSONXOP_Parse output
		if(v_flag)
			return v_flag
		endif
		variable jsonId = V_value
		make /n=0 /o /T textwave
		JSONXOP_Getvalue /q/z/v jsonId, "meta/count"
		nvar /z max_result
		max_result = v_value
		nvar /z offset
		nvar /z num_page
		offset = max(offset,0)
		if(offset > max_result-num_page)
			offset = max(0,max_result-num_page)
			URLRequest /z/time=1 url=get_url_search(), method=get
			if(v_flag)
				// try again - server seems to ocassionally hickup
				URLRequest /z/time=1 url=get_url_search(), method=get
				if(v_flag)
					setdatafolder foldersave 
					return v_flag
				endif
			endif
			output = S_serverResponse
			JSONXOP_release jsonId
			JSONXOP_Parse output
			if(v_flag)
				setdatafolder foldersave 
				return v_flag
			endif
			jsonId = V_value
			make /n=0 /o /T textwave
			JSONXOP_Getvalue /q/z/v jsonId, "meta/count"
			max_result = v_value
		endif
			
		// how many points
		JSONXOP_GetArraySize /q/z jsonId, "/data"
		if(v_flag)
			JSONXOP_Release jsonID
			return 0
		endif
		variable result_num = v_value
		make /n=(result_num,6) /t /o Plans_list
		make /n=(result_num) /o plans_sel_wave, has_darks, done
		make /n=6 /t/o plans_col_wave = {"scan_id","plan","sample","pnts","time","uid"}
		make /o/t /n=(result_num) stream_names, metadata_string = "", metadata_display
		variable i,j, keytype, duration
		string tempstring, keystring, datastring
		for(i=result_num-1;i>=0;i-=1)
			// get the scan_id
			string prefix = "/data/"+num2str(i)+"/attributes/"
			JSONXOP_Getvalue /q/z/v jsonId, prefix + "metadata/start/scan_id"
			variable scan_id = v_value
			JSONXOP_Getvalue /q/z/t jsonId, prefix + "metadata/start/uid"
			string uid = s_value
			// get the stop status
			JSONXOP_Getvalue /q/z/t jsonId, prefix + "metadata/stop/exit_status"
			string stopstatus
			if(v_flag)
				stopstatus = "..."
				done[i]=0
			else
				stopstatus = ""
				done[i]=1
			endif
			// get the number of primary events
			JSONXOP_Getvalue /q/z/v jsonId, prefix + "metadata/start/num_points"
			variable count
			if(v_flag)
				count = nan
			else
				count = v_value
			endif
			// get the number of dark events
			JSONXOP_Getvalue /q/z/v jsonId, prefix + "metadata/stop/num_events/dark"
			if(v_flag)
				has_darks[i] = 1
			else
				has_darks[i] = v_value
			endif
			// get the number of duration
			JSONXOP_Getvalue /q/z/v jsonId, prefix + "metadata/summary/duration"
			if(v_flag)
				has_darks[i] = 1
			else
				has_darks[i] = v_value
			endif
			// get the plan name
			JSONXOP_Getvalue /q/z/t jsonId, prefix + "metadata/start/sample_name"
			string sample
			if(v_flag)
				sample = ""
			else
				sample = s_value
			endif
			JSONXOP_Getvalue /q/z/t jsonId, prefix + "metadata/start/plan_name"
			
			string plan_name
			if(v_flag)
				plan_name = ""
			else
				plan_name = s_value
			endif
			plans_list[i][0] = num2str(scan_id)
			plans_list[i][1] = plan_name
			plans_list[i][2] = sample
			plans_list[i][3] = num2str(count) + stopstatus
			plans_list[i][4] = num2str(duration)
			plans_list[i][5] = uid
			
			// get monitor names
			JSONXOP_GetValue /free /TWAV=tempstreams jsonId,prefix + "metadata/summary/stream_names"
			if(numpnts(tempstreams)>0)
				wfprintf tempstring, "%s;" tempstreams
				stream_names[i] = tempstring
			else
				stream_names[i]=""
			endif
			
					
			// get 0 level metadata as a key:value; liststring 
			JSoNXOP_GetKeys /free/q/z jsonID, prefix + "metadata/start", tempwave
			//wave /t tempwave
			for(j=0;j<numpnts(tempwave);j+=1)
				keystring =  tempwave[j]
				JSONXOP_GetType jsonID, prefix + "metadata/start/"+ keystring
				keytype = v_value
				SWITCH(keytype)
					case 0: //object - another dictionary.  ignore it for now
						break
					case 1: // array - tricky in case array is of weird kinds - ignore it for now
						break
					case 2: // Numeric - get the value, convert to string
						JSONXOP_Getvalue /v jsonID, prefix + "metadata/start/"+ keystring
						metadata_string[i] += keystring + ":" + num2str(v_value) + ";"
						break
					case 3: //string
						JSONXOP_Getvalue /t jsonID, prefix + "metadata/start/"+ keystring
						metadata_string[i] += keystring + ":" + s_value + ";"
						break
					case 4: // Boolean - get the value, convert to string
						JSONXOP_Getvalue /v jsonID, prefix + "metadata/start/"+ keystring
						metadata_string[i] += keystring + ":" + num2str(v_value) + ";"
						break
					default:
						break
				endswitch
			endfor
			
			// get primary url (we already have the info we need.		
			// something like this:
			// https://tiled.nsls2.bnl.gov/api/array/full/rsoxs/3fa0ed34-8a1b-41c4-9ba8-e62643a7267f/primary/data/data_vars/
			// (the rest looks like this:)Small Angle CCD Detector_stats1_total/variable?format=application/octet-stream
			// loading will require listing the contents of /data_vars/ and getting each (in parallel)
			
		endfor
		//make metadata_display which has the same number of columns as metadata_string, and the number of rows as the unique keys in metadata_string
		string uniquekeys="", key
		for(i=0;i<dimsize(metadata_string,0);i++)
			for(j=0;j<itemsinlist(metadata_string[i]);j++)
				key = stringfromlist(0,stringfromlist(j,metadata_string[i]),":")
				if(whichListItem(key,uniquekeys)<0)
					uniquekeys += key + ";"
				endif
			endfor
		endfor
		redimension /n=(itemsinlist(uniquekeys),dimsize(metadata_string,0)+1) metadata_display
		metadata_display[][1,] = stringbykey(stringfromlist(p,uniquekeys),metadata_string[q-1])
		metadata_display[][0] = stringfromlist(p,uniquekeys)
		
		setdatafolder foldersave 
		JSONXOP_Release jsonID
	endif

end


function /s get_url_search()

	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	svar /z preurl = root:Packages:RSoXS_Tiled:preurl
	svar /z posturl = root:Packages:RSoXS_Tiled:posturl
	nvar /z offset = root:Packages:RSoXS_Tiled:offset
	nvar /z num_page = root:Packages:RSoXS_Tiled:num_page
	nvar /z max_result = root:Packages:RSoXS_Tiled:max_result
	wave /t searchlist = root:Packages:RSoXS_Tiled:search_list
	offset = max(offset,0)
	
	posturl = "?fields=metadata"
	
	variable i
	for(i=0;i<numpnts(searchlist);i++)
		posturl += "&" + searchlist[i]
	endfor
	
	posturl += "&page%5Boffset%5D=" + num2str(offset) + "&page%5Blimit%5D="+num2str(num_page)+"&omit_links=true"
	
	if(svar_Exists(apikey) && svar_Exists(baseurl) && svar_Exists(activeurl) && svar_Exists(preurl) && svar_Exists(posturl))
		return baseurl + preurl + activeurl + posturl + apikey
	else
		return ""
	endif
end


Window RSoXSTiled() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(180,52,1876,903)
	ListBox list0,pos={5.00,266.00},size={386.00,573.00},proc=scanBoxProc
	ListBox list0,listWave=root:Packages:RSoXS_Tiled:Plans_list
	ListBox list0,selWave=root:Packages:RSoXS_Tiled:plans_sel_wave
	ListBox list0,titleWave=root:Packages:RSoXS_Tiled:plans_col_wave,mode=9
	ListBox list0,widths={10,20,40,10},userColumnResize=1
	SetVariable requested_results_val,pos={71.00,243.00},size={43.00,19.00},bodyWidth=43,proc=SetVarProc
	SetVariable requested_results_val,title=" "
	SetVariable requested_results_val,limits={-inf,inf,0},value=root:Packages:RSoXS_Tiled:offset
	Button get_URL1,pos={146.00,241.00},size={22.00,21.00},proc=page_toend
	Button get_URL1,title=">>"
	Button get_URL2,pos={119.00,241.00},size={22.00,21.00},proc=page_forward
	Button get_URL2,title=">"
	Button get_URL3,pos={12.00,241.00},size={22.00,21.00},proc=page_tobeginning
	Button get_URL3,title="<<"
	Button get_URL4,pos={42.00,241.00},size={22.00,21.00},proc=page_backward
	Button get_URL4,title="<"
	SetVariable requested_results_val1,pos={169.00,243.00},size={43.00,19.00},bodyWidth=43
	SetVariable requested_results_val1,title=" ",labelBack=(61423,61423,61423)
	SetVariable requested_results_val1,frame=0,valueColor=(21845,21845,21845)
	SetVariable requested_results_val1,limits={-inf,inf,0},value=root:Packages:RSoXS_Tiled:max_result,noedit=1
	Button Tiled_QANT_but,pos={1521.00,3.00},size={96.00,23.00},proc=Tiled_to_QANT
	Button Tiled_QANT_but,title="Import to QANT"
	TabControl View_Tab,pos={397.00,8.00},size={1292.00,835.00},proc=TabProc
	TabControl View_Tab,tabLabel(0)="Monitors",tabLabel(1)="Primary"
	TabControl View_Tab,tabLabel(2)="Images",tabLabel(3)="Baseline"
	TabControl View_Tab,tabLabel(4)="Metadata",value=1
	Button deselect_all_monitors,pos={416.00,382.00},size={80.00,21.00},disable=1,proc=deselect_monnitor_but_proc
	Button deselect_all_monitors,title="deselect all"
	Button Select_all_Monitors,pos={513.00,381.00},size={80.00,22.00},disable=1,proc=select_all_monitor_but_proc
	Button Select_all_Monitors,title="select all"
	SetVariable Catalog_select,pos={9.00,27.00},size={108.00,19.00},bodyWidth=60
	SetVariable Catalog_select,title="Catalog:"
	SetVariable Catalog_select,value=root:Packages:RSoXS_Tiled:activeurl
	SetVariable Server_select,pos={17.00,7.00},size={218.00,19.00},bodyWidth=179
	SetVariable Server_select,title="Server:"
	SetVariable Server_select,value=root:Packages:RSoXS_Tiled:baseurl
	ListBox Catalog_Searches,pos={27.00,130.00},size={287.00,102.00},proc=search_listbox_proc
	ListBox Catalog_Searches,listWave=root:Packages:RSoXS_Tiled:search_list
	ListBox Catalog_Searches,selWave=root:Packages:RSoXS_Tiled:search_sel_list
	ListBox Catalog_Searches,mode=9,widths={500},userColumnResize=1
	SetVariable Key_select,pos={37.00,80.00},size={266.00,19.00},bodyWidth=80,proc=change_search_string
	SetVariable Key_select,title="Key (sample_name, institution etc):"
	SetVariable Key_select,value=root:Packages:RSoXS_Tiled:key_search
	SetVariable Value_select1,pos={143.00,104.00},size={162.00,19.00},bodyWidth=127,proc=change_search_string
	SetVariable Value_select1,title="value:"
	SetVariable Value_select1,value=root:Packages:RSoXS_Tiled:value_search,live=1
	PopupMenu catalog_search,pos={28.00,59.00},size={170.00,17.00},proc=catalog_search_kind_proc
	PopupMenu catalog_search,title="kind of search"
	PopupMenu catalog_search,mode=5,popvalue="regular expression",value=#"\"Full Text;equals;contains;comparison;regular expression\""
	PopupMenu catalog_search_comparison,pos={29.00,105.00},size={96.00,19.00},disable=1,proc=Catalog_search_comparison_proc
	PopupMenu catalog_search_comparison,title="comparison"
	PopupMenu catalog_search_comparison,mode=1,popvalue="<",value=#"\"<;>;in\""
	Button Add_to_search,pos={323.00,83.00},size={46.00,36.00},proc=Add_search
	Button Add_to_search,title="Add"
	Button catalog_search_remove_but,pos={329.00,183.00},size={54.00,37.00},proc=remove_catalog_search_proc
	Button catalog_search_remove_but,title="Remove"
	Button remove_from_search1,pos={329.00,134.00},size={54.00,37.00},proc=remove_all_catalog_search_proc
	Button remove_from_search1,title="Remove\rAll"
	CheckBox auto_update_chk,pos={307.00,7.00},size={80.00,16.00}
	CheckBox auto_update_chk,title="Auto Update",value=0
	CheckBox log_image,pos={419.00,38.00},size={65.00,16.00},disable=1,proc=change_image_option_proc
	CheckBox log_image,title="log image",variable=root:Packages:RSoXS_Tiled:logimage
	PopupMenu color_tab_pop,pos={496.00,36.00},size={200.00,17.00},disable=1,proc=COlorTab_pop_proc
	PopupMenu color_tab_pop,mode=8,value=#"\"*COLORTABLEPOP*\""
	SetVariable min_setv,pos={712.00,34.00},size={85.00,19.00},bodyWidth=60,disable=1,proc=set_image_val_pop
	SetVariable min_setv,title="min"
	SetVariable min_setv,limits={1,500000,1},value=root:Packages:RSoXS_Tiled:min_val
	SetVariable max_setv,pos={801.00,34.00},size={87.00,19.00},bodyWidth=60,disable=1,proc=set_image_val_pop
	SetVariable max_setv,title="max"
	SetVariable max_setv,limits={3,1e+06,1},value=root:Packages:RSoXS_Tiled:max_val
	ListBox Image_sel_lb,pos={417.00,80.00},size={94.00,743.00},disable=1,proc=Primary_sel_listbox_proc
	ListBox Image_sel_lb,listWave=root:Packages:RSoXS_Tiled:image_list
	ListBox Image_sel_lb,selWave=root:Packages:RSoXS_Tiled:image_sel_list,mode=9
	ListBox Image_sel_lb,widths={500},userColumnResize=1
	PopupMenu primary_color_tab_pop,pos={1226.00,37.00},size={200.00,17.00},disable=1,proc=Primary_color_pop_Proc
	PopupMenu primary_color_tab_pop,mode=10,value=#"\"*COLORTABLEPOP*\""
	PopupMenu monitor_color_tab_pop,pos={1132.00,40.00},size={200.00,17.00},disable=1,proc=monitor_color_pop_proc
	PopupMenu monitor_color_tab_pop,mode=13,value=#"\"*COLORTABLEPOP*\""
	SetVariable num_requested_results_val,pos={265.00,244.00},size={118.00,19.00},bodyWidth=43,proc=SetVarProc
	SetVariable num_requested_results_val,title="results / page"
	SetVariable num_requested_results_val,limits={1,100,1},value=root:Packages:RSoXS_Tiled:num_page
	Button update_apikey,pos={132.00,29.00},size={96.00,16.00},proc=update_api_but
	Button update_apikey,title="update_apikey"
	ListBox Monitor_listb,pos={411.00,86.00},size={196.00,289.00},disable=1,proc=monitor_sel_channel_proc
	ListBox Monitor_listb,listWave=root:Packages:RSoXS_Tiled:monitor_list_wave
	ListBox Monitor_listb,selWave=root:Packages:RSoXS_Tiled:monitor_sel_list,mode=9
	Button Select_all_Primary,pos={513.00,381.00},size={80.00,22.00},proc=select_all_primary_but_proc
	Button Select_all_Primary,title="select all"
	ListBox Primary_listb,pos={411.00,86.00},size={196.00,289.00},proc=Primary_sel_channel_proc
	ListBox Primary_listb,listWave=root:Packages:RSoXS_Tiled:primary_list_wave
	ListBox Primary_listb,selWave=root:Packages:RSoXS_Tiled:primary_sel_list,mode=9
	Button deselect_all_primary,pos={416.00,382.00},size={80.00,21.00},proc=deselect_primary_but_proc
	Button deselect_all_primary,title="deselect all"
	PopupMenu X_Axis_channel_pop,pos={416.00,47.00},size={116.00,17.00},proc=Primary_Xaxis_sel_proc
	PopupMenu X_Axis_channel_pop,title="X-Axis"
	PopupMenu X_Axis_channel_pop,mode=5,popvalue="en_monoen_cff",value=#"get_primary_channels()"
	CheckBox individual_y_axis_m_chk,pos={420.00,430.00},size={98.00,16.00},disable=1,proc=Change_monitor_plot_chk
	CheckBox individual_y_axis_m_chk,title="individual y axes"
	CheckBox individual_y_axis_m_chk,variable=root:Packages:RSoXS_Tiled:monitor_plot_indv_axes
	CheckBox log_y_axis_m_chk,pos={420.00,460.00},size={64.00,16.00},disable=1,proc=Change_monitor_plot_chk
	CheckBox log_y_axis_m_chk,title="log y axes"
	CheckBox log_y_axis_m_chk,variable=root:Packages:RSoXS_Tiled:monitor_plot_logy
	CheckBox relative_x_m_axis,pos={420.00,490.00},size={115.00,16.00},disable=1,proc=Change_monitor_plot_chk
	CheckBox relative_x_m_axis,title="subtract time offset"
	CheckBox relative_x_m_axis,variable=root:Packages:RSoXS_Tiled:monitor_plot_subxoffset
	CheckBox individual_y_p_axis_chk,pos={420.00,430.00},size={98.00,16.00},proc=change_primary_plot_chk
	CheckBox individual_y_p_axis_chk,title="individual y axes"
	CheckBox individual_y_p_axis_chk,variable=root:Packages:RSoXS_Tiled:primary_plot_indv_axes
	CheckBox log_y_axis_p_chk,pos={420.00,460.00},size={64.00,16.00},proc=change_primary_plot_chk
	CheckBox log_y_axis_p_chk,title="log y axes"
	CheckBox log_y_axis_p_chk,variable=root:Packages:RSoXS_Tiled:primary_plot_logy
	CheckBox log_x_axis_p_chk,pos={420.00,490.00},size={61.00,16.00},proc=change_primary_plot_chk
	CheckBox log_x_axis_p_chk,title="log x axis"
	CheckBox log_x_axis_p_chk,variable=root:Packages:RSoXS_Tiled:primary_plot_logx
	ListBox Metadata_listb pos={405,42},size={1260,790},widths={150,100},listWave=root:Packages:RSoXS_Tiled:metadata_display,mode=2,disable=1,userColumnResize=1
	ListBox baseline_listb pos={405,42},size={1260,790},widths={200,100},listWave=root:Packages:RSoXS_Tiled:baseline_display,mode=2,disable=1,userColumnResize=1
	Display/W=(617,68,1680,833)/HOST=# /HIDE=1 
	RenameWindow #,Monitors
	SetActiveSubwindow ##
	Display/W=(617,68,1680,833)/HOST=# 
	RenameWindow #,Primary
	SetActiveSubwindow ##
	Display/W=(526,68,1678,833)/HOST=# /HIDE=1 
	RenameWindow #,Images
	SetActiveSubwindow ##
EndMacro





Function SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	sva.blockReentry = 1

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			update_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function page_forward(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	ba.blockReentry = 1

	switch( ba.eventCode )
		case 2: // mouse up
			nvar /z max_result = root:Packages:RSoXS_Tiled:max_result
			nvar /z offset = root:Packages:RSoXS_Tiled:offset
			nvar /z num_page = root:Packages:RSoXS_Tiled:num_page
			//if(offset < max_result - 30)
				offset = offset+num_page
				update_list()
			//endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function page_backward(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	ba.blockReentry = 1

	switch( ba.eventCode )
		case 2: // mouse up
			nvar /z max_result = root:Packages:RSoXS_Tiled:max_result
			nvar /z offset = root:Packages:RSoXS_Tiled:offset
			nvar /z num_page = root:Packages:RSoXS_Tiled:num_page
			if(offset > 0)
				offset = max(offset-num_page,0)
				update_list()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function page_toend(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	ba.blockReentry = 1

	switch( ba.eventCode )
		case 2: // mouse up
			nvar /z max_result = root:Packages:RSoXS_Tiled:max_result
			nvar /z offset = root:Packages:RSoXS_Tiled:offset
			nvar /z num_page = root:Packages:RSoXS_Tiled:num_page
			offset = max_result-max(num_page-10,1)
			update_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function page_tobeginning(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	ba.blockReentry = 1

	switch( ba.eventCode )
		case 2: // mouse up
			nvar /z offset = root:Packages:RSoXS_Tiled:offset
			offset = 0
			update_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


function /s get_monitors([monitorlist,plot])
	string monitorlist
	variable plot
	variable nolist = 0
	
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	svar /z output = root:Packages:RSoXS_Tiled:output
	
	if(paramisdefault( monitorlist ))
		nolist = 1
		monitorlist = ""
	endif
	
	plot = paramisdefault(plot)? 0 : plot
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	string /g list_of_monitor_waves = ""
	
	wave/z/t monitor_metadata_urls
	wave/z/t monitor_metadata, monitor_list_wave, primary_list_wave
	wave/z monitor_sel_list, primary_sel_list
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j,k=0
	make /wave /n=0 /o monitorwaves
	make /free/df/n=(dimsize(plans_sel_wave,0)) monitor_folders
	string uid, testname
	string list_of_urls = ""
	string streambase, stream_url, time_url, safe_stream_base
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uid = plans_list[i][5]
			setdatafolder homedf
			newdatafolder /o/s $cleanupname(uid,0)
			monitor_folders[k] = getdataFolderDFR()
			newdatafolder /o/s monitors 
			k+=1
			for(j=0;j<itemsinlist(stream_names[i]);j++)
				// see if there is already a loaded wave, and if so, load only from there on
				// actually there is no difference in loading the whole monitor in most cases, so I will not implement partial downloads.
				
				
				testname = stringfromlist(j,stream_names[i])
				if(stringmatch(testname,"*_monitor") && (whichListItem(testname,monitorlist)>-1 || nolist))
					streambase = removeEnding(testname,"_monitor")
					safe_stream_base = URLENCODE(streambase)
					stream_url = baseurl+"array/full/"+activeurl+ "/"
					stream_url += uid+"/"+safe_stream_base+"_monitor/data/data_vars/"
					stream_url += safe_stream_base+"/variable/?format=application/octet-stream" + apikey
					
					time_url = baseurl+"array/full/"+activeurl+ "/"
					time_url += uid+"/"+safe_stream_base+"_monitor/timestamps/data_vars/"
					time_url += safe_stream_base+"/variable/?format=application/octet-stream" + apikey
					list_of_urls += uid + ","+ streambase + "," + stream_url + ";"+ uid +","+ streambase +","+ time_url + ";"
				endif
				
			endfor
			
		endif
	endfor
	if(k==0||itemsinlist(list_of_urls,";")==0)
		return ""
	endif
	redimension /n=(k) monitor_folders
	make /o/n=(itemsinlist(list_of_urls,";")) /t uids, urls, list_of_files, streambases, stream_data
	uids = stringfromlist(0,stringfromlist(p,list_of_urls,";"),",")
	streambases = stringfromlist(1,stringfromlist(p,list_of_urls,";"),",")
	urls = stringfromlist(2,stringfromlist(p,list_of_urls,";"),",")
	
	

	
	if(waveexists(monitor_metadata_urls) && waveexists(monitor_metadata))
		if(!cmpstr(monitor_metadata_urls[0],urls[0]) &&numpnts(monitor_metadata) == numpnts(urls))
			stream_data = monitor_metadata //open the cached monitor metadata string which was already pulled
		else
			multithread /NT=(numpnts(list_of_files)) stream_data = fetch_string(urls[p],1)
		endif
	else
		multithread /NT=(numpnts(list_of_files)) stream_data = fetch_string(urls[p],1)
	endif
	
	variable len1, len2
	for(i=0;i<numpnts(uids);i+=2) 
		len1 = strlen(stream_data[i])
		len2 = strlen(stream_data[i+1])
		if(len1==len2 && len1>1 )
			setdatafolder homedf
			newdatafolder /o/s $cleanupname(uids[i],0)
			string /g monitor_waves = ""
		endif
	endfor
	string monitor_names ="", rawstring, rawstring2
	for(i=0;i<numpnts(uids);i+=2) 
		len1 = strlen(stream_data[i])
		len2 = strlen(stream_data[i+1])
		if(len1==len2 && len1>1 )
			setdatafolder homedf
			newdatafolder /o/s $cleanupname(uids[i],0)
			svar monitor_waves
			newdatafolder /o/s monitors
			streambase = streambases[i]
			rawstring = stream_data[i]
			rawstring2 = stream_data[i+1]
			wave stream_wave = StringToUnsignedByteWave(rawstring)
			wave time_wave = StringToUnsignedByteWave(rawstring2)
			redimension /E=1 /Y=4 /n=(len1/8) stream_wave, time_wave
			concatenate /o {stream_wave,time_wave}, $cleanupName(streambase,0)
			wave stream = $cleanupName(streambase,0)
			list_of_monitor_waves+= getwavesDataFolder(stream,2)+";"
			monitor_waves += getwavesDataFolder(stream,2)+";"
			monitor_names += nameofwave(stream) +"="+ getwavesdataFolder(stream,2)+";"
		endif
	endfor
	setdatafolder homedf
	string /g all_monitor_names_for_sel = monitor_names
	
	
	svar all_primary_names_for_sel
	wave /t wave_names_from_primary_list
	string key,value, organized_list=""
	variable index
	make /t/n=0/o wave_names_from_monitor_list // a list of the waves which correspond to the values in the organized list of primary channels
	for(i=0;i<itemsinlist(all_monitor_names_for_sel);i++)
		key = stringfromlist(0,stringfromlist(i,all_monitor_names_for_sel),"=")
		value = stringfromlist(1,stringfromlist(i,all_monitor_names_for_sel),"=")
		index = whichlistitem(key,organized_list)
		if(index<0)
			organized_list+=key+";"
			insertpoints numpnts(wave_names_from_monitor_list),1,wave_names_from_monitor_list
			wave_names_from_monitor_list[numpnts(wave_names_from_monitor_list)-1] = value+";"
		else
			wave_names_from_monitor_list[index] += value+";"
		endif
	endfor
	all_monitor_names_for_sel = organized_list
	redimension /n=(itemsinlist(organized_list)) monitor_list_wave, monitor_sel_list
	monitor_list_wave = stringfromlist(p,organized_list)
	//get the primary time wave, then go through the monitors
	for(i=0;i<numpnts(monitor_folders);i++)
		setdatafolder monitor_folders[i]
		wave times = time0 // the primary time wave (if this changes, it will fail)
		if(!waveexists(times))
			continue
		endif
		duplicate /free times, goodpulse, rises, falls
		goodpulse = 0
		svar monitor_waves
		
		for(j=0;j<itemsinlist(monitor_waves);j+=1)
			wave mon_wave = $stringfromlist(j,monitor_waves)
			wave newchannelwave = splitsignal(mon_wave, times, rises, falls, goodpulse) // make a primary like wave out of the monitor
			if(waveexists(newchannelwave))
				// add the new channel wave to the primary list of waves..
				key = nameofwave(newchannelwave)
				value = getwavesdatafolder(newchannelwave,2)
				index = whichlistitem(key,all_primary_names_for_sel)
				if(index<0) 
					all_primary_names_for_sel+=key+";"
					insertpoints numpnts(wave_names_from_primary_list),1,wave_names_from_primary_list
					wave_names_from_primary_list[numpnts(wave_names_from_primary_list)-1] = value+";"
				else
					wave_names_from_primary_list[index] += value+";"
				endif
			endif
		endfor
	endfor
	redimension /n=(itemsinlist(all_primary_names_for_sel)) primary_list_wave, primary_sel_list
	primary_list_wave = stringfromlist(p,all_primary_names_for_sel)
	setdatafolder foldersave
	return list_of_monitor_waves
end



function /s get_primary()
	
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	string /g primary_wave_names = ""
	string /g all_primary_names_for_sel = ""
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	make /wave /n=0 /o primary_waves
	wave /t primary_list_wave
	wave primary_sel_list
	string uid,uids="", testname, output
	string list_of_urls = ""
	string streambase, stream_url, time_url
	string list_of_sample_names = ""
	string list_of_scan_ids = ""
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
			list_of_sample_names += plans_list[i][2]+";"
			list_of_scan_ids += plans_list[i][0]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId

	string dataurls = "", streamurls = ""
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		stream_url = baseurl+"node/search/"+activeurl+ "/"
		stream_url += uid+"/primary?field=metadata" + apikey
		streamurls += stream_url + ";"
	endfor
	
	make /n=(itemsinlist(streamurls)) /t/o/free streamurl_wave = stringfromlist(p,streamurls), outputs
	
	
	wave/z/t primary_metadata_urls
	wave/z/t primary_metadata
	
	if(waveexists(primary_metadata_urls) && waveexists(primary_metadata))
		if(!cmpstr(primary_metadata_urls[0],streamurl_wave[0]) &&numpnts(primary_metadata) == numpnts(streamurl_wave))
			outputs = primary_metadata //open the cached primary metadata string which was already pulled
		else
			multithread outputs = fetch_string(streamurl_wave[p],1)
		endif
	else
		multithread outputs = fetch_string(streamurl_wave[p],1)
	endif
	
	
	
	
	
	
	//multithread outputs = fetch_string(streamurl_wave[p],1) // get the metadata, so we know what columns to grab
	
	for(i=0;i<itemsinlist(uids);i++)
		output = outputs[i]
		uid = stringfromlist(i,uids)
		if(strlen(output)<3)
			print "couldn't get metadata"
			continue
		endif
		JSONXOP_Parse/q/z output
		if(v_flag)
			print "bad responce to metadata"
			continue
		endif
		jsonId = V_value
		fieldsstring = ""
		JSoNXOP_GetKeys /free/q/z jsonID, "data/0/attributes/metadata/descriptors/0/data_keys", tempwave
		for(j=0;j<dimsize(tempwave,0);j++)
			if(stringmatch(tempwave[j],"*_image"))
				continue
			endif
			if(strlen(fieldsstring)<1)
				fieldsstring += "?"
			else
				fieldsstring += "&"
			endif
			fieldsstring += "field="+URLEncode(tempwave[j])
		endfor
		dataurls += baseurl+"node/full/" + activeurl + "/" + uid + "/primary/data"+fieldsstring+"&format=text/csv" + apikey + ";"
		JSONXOP_release jsonID
	endfor
	make /n=(itemsinlist(dataurls)) /t /free /o dataurl_wave = stringfromlist(p,dataurls), outputs
		
	multithread outputs = fetch_string(dataurl_wave[p],1) // get the metadata, so we know what columns to grab
	string sample_name,longimagenames=""
	variable unique_sample, enloc, samxloc, samyloc
	for(i=0;i<itemsinlist(uids);i++)
		output = outputs[i]
		uid = stringfromlist(i,uids)
		variable num = itemsinlist(output,"\n")-1 // subtract the line for headers
		if(num<1)
			continue
		endif
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		string /g primary_names = ""
		string /g image_names = ""
		string columns = stringfromlist(0,output,"\n")
		string dataname
		sample_name = stringfromlist(i,list_of_sample_names)
		unique_sample = whichlistitem(sample_name,list_of_sample_names) == i // true if this is the first element with sample_name
		unique_sample *= whichlistitem(sample_name,list_of_sample_names,";",i+1) == -1 // true if this is the last element with sample_name
		
		if(unique_sample && itemsinlist(uids)>1)
			sample_name = " - " + stringfromlist(i,list_of_sample_names)+" - " // multiple unique samples, start with the sample name
		elseif(itemsinlist(uids)>1)
			sample_name = " - " + stringfromlist(i,list_of_scan_ids)  // multiple non-uniqud samples, use the scan_id
		else
			sample_name = "" // only one sample, so don't use any name
		endif
		
		enloc = whichlistItem("en_energy_setpoint",columns,",")
		samxloc = whichlistItem("RSoXS_Sample_Outboard_Inboard",columns,",")
		samyloc = whichlistItem("RSoXS_Sample_Up_Down",columns,",")
		string rowstr
		for(j=1;j<itemsinlist(output,"\n");j+=1)
			rowstr = stringfromlist(j,output,"\n")
			if(samxloc>-1 && samyloc>-1)
				image_names +=  "(" +num2str(str2num(stringfromlist(samxloc,rowstr,","))) + "," + num2str(str2num(stringfromlist(samyloc,rowstr,","))) + ")"+sample_name +";"
			elseif(enloc>-1)
				image_names += num2str(str2num(stringfromlist(enloc,rowstr,","))) + "eV"+sample_name +";"
			else
				image_names += num2str(j) +sample_name +";"
			endif
		endfor
		if(itemsinlist(image_names)>itemsinlist(longimagenames))
			longimagenames = image_names
		endif
		for(j=0;j<itemsinlist(stringfromlist(0,output,"\n"),",");j++)
			dataname = CreateDataObjectName(:,stringfromlist(j,stringfromlist(0,output,"\n"),","),1,0,1+2+4)
			if(numtype(str2num(stringfromlist(j,stringfromlist(1,output,"\n"),",")))==2) // text data
				make /n=(num) /o /t $dataname
				wave /t primarywave = $dataname
				primarywave = stringfromlist(j,stringfromlist(p+1,output,"\n"),",")
				primary_wave_names += getwavesdataFolder(primarywave,2)+";"
				primary_names += getwavesdataFolder(primarywave,2)+";"
			else // numeric data
				make /n=(num)/d /o $dataname
				wave primarywaven = $dataname
				primarywaven = str2num(stringfromlist(j,stringfromlist(p+1,output,"\n"),","))
				primary_wave_names += getwavesdataFolder(primarywaven,2)+";"
				primary_names += removeending(dataname,"0") +"="+ getwavesdataFolder(primarywaven,2)+";"
			endif
		endfor
		all_primary_names_for_sel += primary_names
	endfor
	setdatafolder homedf
	make /o /n=(itemsinlist(longimagenames)) /t image_list = num2str(p)+" - ("+ stringfromlist(p,longimagenames) + ")"
	make /o /n=(itemsinlist(longimagenames)) image_sel_list
	string key,value, organized_list=""
	variable index
	make /t/n=0/o wave_names_from_primary_list // a list of the waves which correspond to the values in the organized list of primary channels
	for(i=0;i<itemsinlist(all_primary_names_for_sel);i++)
		key = stringfromlist(0,stringfromlist(i,all_primary_names_for_sel),"=")
		value = stringfromlist(1,stringfromlist(i,all_primary_names_for_sel),"=")
		index = whichlistitem(key,organized_list)
		if(index<0)
			organized_list+=key+";"
			insertpoints numpnts(wave_names_from_primary_list),1,wave_names_from_primary_list
			wave_names_from_primary_list[numpnts(wave_names_from_primary_list)-1] = value+";"
		else
			wave_names_from_primary_list[index] += value+";"
		endif
	endfor
	all_primary_names_for_sel = organized_list
	redimension /n=(itemsinlist(organized_list)) primary_list_wave, primary_sel_list
	primary_list_wave = stringfromlist(p,organized_list)
	setdatafolder foldersave
	return primary_wave_names
end

function /s get_darks()
	
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	string uid,uids="", testname, output
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId
	string dark_wave_names = ""
	string dataurls = "", streamurls = ""
	if(itemsinlist(uids)==0)
		return ""
	endif
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		stream_url = baseurl+"node/search/"+activeurl+ "/"
		stream_url += uid+"/dark?field=metadata" + apikey
		streamurls += stream_url + ";"
	endfor
	
	make /n=(itemsinlist(streamurls)) /t/o/free streamurl_wave = stringfromlist(p,streamurls), outputs
	
	
	wave/z/t dark_metadata_urls
	wave/z/t dark_metadata
	
	
	if(waveexists(dark_metadata_urls) && waveexists(dark_metadata))
		if(!cmpstr(dark_metadata_urls[0],streamurl_wave[0]) &&numpnts(dark_metadata) == numpnts(streamurl_wave))
			outputs = dark_metadata //open the cached primary metadata string which was already pulled
		else
			multithread outputs = fetch_string(streamurl_wave[p],1)
		endif
	else
		multithread outputs = fetch_string(streamurl_wave[p],1)
	endif
	
	
	
	
	//multithread outputs = fetch_string(streamurl_wave[p],1) // get the metadata, so we know what columns to grab
	
	for(i=0;i<itemsinlist(uids);i++)
		output = outputs[i]
		uid = stringfromlist(i,uids)
		if(strlen(output)<3)
			print "couldn't get metadata"
			continue
		endif
		JSONXOP_Parse/q/z output
		if(v_flag)
			print "bad responce to metadata"
			continue
		endif
		jsonId = V_value
		fieldsstring = ""
		JSoNXOP_GetKeys /free/q/z jsonID, "data/0/attributes/metadata/descriptors/0/data_keys", tempwave
		for(j=0;j<dimsize(tempwave,0);j++)
			if(stringmatch(tempwave[j],"*_image"))
				continue
			endif
			if(strlen(fieldsstring)<1)
				fieldsstring += "?"
			else
				fieldsstring += "&"
			endif
			fieldsstring += "field="+URLEncode(tempwave[j])
		endfor
		dataurls += baseurl+"node/full/" + activeurl + "/" + uid + "/dark/data"+fieldsstring+"&format=text/csv" + apikey + ";"
		JSONXOP_release jsonID
	endfor
	make /n=(itemsinlist(dataurls)) /t /free /o dataurl_wave = stringfromlist(p,dataurls), outputs
		
	multithread outputs = fetch_string(dataurl_wave[p],1) // get the metadata, so we know what columns to grab
	
	for(i=0;i<itemsinlist(uids);i++)
		output = outputs[i]
		uid = stringfromlist(i,uids)
		variable num = itemsinlist(output,"\n")-1 // subtract the line for headers
		if(num<1)
			continue
		endif
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		newdatafolder /o/s darks
		string dataname
		for(j=0;j<itemsinlist(stringfromlist(0,output,"\n"),",");j++)
			dataname = CreateDataObjectName(:,stringfromlist(j,stringfromlist(0,output,"\n"),","),1,j,1+2+4)
			if(numtype(str2num(stringfromlist(j,stringfromlist(1,output,"\n"),",")))==2)
				make /n=(num) /o /t $dataname
				wave /t primarywave = $dataname
				primarywave = stringfromlist(j,stringfromlist(p+1,output,"\n"),",")
				dark_wave_names += getwavesdataFolder(primarywave,2)
			else
				make /n=(num)/d /o $dataname
				wave primarywaven = $dataname
				primarywaven = str2num(stringfromlist(j,stringfromlist(p+1,output,"\n"),","))
				dark_wave_names += getwavesdataFolder(primarywaven,2)
			endif
		endfor

	endfor
	
	setdatafolder foldersave
	return dark_wave_names
end

function /wave get_baseline_metadataurls()
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	make /wave /n=0 /o baseline_waves
	string uid,uids="", testname, output
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId
	string primary_wave_names = ""
	string dataurls = "", streamurls = ""
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		dataurls += baseurl+"node/full/" + activeurl + "/" + uid + "/baseline/data?format=text/csv" + apikey + ";"
	endfor
	make /n=(itemsinlist(dataurls)) /t /free /o dataurl_wave = stringfromlist(p,dataurls), outputs
	setdatafolder foldersave
	return dataurl_wave
end

function /wave get_primary_metadataurls()
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	make /wave /n=0 /o primary_waves
	string uid,uids="", testname, output
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId
	string primary_wave_names = ""
	string dataurls = "", streamurls = ""
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		stream_url = baseurl+"node/search/"+activeurl+ "/"
		stream_url += uid+"/primary?field=metadata" + apikey
		streamurls += stream_url + ";"
	endfor
	
	make /n=(itemsinlist(streamurls)) /t/o/free streamurl_wave = stringfromlist(p,streamurls), outputs
	setdatafolder foldersave
	return streamurl_wave
end

function /wave get_monitor_metadataurls()
	
	
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	svar /z output = root:Packages:RSoXS_Tiled:output

	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	svar /z monitorlist
	string monitorlist_local = ";;"
	variable nolist = 1
	if(svar_exists(monitorlist))
		if(strlen(monitorlist)>2)
			monitorlist_local = monitorlist
			nolist=0
		endif
	endif
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	make /wave /n=0 /o monitorwaves
	string uid, testname
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uid = plans_list[i][5]
			setdatafolder homedf
			newdatafolder /o/s $cleanupname(uid,0)
			for(j=0;j<itemsinlist(stream_names[i]);j++)
				testname = stringfromlist(j,stream_names[i])
				if(stringmatch(testname,"*_monitor") && (whichListItem(testname,monitorlist_local)>-1 || nolist))
					streambase = removeEnding(testname,"_monitor")
	
					stream_url = baseurl+"array/full/"+activeurl+ "/"
					stream_url += uid+"/"+streambase+"_monitor/data/data_vars/"
					stream_url += streambase+"/variable/?format=application/octet-stream" + apikey
					
					time_url = baseurl+"array/full/"+activeurl+ "/"
					time_url += uid+"/"+streambase+"_monitor/timestamps/data_vars/"
					time_url += streambase+"/variable/?format=application/octet-stream" + apikey
					list_of_urls += uid + ","+ streambase + "," + stream_url + ";"+ uid +","+ streambase +","+ time_url + ";"
				endif
			endfor
			
		endif
	endfor
	
	if(itemsinlist(list_of_urls)==0)
		make /o/n=0 /t streamurl_wave
		return streamurl_wave
	endif
	make /o/n=(itemsinlist(list_of_urls,";")) /t uids, urls, list_of_files, streambases, stream_data
	uids = stringfromlist(0,stringfromlist(p,list_of_urls,";"),",")
	streambases = stringfromlist(1,stringfromlist(p,list_of_urls,";"),",")
	urls = stringfromlist(2,stringfromlist(p,list_of_urls,";"),",")
	setdatafolder foldersave
	return urls
end


function /wave get_dark_metadataurls()
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j
	string uid,uids="", testname, output
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId
	string dark_wave_names = ""
	string dataurls = "", streamurls = ""
	if(itemsinlist(uids)==0)
		make /o/n=0 /t streamurl_wave
		return streamurl_wave
	endif
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		stream_url = baseurl+"node/search/"+activeurl+ "/"
		stream_url += uid+"/dark?field=metadata" + apikey
		streamurls += stream_url + ";"
	endfor
	
	make /n=(itemsinlist(streamurls)) /t/o/free streamurl_wave = stringfromlist(p,streamurls), outputs
	setdatafolder foldersave
	return streamurl_wave
	
end


function get_all_metadata()
	// get all the metadata calls together at once
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	
	// baseline
	wave /t baseline_urls_wave = get_baseline_metadataurls()
	duplicate /o baseline_urls_wave, baseline_metadata_urls
	variable b_pts = numpnts(baseline_metadata_urls)
	make /o/n=(b_pts) /t baseline_metadata
	
	
	/// monitors
	wave /t monitor_urls_wave = get_monitor_metadataurls()
	duplicate /o monitor_urls_wave, monitor_metadata_urls
	variable m_pts = numpnts(monitor_metadata_urls)
	make /o/n=(m_pts) /t monitor_metadata
	
	
	/// darks
	wave /t dark_urls_wave = get_dark_metadataurls()
	duplicate /o dark_urls_wave, dark_metadata_urls
	variable d_pts = numpnts(dark_metadata_urls)
	make /o/n=(d_pts) /t dark_metadata
	
	
	
	/// primary
	wave /t primary_urls_wave = get_primary_metadataurls()
	duplicate /o primary_urls_wave, primary_metadata_urls
	variable p_pts = numpnts(primary_metadata_urls)
	make /o/n=(p_pts) /t primary_metadata
	
	
	concatenate /t/free/NP {baseline_metadata_urls, monitor_metadata_urls, dark_metadata_urls, primary_metadata_urls}, all_urls
	make /n=(numpnts(all_urls)) /t /free server_responses
	multithread /nt=(numpnts(all_urls)) server_responses = fetch_string(all_urls[p],1)
	baseline_metadata = server_responses[p]
	monitor_metadata = server_responses[p+b_pts]
	dark_metadata = server_responses[p+b_pts+m_pts]
	primary_metadata = server_responses[p+b_pts+m_pts+d_pts]
	
	setdatafolder foldersave

end



	
	
	
	


function /s get_baseline()
	
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave
	variable i,j,k
	make /wave /n=0 /o baseline_waves
	string uid,uids="", testname, output, scan_ids = ""
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			scan_ids += plans_list[i][0]+";"
			uids += plans_list[i][5]+";"
		endif
	endfor
	string fieldsstring
	variable jsonId
	string primary_wave_names = ""
	string dataurls = "", streamurls = ""
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		dataurls += baseurl+"node/full/" + activeurl + "/" + uid + "/baseline/data?format=text/csv" + apikey + ";"
	endfor
	make /n=(itemsinlist(dataurls)) /t /free /o dataurl_wave = stringfromlist(p,dataurls), outputs
		
	wave/z/t baseline_metadata_urls
	wave/z/t baseline_metadata
	
	if(waveexists(baseline_metadata_urls) && waveexists(baseline_metadata))
		if(!cmpstr(baseline_metadata_urls[0],dataurl_wave[0]) &&numpnts(baseline_metadata) == numpnts(dataurl_wave))
			outputs = baseline_metadata //open the cached primary metadata string which was already pulled
		else
			multithread outputs = fetch_string(dataurl_wave[p],1)
		endif
	else
		multithread outputs = fetch_string(dataurl_wave[p],1)
	endif


//	multithread outputs = fetch_string(dataurl_wave[p],1) // get the metadata
	string baseline_wave_names = ""
	string uniquekeys="scan_id", key
	variable index, counter
	make /o /t /n=(1,1) baseline_display = "scan_id"
	variable numcols = 1
	for(i=0;i<itemsinlist(uids);i++)
		output = outputs[i]
		uid = stringfromlist(i,uids)
		variable num = itemsinlist(output,"\n") // subtract the line for headers
		if(num<2)
			continue
		endif
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		make /t /o /n=(itemsinlist(stringfromlist(0,output,"\n"),","),itemsinlist(output,"\n")) baseline
		baseline[][] = stringfromlist(p,stringfromlist(q,output,"\n"),",")
		baseline_wave_names += getwavesdataFolder(baseline,2)
		numcols += itemsinlist(output,"\n")-1
		redimension /n=(itemsinlist(uniquekeys),numcols) baseline_display
		baseline_display[0][numcols-itemsinlist(output,"\n")+1,] = stringfromlist(i,scan_ids)
		for(j=0;j<itemsinlist(stringfromlist(0,output,"\n"),",");j++)
			
			key = stringfromlist(j,stringfromlist(0,output,"\n"),",")
			index = whichListItem(key,uniquekeys)
			if(index<0)
				uniquekeys += key + ";"
				redimension /n=(itemsinlist(uniquekeys)+1,numcols) baseline_display
				index = itemsinlist(uniquekeys)
				baseline_display[index][0] = key
			endif
			
			counter=1
			for(k=numcols-1;k>numcols-itemsinlist(output,"\n");k--)
				baseline_display[index][k] = stringfromlist(j,stringfromlist(counter,output,"\n"),",")
				counter++
			endfor
		endfor
	endfor
	
	
	setdatafolder foldersave
	return baseline_wave_names
end




Threadsafe function /s fetch_string(string url,variable timeout)
	
		
	URLRequest /z /time=(timeout) url=url, method=get
	if(v_flag || !cmpstr(S_serverResponse,"Internal Server Error"))
		// try again - server seems to ocassionally hickup
		URLRequest /z /time=(timeout) url=url, method=get
		if(v_flag || !cmpstr(S_serverResponse,"Internal Server Error"))
			return ""
		endif
	endif
	string output = S_serverResponse
	return output

end

threadsafe function /s fetch_file(string url,string path, string filename, variable timeout)
	
	URLRequest /z /time=(timeout) /P=$path /File=filename /o url=url, method=get
	if(v_flag || !cmpstr(S_serverResponse,"Internal Server Error"))
		// try again - server seems to ocassionally hickup
		URLRequest /z /time=(timeout) /P=$path /File=filename /o  url=url, method=get
		if(v_flag || !cmpstr(S_serverResponse,"Internal Server Error"))
			return ""
		endif
	endif
	string output = S_fileName
	return output

end



function /s get_monitor_list()
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	string Monitor_Names = ""
	wave plans_sel_wave
	wave /t stream_names
	variable i,j
	string stream_name
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			for(j=0;j<itemsinlist(stream_names[i]);j++)
				stream_name = stringfromlist(j,stream_names[i])
				if(whichListItem(stream_name,monitor_names)==-1 && stringmatch(stream_name,"*_monitor"))
					monitor_names += cleanupname(removeending(stream_name,"_monitor"),0) + ";"
				endif
			endfor
		endif
	EndFor
	return monitor_names
end

function /s get_primary_channels()
	svar primary_channels = root:Packages:RSoXS_Tiled:all_primary_names_for_sel
	return primary_channels
end

Function Tiled_to_QANT(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			
			//go to selected uid folders
			
			
			svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
			DFREF foldersave = getdatafolderDFR()
			setdatafolder root:Packages:RSoXS_Tiled
			DFREF homedf = getdataFolderDFR()
			
			wave /T Plans_list, stream_names,metadata_string
			wave plans_sel_wave
			variable i,j,k
			make /wave /n=0 /o waves_to_copy
			string uids="", scan_ids = "", sample_names = "", plan_names = "", metadata_list = "", wave_names=""
			string list_of_urls = ""
			string streambase, stream_url, time_url
			for(i=0;i<dimsize(plans_sel_wave,0);i++)
				if(plans_sel_wave[i])
					scan_ids += plans_list[i][0]+";"
					uids += plans_list[i][5]+";"
					plan_names += plans_list[i][1]+";"
					sample_names += plans_list[i][2]+";"
					metadata_list += metadata_string[i] + ";"
					setdatafolder homedf
					setdatafolder $cleanupname(plans_list[i][5],0)
					wave_names += wavelist("*",",","DIMS:1,TEXT:0") + ";"
				endif
			endfor
			
			// get the waves to copy over including all the primary waves
			// all numeric waves with one dimension wavelist("*",";","DIMS:1,TEXT:0")
			setdatafolder root:
			newdatafolder /o/s NEXAFS
			newdatafolder /O/S Scans
			DFREF qantscansdf = getdataFolderDFR()
			string uid,plan_name,sample_name, scan_id, wave_name_list
			for(i=0;i<itemsinlist(uids);i++)
				setdatafolder qantscansdf
				sample_name = stringfromlist(i,sample_names)
				uid = stringfromlist(i,uids)
				wave_name_list = stringfromlist(i,wave_names)
				scan_id = activeurl+stringfromlist(i,scan_ids)
				newdatafolder /O/S $cleanupname(scan_id,1)
				string columnlist = ""
				for(j=0;j<itemsinlist(wave_name_list,",");j++)
					setdatafolder homedf
					setdatafolder $cleanupname(uid,0)
					wave /z datawave = $stringfromlist(j,wave_name_list,",")
					if(waveexists(datawave))
						setdatafolder qantscansdf
						setdatafolder $cleanupname(scan_id,1)
						duplicate /o datawave, $stringfromlist(j,wave_name_list,",")
						columnlist += stringfromlist(j,wave_name_list,",") + ";"
					endif
				endfor
				setdatafolder qantscansdf
				setdatafolder $cleanupname(scan_id,1)
				make /o /t /n=(itemsinlist(columnlist)) columnnames = stringfromlist(p,columnlist)
				setdatafolder homedf
				setdatafolder $cleanupname(uid,0)
				wave /t baseline
				setdatafolder qantscansdf
				setdatafolder $cleanupname(scan_id,1)
				duplicate /t/o baseline, ExtraPVs
				
				string /g metadata = stringfromlist(i,metadata_list)
				string /g samplename = sample_name
				string /g filename = stringfromlist(i,uids)
				string /g filesize = "NA"
				string /g cdate  = stringbykey("time",metadata)
				string /g mdate  = stringbykey("time",metadata)
				

			
				string /g notes = stringbykey("notes", metadata) + stringbykey("sample_name", metadata)
				string /g otherstr = stringbykey("dim1", metadata)
				string /g EnOffsetstr = ""
				string /g SampleSet = stringbykey("sample_set", metadata)
				string /g refscan = "Default"
				string /g darkscan = "Default"
				string /g enoffset = "Default"
				
				wave /z timew
				if(waveexists(timew))
					string /g acqtime = num2str(timew[0]) 
				else
					string /g acqtime = cdate
				endif
				findvalue /text="time" ExtraPvs
				string /g acqtime = ExtraPVs[v_value][1]
				findvalue /text="RSoXS Sample Rotation" ExtraPVs
				string /g anglestr
				if(strlen(anglestr)*0!=0)
					anglestr = ExtraPVs[v_value][1]
				endif
				
				
				variable xloc=nan, yloc=nan, zloc=nan, r1loc=nan, r2loc=nan
				
				findvalue /text="RSoXS Sample Outboard-Inboard" ExtraPVs
				if(v_value >=0)
					xloc=str2num(ExtraPVs[v_value][2])
				endif
				findvalue /text="RSoXS Sample Up-Down" ExtraPVs
				if(v_value >=0)
					yloc=str2num(ExtraPVs[v_value][2])
				endif
				findvalue /text="RSoXS Sample Downstream-Upstream" ExtraPVs
				if(v_value >=0)
					zloc=str2num(ExtraPVs[v_value][2])
				endif
				findvalue /text="RSoXS Sample Rotation" ExtraPVs
				if(v_value >=0)
					R1loc=90-str2num(ExtraPVs[v_value][2])
					anglestr =  num2str(90-str2num(ExtraPVs[v_value][2]))
				endif
				
				//findvalue /text="en_monoen_cff" ExtraPVs
				findvalue /text="en_polarization" ExtraPVs
			
				if(v_value >=0)
					otherstr=ExtraPVs[v_value][2]
				endif
				//findvalue /text="en_monoen_cff" ExtraPVs
				findvalue /text="en_sample_polarization" ExtraPVs
			
				if(v_value >=0)
					otherstr=ExtraPVs[v_value][2]
				endif
				
				if(xloc*yloc*zloc*r1loc*0==0)
					notes += "( X="+num2str(xloc)+", Y="+num2str(yloc)+", Z="+num2str(zloc)+", R1="+num2str(r1loc)+")"
				endif
				
				duplicate /o ExtraPVs, extrainfo
				wave /t columnnames
			
				wave /z datawave = $(columnnames[0])
				if(!waveexists(datawave))
					setdatafolder root:NEXAFS:scans
					killdatafolder /z cleanupname(scan_id,1)
					setdatafolder foldersave
					continue
				endif
				if(numpnts(datawave) <5)
					setdatafolder root:NEXAFS:scans
					killdatafolder /z cleanupname(scan_id,1)
					setdatafolder foldersave
					continue
				endif
				setdatafolder foldersave
				print "Loaded NEXAFS file : " + cleanupname(scan_id,1)
			endfor
			setdatafolder foldersave
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function scanBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
		update_scan_selection()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function TabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			switch(tab)
				case 0://monitors
					metadata_options(1)
					images_options(1)
					baseline_options(1)
					monitor_options(0)
					primary_options(1)
					break
				case 1://primary
					metadata_options(1)
					images_options(1)
					baseline_options(1)
					monitor_options(1)
					primary_options(0)
					break
				case 2://images
					metadata_options(1)
					images_options(0)
					baseline_options(1)
					monitor_options(1)
					primary_options(1)
					break
				case 3://baseline
					metadata_options(1)
					images_options(1)
					baseline_options(0)
					monitor_options(1)
					primary_options(1)
					break
				case 4://metadata
					metadata_options(0)
					images_options(1)
					baseline_options(1)
					monitor_options(1)
					primary_options(1)

			endswitch	
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


function metadata_options(variable disable)
	ListBox Metadata_listb,disable=(disable)
end
function images_options(variable disable)
	setwindow RSoXSTiled#images,HIDE=(disable)
	CheckBox log_image,disable=(disable)
	PopupMenu color_tab_pop,disable=(disable)
	SetVariable min_setv,disable=(disable)
	SetVariable max_setv,disable=(disable)
	ListBox Image_sel_lb, disable=(disable)
end
function baseline_options(variable disable)
	ListBox baseline_listb,disable=(disable)

end
function monitor_options(variable disable)
	setwindow RSoXSTiled#monitors,HIDE=(disable)
	PopupMenu monitor_color_tab_pop,disable=(disable)
	CheckBox individual_y_axis_m_chk,disable=(disable)
	CheckBox log_y_axis_m_chk,disable=(disable)
	CheckBox relative_x_m_axis,disable=(disable)
	Button Select_all_monitors,disable=(disable)
	ListBox monitor_listb,disable=(disable)
	Button deselect_all_monitors,disable=(disable)
end
function primary_options(variable disable)
	setwindow RSoXSTiled#primary,HIDE=(disable)
	PopupMenu X_Axis_channel_pop,win=RSoXSTiled,disable=(disable)
	Button Select_all_Primary,disable=(disable)
	ListBox Primary_listb,disable=(disable)
	Button deselect_all_primary,disable=(disable)
	CheckBox individual_y_p_axis_chk,disable=(disable)
	CheckBox log_y_axis_p_chk,disable=(disable)
	CheckBox log_x_axis_p_chk,disable=(disable)
end


Function Add_search(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			/// look at what kind of search, pull the necessary globals and construct a search
			string search = get_search_string()
			
			wave /t searchlist = root:Packages:RSoXS_Tiled:search_list
			wave search_sel_list = root:Packages:RSoXS_Tiled:search_sel_list
			wave /t search_settings = root:Packages:RSoXS_Tiled:search_settings
			if(strlen(search)>2)
				insertpoints /M=0 numpnts(searchlist),1,searchlist,search_sel_list,search_settings
				if(numpnts(search_settings)==1)
					redimension /n=(1,4) search_settings
				endif
				searchlist[numpnts(searchlist)-1] = stringfromlist(0,search)
				search_sel_list[numpnts(searchlist)-1] = 0
				search_settings[numpnts(searchlist)-1][0] = stringfromlist(1,search)
				search_settings[numpnts(searchlist)-1][1] = stringfromlist(2,search)
				search_settings[numpnts(searchlist)-1][2] = stringfromlist(3,search)
				search_settings[numpnts(searchlist)-1][3] = stringfromlist(4,search)
				update_list()
			endif
				
			break
		default: // control being killed
			break
	endswitch

	return 0
End

function edit_search_string()
	
	wave /t searchlist = root:Packages:RSoXS_Tiled:search_list
	wave search_sel_list = root:Packages:RSoXS_Tiled:search_sel_list
	wave /t search_settings = root:Packages:RSoXS_Tiled:search_settings
	findvalue /z/v=1 search_sel_list
	variable row = v_value
	if(sum(search_sel_list)==1 && row>=0)
		string search = get_search_string()
		if(strlen(search)>2)
			searchlist[row] = stringfromlist(0,search)
			search_settings[row][0] = stringfromlist(1,search)
			search_settings[row][1] = stringfromlist(2,search)
			search_settings[row][2] = stringfromlist(3,search)
			search_settings[row][3] = stringfromlist(4,search)
			update_list()
		endif
	endif

end



function /s get_search_string()
	svar comp_type = root:Packages:RSoXS_Tiled:comparison_type_search
	nvar search_type = root:Packages:RSoXS_Tiled:search_type
	svar key = root:Packages:RSoXS_Tiled:key_search
	svar value = root:Packages:RSoXS_Tiled:value_search
	// add search to the bottom of the search list
	string search = ""
	switch(search_type)
	case 1://Full Text
	//filter[eq][condition][key]=sample_id&filter[eq][condition][value]="diode"&
	//filter[fulltext][condition][text]=Calibration&filter[fulltext][condition][case_sensitive]=false
	//&sort=time
		search += "filter[fulltext][condition][text]="+value+"&filter[fulltext][condition][case_sensitive]=false"
		break
	case 2: // equals
		search += "filter[eq][condition][key]="+key+"&filter[eq][condition][value]=\""+value+"\""
		break
	case 3: // contains
	//filter[contains][condition][key]=sample_id&filter[contains][condition][value]="A1"
		search += "filter[contains][condition][key]="+key+"&filter[contains][condition][value]=\""+value+"\""
		break
	case 4: // comparison
		if(!cmpstr(comp_type,"<"))
			search +="filter[comparison][condition][operator]=lt"
		elseif(!cmpstr(comp_type,">"))
			search +="filter[comparison][condition][operator]=gt"
		endif
			
		search +="&filter[comparison][condition][key]="+key
		search +="&filter[comparison][condition][value]="+value
		//filter[comparison][condition][operator]=gt
		//&filter[comparison][condition][key]=scan_id
		//&filter[comparison][condition][value]=10000
		break
	case 5: // regex
	//filter[regex][condition][key]=sample_id&filter[regex][condition][pattern]=^A[1]&filter[regex][condition][case_sensitive]=false&sort=time
		search +="filter[regex][condition][key]="+key
		search +="&filter[regex][condition][pattern]="+value
		search +="&filter[regex][condition][case_sensitive]=false"
	default:
		break
	endswitch
	
	search+=";"+ num2str(search_type)
	search+=";"+ key
	search+=";"+ value
	search+=";"+ comp_type
	
	return search
end


Function catalog_search_kind_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			nvar search_type = root:Packages:RSoXS_Tiled:search_type
			search_type = popnum
			switch(popNum)
			
			case 1://Full Text
				// only value visible
				SetVariable Key_select,win=RSoXSTiled,disable=1
				SetVariable Value_select1,win=RSoXSTiled,disable=0
				PopupMenu catalog_search_comparison,win=RSoXSTiled,disable=1
				break
			case 2: // equals
			case 3: // contains
			case 5: // regex
				SetVariable Key_select,win=RSoXSTiled,disable=0
				SetVariable Value_select1,win=RSoXSTiled,disable=0
				PopupMenu catalog_search_comparison,win=RSoXSTiled,disable=1
				// comparison pop up invisible 
				break
			case 4: // comparison
				SetVariable Key_select,win=RSoXSTiled,disable=0
				SetVariable Value_select1,win=RSoXSTiled,disable=0
				PopupMenu catalog_search_comparison,win=RSoXSTiled,disable=0
				// all elements visible
				
				break
			default:
				break
			endswitch
			
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function remove_catalog_search_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave /t searchlist = root:Packages:RSoXS_Tiled:search_list
			wave /t search_settings = root:Packages:RSoXS_Tiled:search_settings
			wave search_sel_list = root:Packages:RSoXS_Tiled:search_sel_list
			variable i
			for(i=numpnts(search_sel_list)-1;i>=0;i-=1)
				if(search_sel_list[i])
					deletepoints i,1, search_sel_list, searchlist, search_settings
				endif
			endfor
			update_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function remove_all_catalog_search_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave /t searchlist = root:Packages:RSoXS_Tiled:search_list
			wave /t search_settings = root:Packages:RSoXS_Tiled:search_settings
			wave search_sel_list = root:Packages:RSoXS_Tiled:search_sel_list
			redimension /n=0 searchlist,search_sel_list, search_settings
			update_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function change_search_string(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			edit_search_string()
			SetVariable $(sva.ctrlname),win=RSoXSTiled,activate
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Catalog_search_comparison_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			// set string to comparison string
			svar type = root:Packages:RSoXS_Tiled:comparison_type_search
			type = popstr
			edit_search_string()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function /s get_images([string lims, variable forcedl])
	forcedl =  paramisdefault(forcedl)? 0 : forcedl
	variable uselimits = 0
	variable xmin,xmax,ymin,ymax
	if(!paramisdefault(lims))
		if(itemsinlist(lims,",")==4)
			xmin = str2num(stringfromlist(0,lims,","))
			xmax = str2num(stringfromlist(1,lims,","))
			ymin = str2num(stringfromlist(2,lims,","))
			ymax = str2num(stringfromlist(3,lims,","))
			if(xmin*ymin*xmax*ymax*0==0)
				if(xmin>=0 && xmax>xmin && ymin>=0 && ymax>ymin)
					uselimits = 1
				endif
			endif
		endif
	endif
	
	string list_of_image_nums_to_use = ""
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	svar /z baseurl = root:Packages:RSoXS_Tiled:baseurl
	svar /z activeurl = root:Packages:RSoXS_Tiled:activeurl
	
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	string /g image_wave_list // store the loaded image wave names here, for easy plotting etc.
	wave /z image_sel_list
	string list_of_imnums = ""
	variable i,j,k
	if(waveexists(image_sel_list))
		variable uselist = sum(image_sel_list)>0
		for(i=0;i<numpnts(image_sel_list);i++)
			if(image_sel_list[i])
				list_of_imnums += num2str(i)+";"
			endif
		endfor
	else
		uselist = 0
	endif
	string tmppath = getenvironmentVariable("TMP")
	if(strlen(tmppath)<1)
		tmppath = getenvironmentVariable("TMPDIR")
	endif
	newpath /o/q tempfolder, tmppath
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave, has_darks
	make /wave /n=0 /o primary_waves
	string uid,uids="",darks="", darkstr, testname, output, islight=""
	string list_of_urls = ""
	string streambase, stream_url, time_url
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i])
			uids += plans_list[i][5]+";"
			darks += num2str(has_darks[i])+";"
		endif
	endfor
	string fieldsstring
	variable jsonId, dark
	string primary_wave_names = ""
	string dataurls = "", streamurls = "", darkurls = ""
	for(i=0;i<itemsinlist(uids);i++)
		uid = stringfromlist(i,uids)
		stream_url = baseurl+"node/search/"+activeurl+ "/"
		stream_url += uid+"/primary?field=metadata" + apikey
		streamurls += stream_url + ";"
	endfor
	if(itemsinlist(streamurls)==0)
		MakeImagePlots(0)
		return ""
	endif
	make /n=(itemsinlist(uids)) /t/o/free streamurl_wave = stringfromlist(p,streamurls+darkurls), outputs
	
	wave/z/t primary_metadata_urls
	wave/z/t primary_metadata
	
	if(waveexists(primary_metadata_urls) && waveexists(primary_metadata))
		if(!cmpstr(primary_metadata_urls[0],streamurl_wave[0]) &&numpnts(primary_metadata) == numpnts(streamurl_wave))
			outputs = primary_metadata //open the cached primary metadata string which was already pulled
		else
			multithread outputs = fetch_string(streamurl_wave[p],1)
		endif
	else
		multithread outputs = fetch_string(streamurl_wave[p],1)
	endif

	
	
	string filenames = "",layers = ""
	variable numimages = 0, realxmin, realxmax, realymin, realymax
	string x_dims = ""
	string uid_list = "",dark_list = "", fnamenum_str
	
	for(i=0;i<itemsinlist(uids);i++) // loop through each image channel in each uid, to build the filenames and get the image sizes
		
		output = outputs[i]
		uid = stringfromlist(i,uids)
		darkstr = stringfromlist(i,darks)
		if(strlen(output)<3)
			print "couldn't get metadata"
			continue
		endif
		JSONXOP_Parse/q/z output
		if(v_flag)
			print "bad responce to metadata"
			continue
		endif
		jsonId = V_value
		string xmin_str="",ymin_str="",xmax_str="",ymax_str="",xdim_temp, xmin_temp, xmax_temp, ymin_temp, ymax_temp
		JSoNXOP_GetKeys /free/q/z jsonID, "data/0/attributes/metadata/descriptors/0/data_keys", tempwave
		for(j=0;j<dimsize(tempwave,0);j++)
			if(!stringmatch(tempwave[j],"*_image"))
				continue
			endif
			JSONXOP_GetValue /free /q /z /wave=shape jsonId, "data/0/attributes/structure/macro/data_vars/"+tempwave[j]+"/macro/variable/macro/shape"
			list_of_image_nums_to_use = ""
			if(uselist)
				for(k=0;k<shape[0];k++)
					if(whichlistitem(num2str(k),list_of_imnums)>=0)
						numimages += 1
						list_of_image_nums_to_use += num2str(k)+";"
					endif
				endfor
			else
				list_of_image_nums_to_use =":;"
				numimages += shape[0]*shape[1]
			endif
			if(uselimits)
				realxmin = min(max(0,xmin),shape[2]-1)
				xmin_temp = num2str(realxmin)
				realxmax = max(realxmin+1,min(shape[2],xmax))
				xmax_temp = num2str(realxmax)
				realymin = min(max(0,ymin),shape[3]-1)
				ymin_temp = num2str(realymin)
				realymax = max(realymin+1,min(shape[3],ymax))
				ymax_temp = num2str(realymax)
				
				xdim_temp = num2str(realxmax-realxmin)
			else
				xdim_temp = num2str(shape[2])
				xmin_temp= ""
				xmax_temp= ""
				ymin_temp= ""
				ymax_temp= ""
			endif
			for(k=0;k<itemsinlist(list_of_image_nums_to_use);k++)
				x_dims += xdim_temp+";"
				xmin_str+= xmin_temp+";"
				xmax_str+= xmax_temp+";"
				ymin_str+= ymin_temp+";"
				ymax_str+= ymax_temp+";"
				layers += stringfromlist(k,list_of_image_nums_to_use) + ";"
				dataurls += baseurl+"array/full/" + activeurl + "/" + uid + "/primary/data/data_vars/"+URLencode(tempwave[j])+"/variable?format=tif" + apikey+"&slice="+stringfromlist(k,list_of_image_nums_to_use) + ";"
				filenames +=cleanupname(uid,1,20)+replacestring(":",stringfromlist(k,list_of_image_nums_to_use),"a")+cleanupname(tempwave[j],1,10)+";"
				uid_list += uid + ";"
				dark_list += "0"+ ";"
			endfor
			if(str2num(darkstr))
				list_of_image_nums_to_use +=":;"
				x_dims += num2str(shape[2])+";"
				layers += ";" // always get all darks
				dataurls += baseurl+"array/full/" + activeurl + "/" + uid + "/dark/data/data_vars/"+URLencode(tempwave[j])+"/variable?format=tif" + apikey+"&slice=:;"
				filenames +=cleanupname(uid,1,20)+"d"+cleanupname(tempwave[j],1,9)+";"
				uid_list += uid + ";"
				dark_list += darkstr+ ";"
			endif
		endfor
		JSONXOP_release jsonID
	endfor
	// calculate the slicing necessary for each step
	if(itemsinlist(x_dims)==0)
		MakeImagePlots(0)
		return ""
	endif
	
	
	make /free/n=(itemsinlist(x_dims)) /t slicingratio, uid_wave, dark_wave, layerwave
	uid_wave = stringfromlist(p,uid_list)
	dark_wave = stringfromlist(p,dark_list) // indicates if this file is for darks
	layerwave = stringfromlist(p,layers)
	make /free/n=(itemsinlist(dark_list)) use_darks = str2num(stringfromlist(p,dark_list))
	
	slicingratio = num2str(get_slicing_ratio(numimages,1500,str2num(stringfromlist(p,x_dims))))
	
	
	
	make /n=(itemsinlist(dataurls)) /t /free /o dataurl_wave, file_names, file_paths, limits
	limits = stringfromlist(p,xmin_str)+","+stringfromlist(p,xmax_str)+","+stringfromlist(p,ymin_str)+","+stringfromlist(p,ymax_str)
	dataurl_wave = stringfromlist(p,dataurls)+",0,"+stringfromlist(p,xmin_str)+":"+stringfromlist(p,xmax_str)+":"+slicingratio[p]+","+stringfromlist(p,ymin_str)+":"+stringfromlist(p,ymax_str)+":"+slicingratio[p]

	file_names = stringfromlist(p,filenames)+"_"+slicingratio[p]+".tiff"
	string cached_file_list = ""
	string cached_file_uids = ""
	string cached_file_darks = ""
	string cached_limits = ""
	string cached_layers = ""
	for(i=numpnts(file_names)-1;i>=0;i--)
		getfileFolderInfo /q/z/P=tempfolder file_names[i]
		if(v_flag==0 && V_logEOF > 500 && !forcedl)
			cached_file_list += s_path+";"
			cached_file_uids += uid_wave[i] + ";"
			cached_limits += limits[i] + ";"
			cached_file_darks += dark_wave[i] + ";"
			cached_layers += layerwave[i] + ";"
			deletepoints i,1, dataurl_wave, file_paths, file_names, uid_wave, dark_wave, limits, layerwave
		endif
	endfor
	if(numpnts(file_paths)>0)
		//multithread /NT=5 file_paths = fetch_file(dataurl_wave[p], "tempfolder",file_names[p],20)
		file_paths = fetch_file(dataurl_wave[p], "tempfolder",file_names[p],20)
	endif

	
// load the images into the uid folder, split them out into individual images, plot them in plots
	string wave_list = ""
	string limstr
	string layer
	for(i=0;i<numpnts(file_paths);i++)
		uid = uid_wave[i]
		limstr = limits[i]
		darkstr = dark_wave[i]
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		string /g datawave_list = ""
		string /g darkwave_list = ""
	endfor
	for(i=itemsinlist(cached_file_list)-1;i>=0;i--)
		uid = stringfromlist(i,cached_file_uids)
		limstr = stringfromlist(i,cached_limits)
		darkstr = stringfromlist(i,cached_file_darks)
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		string /g datawave_list = ""
		string /g darkwave_list = ""
	endfor
	for(i=0;i<numpnts(file_paths);i++)
		uid = uid_wave[i]
		limstr = limits[i]
		darkstr = dark_wave[i]
		layer = layerwave[i]
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		string /g datawave_list
		string /g darkwave_list
		ImageLoad/O/Z/T=tiff/S=0/C=-1/LR3D/Q file_paths[i]
		if(v_flag==0)
			deleteFile /z file_paths[i]
			continue
		endif
		for(j=0;j<itemsinlist(s_wavenames);j++)
			wave newwave = $stringfromlist(j,s_wavenames)
			if(uselimits)
				setscale /i x, str2num(stringfromlist(0,limstr,",")), str2num(stringfromlist(1,limstr,",")), newwave
				setscale /i y, str2num(stringfromlist(2,limstr,",")), str2num(stringfromlist(3,limstr,",")), newwave
			endif
			note newwave, "layer:"+layer+";"
			if(str2num(darkstr))
				darkwave_list += getwavesdatafolder(newwave,2) + ";"
			else
				datawave_list += getwavesdatafolder(newwave,2) + ";"
				wave_list += getwavesdatafolder(newwave,2) + ";"
			endif
		endfor
		variable /g dark_subtracted = 0
	endfor
	for(i=itemsinlist(cached_file_list)-1;i>=0;i--)
		uid = stringfromlist(i,cached_file_uids)
		limstr = stringfromlist(i,cached_limits)
		darkstr = stringfromlist(i,cached_file_darks)
		layer = stringfromlist(i,cached_layers)
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		string /g datawave_list
		string /g darkwave_list
		ImageLoad/O/Z/T=tiff/S=0/C=-1/LR3D/Q stringfromlist(i,cached_file_list)
		if(v_flag==0)
			deleteFile /z stringfromlist(i,cached_file_list)
			continue
		endif
		for(j=0;j<itemsinlist(s_wavenames);j++)
			wave newwave = $stringfromlist(j,s_wavenames)
			if(uselimits)
				setscale /i x, str2num(stringfromlist(0,limstr,",")), str2num(stringfromlist(1,limstr,",")), newwave
				setscale /i y, str2num(stringfromlist(2,limstr,",")), str2num(stringfromlist(3,limstr,",")), newwave
			endif
			note newwave, "layer:"+layer+";"
			if(str2num(darkstr))
				darkwave_list += getwavesdatafolder(newwave,2) + ";"
			else
				datawave_list += getwavesdatafolder(newwave,2) + ";"
				wave_list += getwavesdatafolder(newwave,2) + ";"
			endif
		endfor
		variable /g dark_subtracted = 0
	endfor
	subtract_darks()
	MakeImagePlots(numimages)
	image_wave_list = wave_list
	update_image_plots() // this reads the list of loaded images, and plots them in the image plots.
	setdatafolder foldersave
	return wave_list


end


function get_slicing_ratio(variable num_images,variable total_pix_x, variable image_pix_X)
	variable images_on_top_edge = ceil(sqrt(num_images))
	variable images_on_left_edge = ceil(num_images/images_on_top_edge)
	return ceil(image_pix_X/(total_pix_x/images_on_top_edge))
end


function MakeImagePlots(num)
	variable num
	variable numx, numy
	dfref foldersave = getdatafolderdfR()
	setdatafolder root:Packages:RSoXS_Tiled
	dfref homedf = getdataFolderDFR()
	wave /z/t image_plot_names
	variable i
	if(waveexists(image_plot_names))
		for(i=0;i<dimsize(image_plot_names,0);i+=1)
			killwindow /z RSoXSTiled#images#$image_plot_names[i]
		endfor
	endif
	make /o/n=(num) /t image_plot_names
	
	
	numy = max(1,floor(.9*sqrt(num)))
	numx = ceil((num)/numy)
	
	variable sizex, sizey
	//(414,68,1680,892)
	getwindow RSOXSTILED#images wsize
	sizex = floor((v_right-v_left) / numx)
	sizey = floor((v_bottom-v_top) / numy)
	
	variable xloc=0, yloc=0
	variable imnum = 0
	image_plot_names = "Tiled_image"+num2str(p)
	for(yloc=0;yloc<numy;yloc+=1)
		for(xloc=0;xloc<numx;xloc+=1)
			if(imnum>=num)
				break
			endif
			Display/W=(sizex*xloc,sizey*yloc,sizex*(xloc+1),sizey*(yloc+1))/HOST=RSOXSTILED#images /n=$image_plot_names[imnum]
			imnum+=1
		endfor
		if(imnum>=num)
			break
		endif
	endfor
end

function update_scan_selection()
	get_all_metadata()
	get_primary()
	get_darks()
	get_baseline()
	get_monitors() // this will add to the primary list
	get_images(forcedl=1)
	update_monitor_plots()
	update_primary_plots()
	update_baseline_display()
	update_metadata_display()

end

function update_image_plots([variable plot])
	plot = paramIsDefault(plot)? 1 : 0
// make or update all of the images from the list of images and uids selected
	dfref foldersave = getdatafolderdfR()
	setdatafolder root:Packages:RSoXS_Tiled
	dfref homedf = getdataFolderDFR()
	nvar min_val, max_val, logimage
	svar colortab
	wave /t image_plot_names
	svar image_wave_list
	variable i,j,imnum=0,k
	for(i=0;i<itemsinlist(image_wave_list);i++)
		wave image = $stringfromlist(i,image_wave_list)
		svar image_names = $(getwavesdataFolder(image,1)+"image_names")
		for(j=0;j<dimsize(image,2);j++)
			IF(PLOT|| strlen(ImageNameList("RSoXSTiled#images#"+image_plot_names[imnum],";"))==0)
				appendimage /G=1 /w=RSoXSTiled#images#$image_plot_names[imnum] image
			endif
			ModifyImage /w=RSoXSTiled#images#$image_plot_names[imnum] ''#0, plane=j
			ModifyGraph /w=RSoXSTiled#images#$image_plot_names[imnum] margin=1,nticks=0,standoff=0
			ModifyImage /w=RSoXSTiled#images#$image_plot_names[imnum] ''#0 log=logimage,ctab= {min_val,max_val,$colortab,0}
			k=numberbykey("layer",note(image))
			k=numtype(k)==2? 0 : k
			TextBox /w=RSoXSTiled#images#$image_plot_names[imnum] /S=0/F=0/A=LT stringfromlist(k+j,image_names)
			imnum+=1
		endfor
	endfor
end
function update_monitor_plots()
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	svar channels = root:Packages:RSoXS_Tiled:all_monitor_names_for_sel
	wave /t wave_list = root:Packages:RSoXS_Tiled:wave_names_from_monitor_list
	svar /z plotted_channels = root:Packages:RSoXS_Tiled:monitor_plot_channels
	nvar logy = root:Packages:RSoXS_Tiled:monitor_plot_logy
	nvar seperate_axes = root:Packages:RSoXS_Tiled:monitor_plot_indv_axes
	nvar sub_time_axis = root:Packages:RSoXS_Tiled:monitor_plot_subxoffset
	string tnames = tracenameList("RSoXSTiled#monitors","",1)
	variable i,j
	for(i=itemsinlist(tnames)-1;i>=0;i--)
		removeFromGraph /w=RSoXSTiled#monitors $stringfromlist(i,tnames)
	endfor
	if(!svar_exists(plotted_channels))
		return -1
	endif
	variable chan_idx
	string wavelocs
	for(i=0;i<itemsinlist(plotted_channels);i++)
		chan_idx = whichlistitem(removeending(stringfromlist(i,plotted_channels),"_monitor"),channels)
		if(chan_idx<0)
			print "Error - couldn't find monitor channel " + stringfromlist(i,plotted_channels)
			continue
		endif
		wavelocs = wave_list[chan_idx]
		for(j=0;j<itemsinlist(wavelocs);j+=1)
			wave /z datawave = $stringfromlist(j,wavelocs)
			if(seperate_axes)
				appendtograph /w=RSoXSTiled#monitors /b/l=$Cleanupname(nameofwave(datawave),0)  datawave[][0] /TN=$(Cleanupname(nameofwave(datawave),0)+num2str(j)) vs datawave[][1]
				ModifyGraph /w=RSoXSTiled#monitors nticks($Cleanupname(nameofwave(datawave),0))=0,freePos($Cleanupname(nameofwave(datawave),0))=0,noLabel($Cleanupname(nameofwave(datawave),0))=2
				ModifyGraph /w=RSoXSTiled#monitors log($Cleanupname(nameofwave(datawave),0))=logy
			else
				appendtograph /w=RSoXSTiled#monitors /l/b  datawave[][0] /TN=$(Cleanupname(nameofwave(datawave),0)+num2str(j)) vs datawave[][1]
				ModifyGraph /w=RSoXSTiled#monitors log(left)=logy
			endif
			if(sub_time_axis)
				ModifyGraph /w=RSoXSTiled#monitors offset($(Cleanupname(nameofwave(datawave),0)+num2str(j)))={-datawave[0][1]+1,0}
			endif

		endfor
	endfor
	svar color =  root:Packages:RSoXS_Tiled:monitor_color
	Color_Traces(color,"RSoXSTiled#monitors")
	setdatafolder foldersave
// make or update the plot of the monitors based on the selected uids and channels
end

function update_primary_plots()
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	svar channels = root:Packages:RSoXS_Tiled:all_primary_names_for_sel
	svar xaxis = root:Packages:RSoXS_Tiled:primary_x_axis
	nvar logx = root:Packages:RSoXS_Tiled:primary_plot_logx
	nvar logy = root:Packages:RSoXS_Tiled:primary_plot_logy
	nvar seperate_axes = root:Packages:RSoXS_Tiled:primary_plot_indv_axes
	wave /t wave_list = root:Packages:RSoXS_Tiled:wave_names_from_primary_list
	svar /z plotted_channels = root:Packages:RSoXS_Tiled:primary_plot_channels
	string tnames = tracenameList("RSoXSTiled#Primary","",1)
	variable i,j
	for(i=itemsinlist(tnames)-1;i>=0;i--)
		removeFromGraph /w=RSoXSTiled#Primary $stringfromlist(i,tnames)
	endfor
	if(!svar_exists(plotted_channels))
		return -1
	endif
	variable chan_idx
	string wavelocs, waveloc_cleaned, wavename_cleaned
	for(i=0;i<itemsinlist(plotted_channels);i++)
		chan_idx = whichlistitem(stringfromlist(i,plotted_channels),channels)
		if(chan_idx<0)
			print "Error - couldn't find primary channel " + stringfromlist(i,plotted_channels)
			continue
		endif
		wavelocs = wave_list[chan_idx]
		wavename_cleaned = stringfromlist(i,plotted_channels)
		for(j=0;j<itemsinlist(wavelocs);j+=1)
			waveloc_cleaned = stringfromlist(j,wavelocs)
			wave /z datawave = $stringfromlist(j,wavelocs)
			setdatafolder getwavesDataFolderDFR(datawave)
			wave /z xwave = $xaxis
			if(waveexists(xwave) && waveexists(datawave))
				if(seperate_axes)
					appendtograph /w=RSoXSTiled#Primary /l=$Cleanupname(nameofwave(datawave),0) datawave vs xwave
					ModifyGraph /w=RSoXSTiled#Primary nticks($Cleanupname(nameofwave(datawave),0))=0,freePos($Cleanupname(nameofwave(datawave),0))=0,noLabel($Cleanupname(nameofwave(datawave),0))=2
				else
					appendtograph /w=RSoXSTiled#Primary datawave vs xwave
				endif
				ModifyGraph /w=RSoXSTiled#Primary log(left)=logy
				ModifyGraph /w=RSoXSTiled#Primary log(bottom)=logx
			else
				wave /z xwave = $(xaxis+"0")
				if(waveexists(xwave) && waveexists(datawave))
					if(seperate_axes)
						appendtograph /w=RSoXSTiled#Primary /l=$Cleanupname(nameofwave(datawave),0) datawave vs xwave
						ModifyGraph /w=RSoXSTiled#Primary nticks($Cleanupname(nameofwave(datawave),0))=0,freePos($Cleanupname(nameofwave(datawave),0))=0,noLabel($Cleanupname(nameofwave(datawave),0))=2
						ModifyGraph /w=RSoXSTiled#Primary log($Cleanupname(nameofwave(datawave),0))=logy
					else
						appendtograph /w=RSoXSTiled#Primary datawave vs xwave
					endif
					ModifyGraph /w=RSoXSTiled#Primary log(bottom)=logx
				endif
			endif
		endfor
	endfor
	svar color =  root:Packages:RSoXS_Tiled:Primary_color
	Color_Traces(color,"RSoXSTiled#primary")
	setdatafolder foldersave
//make or update the plot of the primary tabular data based on the selected uids and channels
end
function update_baseline_display()
// populate whatever baseline display (listbox? graph?) based on the uids selected
end
function update_metadata_display()
	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()


	
	setdatafolder foldersave
// populate the listbox of metadata for the selected uids
end

function dostuff()
	get_all_metadata()
	get_primary()
	get_darks()
	get_baseline()
	get_monitors()
	get_images()
end

function subtract_darks()
 // get the list of uids
 	DFREF foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	DFREF homedf = getdataFolderDFR()
	
	wave /T Plans_list, stream_names
	wave plans_sel_wave, has_darks
	variable i,j,k
	string uids = "", uid
	for(i=0;i<dimsize(plans_sel_wave,0);i++)
		if(plans_sel_wave[i] && has_darks[i])
			uids += plans_list[i][5]+";"
		endif
	endfor
	make /o/n=(itemsinlist(uids)) /t uid_wave = stringfromlist(p,uids)
	
	
 	for(i=0;i<numpnts(uid_wave);i++)
		uid = uid_wave[i]
		setdatafolder homedf
		newdatafolder /o/s $cleanupname(uid,0)
		nvar /z dark_subtracted
		if(nvar_exists(dark_subtracted))
			if(dark_subtracted)
				continue
			endif
		endif
		wave /z timew = time0
		wave dtimew = :darks:time0
		svar /z datawave_list,darkwave_list
		
		
		if(!waveexists(timew)||!waveexists(dtimew)||!svar_exists(datawave_list)||!svar_exists(darkwave_list))
			continue
		endif
		duplicate /free timew,darkpnt
		darkpnt = binarysearch(dtimew,timew)
		darkpnt = darkpnt[p]==-1 ? 0 : darkpnt[p]
		darkpnt = darkpnt[p]==-2 ? numpnts(dtimew)-1 : darkpnt[p]
		wave /z darkw = $stringfromlist(0,darkwave_list)
		if(!waveexists(darkw))
			continue
		endif
		for(j=0;j<itemsinlist(datawave_list);j++)
			wave /z dataw = $stringfromlist(j,datawave_list) // will there be multiples ever?  I think we always just want to use the one...
		
			if(!waveexists(dataw))
				continue
			endif
			k = numberByKey("layer",note(dataw))
			k = numtype(k)==2 ? 0 : k
			dataw -= darkw[p][q][darkpnt[min(k+r,numpnts(darkpnt)-1)]]
		endfor
		variable /g dark_subtracted = 1
		
	endfor
	
	
	setdatafolder foldersave

end


Function search_listbox_proc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			if(sum(selwave)==1)
				wave /t search_settings = root:Packages:RSoXS_Tiled:search_settings
				if(row < dimsize(search_settings,0))
					svar comp_type = root:Packages:RSoXS_Tiled:comparison_type_search
					nvar search_type = root:Packages:RSoXS_Tiled:search_type
					svar key = root:Packages:RSoXS_Tiled:key_search
					svar value = root:Packages:RSoXS_Tiled:value_search
					search_type = str2num(search_settings[row][0])
					key = search_settings[row][1]
					value = search_settings[row][2]
					comp_type = search_settings[row][3]
				endif
			endif
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function set_image_val_pop(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			update_image_plots(plot=0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function change_image_option_proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			
			update_image_plots(plot=0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function COlorTab_pop_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			svar ctab = root:Packages:RSoXS_Tiled:colortab
			ctab = popstr
			update_image_plots(plot=0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End




Function ScrollZoomHook(s)
	STRUCT WMWinHookStruct &s
	string axes_t, axisname, info, dummy
	variable numaxes, i, j, f1, f2
	variable relx, rely, scale, mouseLoc, cursorval, rangeinc, newmax, newmin

	// bit 0:	Mouse button is down.
	//bit 1:	Shift key is down.
	//bit 2:	Option (Macintosh ) or Alt (Windows ) is down.
	//bit 3:	Command (Macintosh ) or Ctrl (Windows ) is down.
	//bit 4:	Contextual menu click: right-click or Control-click (Macintosh , or right-click (Windows ).
	switch(s.eventCode)
		case 3:		// Mouse down
			if(s.eventMod & 2^4)		// right mouse button - leave this interaction as normal
				PopupContextualMenu/C=(s.mouseLoc.h, s.mouseLoc.v)/N "ScrollZoomDisablePopup"
			endif
			
			break
		case 4: // mouse moved
		case 5: // mouse up
		case 22:		// Scroll wheel
			if ((s.eventMod & 2^3) == 0)		// Temp disable if control key held down

			axes_t = axislist("")
			numaxes = itemsinlist(axes_t)
			make/n=(numaxes)/free/o/t axes, sz_name, sz_type
			make/n=(numaxes)/free/o sz_relpos0, sz_relpos1, sz_min, sz_max
			
			getwindow kwTopWin, psizeDC
			rely = (s.mouseLoc.v - V_top) / (V_bottom - V_top)
			rely = 1 - rely
			relx = (s.mouseLoc.h - V_left) / (V_right - V_left)
	
			// Are we inside plot area?
			if ( (relx >= 0) && (relx <=1) && (rely >= 0) && (rely <=1))
			
			scale = 0.03
			scale *= s.wheelDy
			if ((s.eventMod & 2^1) != 0)		// Shift
				scale *= 8
			endif
			//if (s.wheelDy)
			//	scale = .03
			//	scale *= s.wheelDy
			//else
			//	scale = .25
			//	scale *= s.wheelDx
			//endif
			
			make/free/n=(numaxes)/t axes
			axes = stringfromlist(p, axes_t)
			// Get axis info and put into waves.  To do: move into sep routine.
			for (i=0; i<numaxes; i+=1)
				axisname = axes[i]
				info = axisinfo("", axisname)
				sz_name[i] = axisname
				sz_type[i] = stringbykey("AXTYPE", info)
				sscanf stringbykey("axisEnab(x)", info, "="), "{%f,%f}", f1, f2
				sz_relpos0[i] = f1
				sz_relpos1[i] = f2
				getaxis/q $axisname
				sz_min[i] = V_min
				sz_max[i] = V_max
			endfor

			// Check if we're within axis bounds
			extract/free/o/indx axes, haxes, (stringmatch(sz_type[p], "top") || stringmatch(sz_type[p], "bottom") )  && relx > sz_relpos0[p] && relx < sz_relpos1[p]
			extract/free/indx axes, vaxes, (stringmatch(sz_type[p], "left") || stringmatch(sz_type[p], "right") )  && rely > sz_relpos0[p] && rely < sz_relpos1[p]
			make/free/n=0 targetaxes
			concatenate/np {haxes, vaxes}, targetaxes

			pauseupdate; silent 1
			s.doSetCursor = 1
			s.cursorCode = 8
			for (i=0; i<numpnts(targetaxes); i+=1)
				j = targetaxes[i]
				if ( stringmatch(sz_type[j], "top") || stringmatch(sz_type[j], "bottom") )
					mouseLoc = s.mouseLoc.h
				else
					mouseLoc = s.mouseLoc.v
				endif
				axisname = axes[j]
				cursorval = axisvalfrompixel("", axisname, mouseLoc)
				rangeinc = (sz_max[j] - sz_min[j]) * scale
				newmax = sz_max[j] + -rangeinc * (sz_max[j] - cursorval) / (sz_max[j] - sz_min[j])
				newmin = sz_min[j] - -rangeinc * (cursorval - sz_min[j]) / (sz_max[j] - sz_min[j])
				SetAxis $axes[j] newmin, newmax
			endfor
			
			endif
			endif
			break
	EndSwitch
End


Function Primary_sel_listbox_proc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			get_images()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function Primary_Xaxis_sel_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			dfref foldersave = getdatafolderdfr()
			setdatafolder root:Packages:RSoXS_Tiled
			string /g primary_x_axis
			primary_x_axis = popStr
			setdatafolder foldersave
			update_primary_plots()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


function Color_Traces(Colortabname,Graphname)
	string colortabname, graphname
	
	if(cmpstr(graphName,"")==0)
		graphname = WinName(0, 1)
	endif
	if (strlen(graphName) == 0)
		return -1
	endif

	Variable numTraces =itemsinlist(TraceNameList(graphName,";",1))
	if (numTraces <= 0)
		return -1
	endif
	variable numtracesden=numtraces
	if( numTraces < 2 )
		numTracesden= 2	// avoid divide by zero, use just the first color for 1 trace
	endif

	ColorTab2Wave $colortabname
	wave RGB = M_colors
	Variable numRows= DimSize(rgb,0)
	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)
		index = round(i/(numTracesden-1) * (numRows*2/3-1))	// spread entire color range over all traces.
		ModifyGraph/w=$graphName rgb[i]=(rgb[index][0], rgb[index][1], rgb[index][2])
	endfor
end


Function Primary_color_pop_Proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			svar color =  root:Packages:RSoXS_Tiled:Primary_color
			color = popstr
			Color_Traces(color,"RSoXSTiled#primary")
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function monitor_color_pop_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			svar color =  root:Packages:RSoXS_Tiled:Monitor_color
			color = popstr
			Color_Traces(color,"RSoXSTiled#monitor")
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



function /wave splitsignal(wavein, times, rises, falls, goodpulse)
	wave wavein,times, rises, falls,goodpulse // take the time from the primary wave, and get a representation of the monitors around this time
	// look for pulses and pick out one the pulse height points if possible, otherwise just mean.
	// rises, falls, and goodpulse are itterative measures, so if a strong signal is measured first, these value will make the proceeding calls more accurate
	// thus the behavior will vary depending on the order you run the monitors through this function
	
	make /free /n=(dimsize(wavein,0)) /d timesin = wavein[p][1], datain = wavein[p][0]
	
	string name = nameofwave(wavein)
	wave /z waveout = $("_"+name)
	if(numpnts(wavein)<2* numpnts(times))
		//print "not valid waves"
		return waveout
	endif
	make /o/n=(dimsize(times,0)) $("m_"+name), $("s_"+name), $("f_"+name)
	wave waveout = $("m_"+name), stdwave = $("s_"+name), fncwave = $("f_"+name)
	make /n=(dimsize(times,0)) /free pntlower, pntupper
	pntupper = binarysearch(timesin,times[p])
	pntupper = pntupper[p]==-2 ? numpnts(timesin)-1 : pntupper[p]
	duplicate /o /free pntupper, pntlower, pntlower1
	pntlower1 = binarysearch(timesin,times[p]-1.5)
	insertpoints /v=0 0,1,pntlower
	make /free temprises, tempfalls
	waveout = median(datain,pntlower1[p]+10,pntupper[p]-0)
	stdwave = sqrt(variance(datain,pntlower1[p]+2,pntupper[p]-0))
	variable i, meanvalue, alreadygood, err
	for(i=0;i<dimsize(times,0);i+=1)
		if(pntupper[i] - pntlower[i] < 3)
			continue
		endif
		//meanvalue = mean(datain,pntlower[i],pntupper[i])
		meanvalue = (6/10) *(wavemin(datain,pntlower[i],pntupper[i]) + wavemax(datain,pntlower[i],pntupper[i]))
		try
			findlevels /B=3/EDGE=1 /Q /P /D=temprises /R=[max(0,pntlower[i]),min(numpnts(datain)-1,pntupper[i])] datain, meanvalue;AbortonRTE // look for rising and falling edges
			findlevels /B=3/EDGE=2 /Q /P /D=tempfalls /R=[max(0,pntlower[i]),min(numpnts(datain)-1,pntupper[i])] datain, meanvalue;AbortonRTE
		catch
			err = getRTError(1)
			//print getErrMessage(err)
			goodpulse[i]=0
			break
		endtry
		if(dimsize(temprises,0) == 1 && dimsize(tempfalls,0)== 1 ) // did we find a single pulse?
			alreadygood = goodpulse[i]
			rises[i] = timesin(temprises[0]) // if so, change them to times (so they work for all channels)
			falls[i] = timesin(tempfalls[0])
			waveout[i] = median(datain,binarysearchinterp(timesin,rises[i])+1,binarysearchinterp(timesin,falls[i])-1)
			stdwave[i] = sqrt(variance(datain,binarysearchinterp(timesin,rises[i])+1,binarysearchinterp(timesin,falls[i])-1))
			goodpulse[i]=1
		else
			if(alreadygood) // have we already found the rising and falling times?
				waveout[i] = median(datain,binarysearch(timesin,rises[i])+0,binarysearch(timesin,falls[i]))
				stdwave[i] = sqrt(variance(datain,binarysearch(timesin,rises[i])+0,binarysearch(timesin,falls[i])))
			else
				goodpulse[i]=0
			endif
		endif
	endfor
	
	//curvefit
	return waveout
end


function /s get_apikey()
// load the api key from memory, or read it from disk into memory
	svar /z apikey = root:Packages:RSoXS_Tiled:apikey
	if(svar_exists(apikey))
		return apikey
	endif
	dfref foldersave =  getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	string /g apikey
	string test_string = load_apikey()
	if(strlen(test_string)>20)
		apikey = "&api_key=" + test_string
		return apikey
	else
		test_string = write_apikey()
		if(strlen(test_string)>20)
			apikey = "&api_key=" + test_string
			return apikey
		endif
	endif
	
	setdatafolder foldersave
end


function /s write_apikey()
// get the api key from user, and write it to a file in the user documents
	
	string apikey
	prompt apikey, "Tiled API key - follow the instructions to log into tiled and generate an api key\r and enter that here. \ryou will only need to enter this once on this computer."
	doprompt "Please enter your API key.  this will be stored in your user documents folder.", apikey
	if(v_flag)
		return ""
	endif
	variable apikeyfile
	open /p=IgorUserFiles /z apikeyfile as "tiledapi.key"
	fprintf apikeyfile, "%s", apikey
	close apikeyfile
	return apikey
end

function /s load_apikey()
	variable apikeyfile
	string apikey
	open /r/p=IgorUserFiles /z apikeyfile as "tiledapi.key"
	freadLine /n=10000 apikeyfile, apikey
	close apikeyfile
	return apikey
end

Function update_api_but(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			write_apikey()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Menu "RSoXS"
	"TiledRSoXS", /Q, Execute/P "init_tiled_rsoxs()"
	help={"Browse and import data from a Tiled server"}
End


function update_primary_list()
	wave /t lb_wave = root:Packages:RSoXS_Tiled:Primary_list_wave
	wave lb_sel_wave = root:Packages:RSoXS_Tiled:primary_sel_list
	dfref foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	string /g primary_plot_channels
	variable i
	primary_plot_channels = ""
	for(i=0;i<dimsize(lb_sel_wave,0);i++)
		if(lb_sel_wave[i])
			primary_plot_channels += lb_wave[i] + ";"
		endif
	endfor
	setdatafolder foldersave
	update_primary_plots()
end

function update_monitor_list()
	wave /t lb_wave = root:Packages:RSoXS_Tiled:monitor_list_wave
	wave lb_sel_wave = root:Packages:RSoXS_Tiled:monitor_sel_list
	dfref foldersave = getdatafolderDFR()
	setdatafolder root:Packages:RSoXS_Tiled
	string /g monitor_plot_channels
	variable i
	monitor_plot_channels = ""
	for(i=0;i<dimsize(lb_sel_wave,0);i++)
		if(lb_sel_wave[i])
			monitor_plot_channels += lb_wave[i] + ";"
		endif
	endfor
	setdatafolder foldersave
	update_monitor_plots()
	
end


Function select_all_primary_but_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave primary_sel_list = root:Packages:RSoxs_Tiled:primary_sel_list
			primary_sel_list = 1
			update_primary_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function deselect_primary_but_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave primary_sel_list = root:Packages:RSoxs_Tiled:primary_sel_list
			primary_sel_list=0
			update_primary_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function select_all_monitor_but_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave monitor_sel_list = root:Packages:RSoxs_Tiled:monitor_sel_list
			monitor_sel_list = 1
			update_monitor_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function deselect_monnitor_but_proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			wave monitor_sel_list = root:Packages:RSoxs_Tiled:monitor_sel_list
			monitor_sel_list = 0
			update_monitor_list()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function monitor_sel_channel_proc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	switch( lba.eventCode )
		case 4: // cell selection
		case 5: // cell selection plus shift key
			update_monitor_list()
	endswitch

	return 0
End

Function Primary_sel_channel_proc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	switch( lba.eventCode )
		case 4: // cell selection
		case 5: // cell selection plus shift key
			update_primary_list()
	endswitch

	return 0
End


Function Change_monitor_plot_chk(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			update_monitor_plots()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function change_primary_plot_chk(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			update_primary_plots()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
