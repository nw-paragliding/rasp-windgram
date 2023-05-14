'use strict';

var WxMap = function (options) {

    var self = this,
        defaults = {
            'div': null,
            'center': null,
            'zoom': null
        },
        settings,
        sitesLayer,
        persistentLayersControl,
        mapOptions,
        _localStorageKey = '_wxtofly_map';

    settings = $.extend({}, defaults, options);

    if (!settings['div'] && !settings['div'].length && settings['div'] !== 1) {
        throw "invalid div option";
    }

    // create a list of base layer tile providers
    persistentLayersControl = L.control.persistentLayers();
    this.layerControl = persistentLayersControl;

    // initialize map object
    mapOptions = {
        layers: [persistentLayersControl.getCurrentLayer()],
        center: [0, 0],
        zoomControl: false,
        zoom: Math.max(persistentLayersControl.getCurrentLayer().options.minZoom, 3)
    };

    var zoom = parseInt(localStorage.getItem(_localStorageKey + '_zoom'));
    if (!isNaN(zoom)) {
        mapOptions['zoom'] = zoom;
    }
    var center = localStorage.getItem(_localStorageKey + '_center');
    if (center) {
        try {
            mapOptions['center'] = JSON.parse(center);
        }
        catch (e) {
        }
    }

    if (settings['center']) {
        mapOptions['center'] = settings['center'];
    }

    if (settings['zoom']) {
        mapOptions['zoom'] = settings['zoom'];
    }

    this.map = L.orderedControlsMap(
        settings['div'][0],
        mapOptions
    );

    this.map.on('zoom', function (e) {
        localStorage.setItem(_localStorageKey + '_zoom', e.target.getZoom());
    });

    this.map.on('move', function (e) {
        localStorage.setItem(_localStorageKey + '_center', JSON.stringify(e.target.getCenter()));
    });    

    // add layers control to map
    persistentLayersControl.addTo(this.map);

    //add zoom control
    this.map.zoomControl = L.control.zoom({
        position: 'topright'
    }).addTo(this.map);

    L.DomUtil.addClass(this.map._container, 'cursor-crosshair');
};

$.fn.wxMap = function (options) {
    if (options === undefined) {
        options = {};
    }
    options['div'] = this;
    return new WxMap(options);
};
