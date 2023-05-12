&project_id
 SIMULATION_NAME = 'BASE PNW  d02 at 4km  with Blanchard as d03 .08km'
 USER_DESC = 'TJ Olney'
/
&filetimespec
 START_YEAR = 2017,
 START_MONTH = 02,
 START_DAY = 06,
 START_HOUR = 12,
 START_MINUTE = 00,
 START_SECOND = 00,
 END_YEAR = 2017,
 END_MONTH = 02,
 END_DAY = 07,
 END_HOUR = 03,
 END_MINUTE = 00,
 END_SECOND = 00,
 INTERVAL = 3600, 
/
&hgridspec
 NUM_DOMAINS = 2, 
 XDIM = 79, 
 YDIM = 103, 
 PARENT_ID = 1, 1, 
 RATIO_TO_PARENT = 1,   3, 
 DOMAIN_ORIGIN_LLI = 1,  13, 
 DOMAIN_ORIGIN_LLJ = 1,  59, 
 DOMAIN_ORIGIN_URI = 79,  30, 
 DOMAIN_ORIGIN_URJ = 103,  80, 
 MAP_PROJ_NAME = 'lambert'
 MOAD_KNOWN_LAT = 48.24
 MOAD_KNOWN_LON = -121.33
 MOAD_STAND_LATS = 48.24, 48.24
 MOAD_STAND_LONS = -121.33
 MOAD_DELTA_X = 4000.000, 
 MOAD_DELTA_Y = 4000.000, 
 SILAVWT_PARM_WRF = 0.
 TOPTWVL_PARM_WRF = 2.
/
&sfcfiles
 TOPO_30S = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/topo_30s',
 LANDUSE_30S = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/landuse_30s',
 SOILTYPE_TOP_30S = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/soiltype_top_30s',
 SOILTYPE_BOT_30S = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/soiltype_bot_30s',
 GREENFRAC = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/greenfrac',
 SOILTEMP_1DEG = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/soiltemp_1deg',
 ALBEDO_NCEP = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/albedo_ncep',
 MAXSNOWALB = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/maxsnowalb',
 ISLOPE = '[BASEDIR]/WRF/wrfsi/extdata/GEOG/islope',
/
&interp_control
 NUM_ACTIVE_SUBNESTS = 1, 
 ACTIVE_SUBNESTS = 2, 
 PTOP_PA = 5000,
 HINTERP_METHOD = 1,
 LSM_HINTERP_METHOD = 1,
 NUM_INIT_TIMES = 1, 
 INIT_ROOT = 'ETA',
 LBC_ROOT = 'ETA',
 LSM_ROOT = '',
 CONSTANTS_FULL_NAME = '',
 VERBOSE_LOG = .false.,
 OUTPUT_COORD = 'ETAP',
 LEVELS = 1.000, 0.998, 0.994, 0.987, 0.979, 
	0.969, 0.958, 0.945, 0.933, 0.920, 
	0.907, 0.895, 0.882, 0.870, 0.857, 
	0.844, 0.830, 0.817, 0.804, 0.790, 
	0.776, 0.762, 0.747, 0.731, 0.715, 
	0.699, 0.681, 0.663, 0.642, 0.617, 
	0.585, 0.549, 0.508, 0.463, 0.420, 
	0.381, 0.347, 0.321, 0.300, 0.279, 
	0.257, 0.236, 0.213, 0.191, 0.168, 
	0.145, 0.122, 0.098, 0.074, 0.050, 
	0.025, 0.000
/
&si_paths
 ANALPATH = '[BASEDIR]/WRF/wrfsi/extdata/extprd',
 LBCPATH = '[BASEDIR]/WRF/wrfsi/extdata/extprd',
 LSMPATH = '[BASEDIR]/WRF/wrfsi/extdata/extprd',
 CONSTANTS_PATH = '[BASEDIR]/WRF/wrfsi/extdata/extprd',
/
