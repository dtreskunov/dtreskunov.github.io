(function() {

  //var CORS_PROXY = 'https://cors-anywhere.herokuapp.com';
  var CORS_PROXY = 'https://dtreskunov-cors-anywhere.herokuapp.com';

  window.addEventListener('load', function setupPhotospheres() {
    $('.photosphere').each(function() {
      var viewer = PhotoSphereViewer({
        container: this,
        panorama: CORS_PROXY + '/' + this.dataset.url,
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
      features = map.data.addGeoJson(geoJson, {idPropertyName: 'id'});
      map.fitBounds(bounds);
    });

    $('[data-geojson-id]').on('mouseover', function() {
      var feature = map.data.getFeatureById(this.dataset.geojsonId);
      if (feature !== undefined) {
        map.data.revertStyle(feature);
        map.data.overrideStyle(feature, {
          icon: 'https://maps.gstatic.com/mapfiles/ms2/micons/green-dot.png',
          zIndex: 1000,
        });
      }
    }).on('mouseout', function() {
      var feature = map.data.getFeatureById(this.dataset.geojsonId);
      if (feature !== undefined) {
        map.data.revertStyle(feature);
      }
    });

    map.data.addListener('click', function(event) {
      var id = event.feature.getId();
      if (id !== undefined) {
        $.smoothScroll({scrollTarget: $('[data-geojson-id="' + id + '"]')});
      }
    });
  });

}());
