const wxMap = $('#map').wxMap();
const leafletMap = wxMap.map;
const dialogWindgrams = $("#dialog-windgrams");
const imgSize = 300;

let gridData = null;
let domainData = null;
let selectedSiteGrid = null;
var domainLayer = null;
let selectedMarker = null;

function drawSiteGrid(site) {

	if (selectedSiteGrid) {
		if (selectedSiteGrid.d2) {
			selectedSiteGrid.d2.rect.remove();
		}
		if (selectedSiteGrid.w2) {
			selectedSiteGrid.w2.rect.remove();
		}
	}
	
	if (!gridData) {
		return;
	}

	const siteGridData = gridData[site];

	if (!siteGridData) {
		return;
	}

	selectedSiteGrid = {
		d2: createSiteDomainGrid(siteGridData["d2"], 2828.427, 'green', 'Approx 4km resolution grid point'),
		w2: createSiteDomainGrid(siteGridData["w2"], 942.809, 'blue', 'Approx 1.3km resolution grid point')
	};
}

function createSiteDomainGrid(siteDomainGridData, distance, color, tooltip) {

	if (!siteDomainGridData) {
		return null;
	}

	let siteDomainGrid = {
		center: L.latLng(siteDomainGridData.latlon.lat, siteDomainGridData.latlon.lon),
		region: siteDomainGridData.region
	};

	siteDomainGrid.bounds = [
		L.GeometryUtil.destination(siteDomainGrid.center, 45, distance),
		L.GeometryUtil.destination(siteDomainGrid.center, 225, distance)
	];

	siteDomainGrid.rect = L.rectangle(
		siteDomainGrid.bounds, 
		{
			color: color, 
			weight: 1
		}).addTo(leafletMap);

	siteDomainGrid.rect.bindTooltip(
		tooltip,
		{
			sticky: true,
			className: "tooltip-grid"
		});

	return siteDomainGrid;
}

function hideDomains() {
	if (domainLayer)
	{
		leafletMap.removeLayer(domainLayer);
		domainLayer = null;
	}
}

function showDomains(index) {
	var region = domainData[index];
	hideDomains();
	
	let domains = [];
	var colors = ['yellow', 'green', 'blue', 'purple'];

	for (var i = 0; i < region["domains"].length; i++) {

		var regionName = region.region;
		var domain = region["domains"][i];
	
		var domainCenter = L.latLng(domain["CENT_LAT"], domain["CENT_LON"]);
		var res = domain["SPACE"];
		var nx = domain["NX"];
		var ny = domain["NY"];
		var dist_x = (res * nx) / 2;
		var dist_y = (res * ny) / 2;
		
		var domainNE = L.GeometryUtil.destination(domainCenter, 90, dist_x);
		domainNE = L.GeometryUtil.destination(domainNE, 0, dist_y);
		var domainSW = L.GeometryUtil.destination(domainCenter, 180, dist_y);
		domainSW = L.GeometryUtil.destination(domainSW, 270, dist_x);

		let rect = L.rectangle(
			[ domainNE, domainSW ], 
			{
				color: colors[i], 
				weight: 1,
				opacity: 0.5,
				fill: true,
				fillColor: colors[i],
				fillOpacity: 0.25
			});

		var tooltip = "<b>Region: </b>" + region.region;
		tooltip += '<br/><b>Domain: </b>' + domain["domain"];
		tooltip += '<br/><b>Center: </b>' + domain["CENT_LAT"] + ',' + domain["CENT_LON"];
		tooltip += '<br/><b>Grid points: </b>' + domain["NX"] + 'x' + domain["NY"];
		tooltip += '<br/><b>Resolution: </b>' + domain["SPACE"] / 1000 + 'km';
		
		rect.bindTooltip(
			tooltip,
			{
				sticky: true,
				className: "tooltip-domain"
			});
	
		domains.push(rect);
	}

	domainLayer = L.layerGroup(domains).addTo(leafletMap);
}

function updateMenu(marker) {
	$('#nav-link-windgrams').attr('href', 'windgrams.html#' + marker.siteName);
	
	const noaaNavLink = $('#nav-link-noaa');
	if (marker.state != "British Columbia")
	{
		const location = marker.getLatLng();
		noaaNavLink.attr('href', "http://forecast.weather.gov/MapClick.php?lat=" + location.lat + "&lon=" + location.lng + "&unit=0&lg=english&FcstType=graphical");
		noaaNavLink.removeClass('disabled');
	}
	else
	{
		noaaNavLink.addClass('disabled');
	}
}

