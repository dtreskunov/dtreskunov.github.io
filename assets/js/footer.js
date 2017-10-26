(function() {

  window.addEventListener('load', function setupPhotospheres() {
    var corsProxy = 'https://cors-anywhere.herokuapp.com';
    //var corsProxy = 'https://dtreskunov-cors-anywhere.herokuapp.com';
    $('.photosphere').each(function() {
      var viewer = PhotoSphereViewer({
        container: this,
        panorama: corsProxy + '/' + this.dataset.url,
        caption: this.dataset.caption,
        gyroscope: true
      });
      viewer.getNavbarButton('markers').hide();
    });
  });

  window.addEventListener('load', function setupGeoJsons() {
    if (window.SHOW_MAP !== undefined && !window.SHOW_MAP) {
      return;
    }
    var annotatedElements = $('[data-geojson]');
    if (annotatedElements.length === 0) {
      return;
    }

    // find an existing map container or make one and append it into sidebar
    var container = $('#map');
    if (container.length === 0) {
      container = $('<div class="google-map">');
      $('#main .sidebar').first().append(container);
    }
    var mapOptions = $.extend({zoom: 1, center: {lat: 0, lng: 0}}, window.MAP_OPTIONS);
    var map = new google.maps.Map(container[0], mapOptions);

    annotatedElements.each(function() {
      var geoJson = JSON.parse(this.dataset.geojson);
      var bounds = new google.maps.LatLngBounds();
      $.each(geoJson.features, function(i, feature) {
        var cs = feature.geometry.coordinates;
        if (cs.length === 0) {
          return;
        }
        if (typeof cs[0] === 'number') {
          bounds.extend({lng: cs[0], lat: cs[1]});
        } else if ($.isArray(cs[0])) {
          $.each(cs, function(i, lngLat) {
            bounds.extend({lng: lngLat[0], lat: lngLat[1]});
          });
        }
      });
      map.data.setStyle(function(feature) {
        return {
          icon: feature.getProperty('icon') || 'https://maps.gstatic.com/mapfiles/ms2/micons/red-dot.png',
        };
      });
      map.data.addGeoJson(geoJson);
      map.fitBounds(bounds);
    });
  });

}());
