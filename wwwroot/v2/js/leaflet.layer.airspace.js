L.Airspace = L.LayerGroup.extend({

    options: {
    },

    initialize: function (data, options) {
        if (data && Array.isArray(data)) {
            var layers = [];

            data.forEach(function (airspace) {
                
                var latlngs = polyline.decode(airspace.polygon);
                const polygonOptions = {
                    stroke: true,
                    noClip: true,
                    fillOpacity: 0.35
                };

                if (airspace.strokeColor) {
                    polygonOptions.color = airspace.strokeColor;
                }

                if (airspace.strokeOpacity) {
                    polygonOptions.opacity = airspace.strokeOpacity;
                }

                if (airspace.strokeWeight) {
                    polygonOptions.weight = airspace.strokeWeight;
                }

                if (airspace.fillColor) {
                    polygonOptions.fill = true;
                    polygonOptions.fillColor = airspace.fillColor;
                }

                if (airspace.fillOpacity) {
                    polygonOptions.fillOpacity = airspace.fillOpacity;
                }

                const polygon = L.polygon(latlngs, polygonOptions);
                polygon.fillOpacity = polygonOptions.fillOpacity;

                polygon.on('mousemove', function(e) {
                    e.target.setStyle({
                        fillOpacity: 0.1
                    });
                });

                polygon.on('mouseout', function(e) {
                    e.target.setStyle({
                        fillOpacity: e.target.fillOpacity
                    });
                });

                if (airspace.description) {
                    let tooltip = airspace.description;
                    if (airspace.altLow && airspace.altHigh) {
                        tooltip = tooltip + `<br />${airspace.altLow}-${airspace.altHigh}`;

                    }
                    polygon.bindTooltip(
                        tooltip, 
                        {
                            sticky: true,
                            className: "tooltip-airspace"
                        });
                }

                layers.push(polygon);
            });

            L.LayerGroup.prototype.initialize.call(this, layers, options);
        }
    }
});

//constructor registration
L.airspace = function (data, options) {
    return new L.Airspace(data, options);
};