function initSites(sites){
	var fcstDate = new Date();
	var fcstDateUTC = fcstDate.format("UTC:yyyy-mm-dd");

	for (var i = 0; i < sites.length; i++) {
		
		var siteLocation = L.latLng(
			parseFloat(sites[i]["Lat"]),
			parseFloat(sites[i]["Lon"])
		);
		
		var marker = L.marker(
			siteLocation,
			{
				title: sites[i]["Site"]
			})
			.addTo(leafletMap);

		marker.siteName = sites[i]["Site"];
		marker.siteState = sites[i]["State"];

		const markerHtml = '<div>'+
			'<h4>' + sites[i]["Site"].replace(/_/g, " ") + '</h4>'+
			'<div>' +
			'<b>Lat/Lon: </b>' + sites[i]["Lat"] + ', ' + sites[i]["Lon"] +
			'</div>'+
			'<p>' +
			`<img data-bs-toggle="modal" data-bs-target="#dialog-windgrams" style="width:${imgSize}px" src="http://wxtofly.net/windgrams/${fcstDateUTC}_${sites[i]["Site"]}_windgram.png?${img_timestamp}"></img>` + 
			'<br/>' +
			'(Click on image for all available windgrams)</div>';

		marker.bindPopup(markerHtml);

		marker.on('click', function(e) { 
			showMarker(e.target);
		});

		if (location.hash === ("#" + marker.siteName)) {
			showMarker(marker);
			marker.openPopup();
		}
	}
}

function showMarker(marker) {
	if (selectedMarker) { 
		selectedMarker.setIcon(blueIcon);
	}
	marker.setIcon(redIcon);

	selectedMarker = marker;
	location.hash = marker.siteName;

	var fcstDate = new Date();
	$("#modalWindgram1").attr( "src", "http://wxtofly.net/windgrams/" + fcstDate.format("UTC:yyyy-mm-dd") + "_" + marker.siteName + "_windgram.png?" + img_timestamp );
	$("#modalWindgram1").on("error", function () {
		$(this).parent().html('');
	});
	fcstDate.setDate(fcstDate.getDate() + 1);
	$("#modalWindgram2").attr( "src", "http://wxtofly.net/windgrams/" + fcstDate.format("UTC:yyyy-mm-dd") + "_" + marker.siteName + "_windgram.png?" + img_timestamp );
	$("#modalWindgram2").on("error", function () {
		$(this).parent().html('');
	});
	fcstDate.setDate(fcstDate.getDate() + 1);
	$("#modalWindgram3").attr( "src", "http://wxtofly.net/windgrams/" + fcstDate.format("UTC:yyyy-mm-dd") + "_" + marker.siteName + "_windgram.png?" + img_timestamp );
	$("#modalWindgram3").on("error", function () {
		$(this).parent().html('');
	});
	fcstDate.setDate(fcstDate.getDate() + 1);
	$("#modalWindgram4").attr( "src", "http://wxtofly.net/windgrams/" + fcstDate.format("UTC:yyyy-mm-dd") + "_" + marker.siteName + "_windgram.png?" + img_timestamp );
	$("#modalWindgram4").on("error", function () {
		$(this).parent().html('');
	});

	let centerPoint = leafletMap.latLngToLayerPoint(marker.getLatLng());
	centerPoint.y = centerPoint.y - imgSize/2;

	leafletMap.setView(
		leafletMap.layerPointToLatLng(centerPoint),
		leafletMap.getZoom());

	dialogWindgrams.find('.modal-title').text(marker.siteName.replace(/_/g, " "));

	drawSiteGrid(marker.siteName);
	updateMenu(marker);
}

L.control.responsiveCoordinates({
	'position': 'bottomleft',
	'click': function (e) {
	},
	'contextmenu': function (e) {
	}
}).addTo(leafletMap);

$.getJSON('json/sites.json', function(sites) {
	initSites(sites);
});

$.getJSON('json/grid.json', function(data) {
	gridData = data;
	if (selectedMarker){
		drawSiteGrid(selectedMarker.siteName);
	}
});

var toolbarControl = L.control.toolbar([
	{
		'name': 'menu',
		'awesomeIcon': 'fas fa-bars',
		'tooltip': 'Menu',
		'panel': $('#toolbar-menu'),
		'disabled': false
	}],
	{
		'bottomOffset': 100,
		'buttonOffset': 2
	}).addTo(leafletMap);

$.getJSON('json/domains.json', function(data) {
	domainData = data;

	var ul = $('#list-domains');
	for (var i = 0; i < domainData.length; i++) {
		var li = $("<li/>");
		var a = $(`<a class="dropdown-item" href="#" onclick="showDomains(${i})">${domainData[i]["region"]}</a>`);
		li.append(a);
		ul.append(li);
	}
	ul.append('<li><hr class="dropdown-divider"></li>');

	var li = $("<li/>");
	var a = $('<a class="dropdown-item" href="#">Hide</a>');
	a.click((e) => {
		hideDomains();
	});
	li.append(a);
	ul.append(li);
});	

$.getJSON('json/airspace.json', function(data) {
	const airspace = L.airspace(data).addTo(leafletMap);
	const buttonAirspace = $('#nav-link-airspace');
	airspace.visible = true;
	buttonAirspace.click((e) => {
		if (airspace.visible === true) {
			leafletMap.removeLayer(airspace);
			buttonAirspace.text('Show Airspace');
		}
		else {
			leafletMap.addLayer(airspace);
			buttonAirspace.text('Hide Airspace');
		}
		airspace.visible = !airspace.visible;
	});
});