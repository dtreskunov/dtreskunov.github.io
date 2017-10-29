(function() {

  function getCorsUrl(url) {
    var proxy = window.CORS_PROXY || 'https://cors-anywhere.herokuapp.com';
    return proxy + '/' + url;
  }

  window.addEventListener('load', function setupPhotoSpheres() {
    function setupPhotoSphere(container) {
      $container = $(container);
      $container.one('click', function() {
        $container.empty();
        var viewer = PhotoSphereViewer({
          container: $container[0],
          panorama: getCorsUrl($container.attr('data-url')),
          caption: $container.attr('data-caption'),
          gyroscope: true
        });
        viewer.getNavbarButton('markers').hide();
      });
    }
    $('.photosphere').each(function() {
      setupPhotoSphere(this);
    });
  });

  window.addEventListener('load', function setupGeoJsons() {
    var ICON_INACTIVE = 'https://maps.gstatic.com/mapfiles/ms2/micons/red-dot.png';
    var ICON_ACTIVE = 'https://maps.gstatic.com/mapfiles/ms2/micons/green-dot.png';

    if (window.SHOW_MAP !== undefined && !window.SHOW_MAP) {
      return;
    }
    var annotatedElements = $('[data-geo-json]');
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
      var geoJson = JSON.parse(this.dataset.geoJson);
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
        return {icon: feature.getProperty('active') ? ICON_ACTIVE : ICON_INACTIVE}
      });
      map.data.addGeoJson(geoJson, {idPropertyName: 'id'});
      map.fitBounds(bounds);
    });

    $('[data-geo-json-id]').on('mouseover click', function() {
      var feature = map.data.getFeatureById(this.dataset.geoJsonId);
      if (feature) {
        var geometry = feature.getGeometry();
        if (geometry.getType() === 'Point') {
          map.panTo(geometry.get());
        }
        feature.setProperty('active', true);
      }
    }).on('mouseout', function() {
      var feature = map.data.getFeatureById(this.dataset.geoJsonId);
      if (feature) {
        feature.setProperty('active', false);
      }
    });

    var infoWindow = new google.maps.InfoWindow();
    map.addListener('click', function() {
      infoWindow.close();
    });
    map.data.addListener('click', function(event) {
      var feature = event.feature;
      if (feature) {
        openFeaturePopup(feature);
      }
    });

    function openFeaturePopup(feature) {
      var icon = feature.getProperty('icon');
      if (!icon) {
        return;
      }
      var id = feature.getId();
      var position = feature.getGeometry().getType() === 'Point' ? feature.getGeometry().get() : map.getCenter();
      var $img = $('<img class="google-map__icon">').attr('src', icon).on('click', function() {
        var $referencedElement = $('[data-geo-json-id="' + id + '"]');
        if (!$referencedElement) {
          return;
        }
        if ($referencedElement.is('a')) {
          $referencedElement.trigger('click');
        } else if ($referencedElement.find('a').length > 0) {
          $referencedElement.find('a').first().trigger('click');
        } else {
          $(document).fullScreen(false);
          $.smoothScroll({scrollTarget: $referencedElement});
        }
      });
      infoWindow.setContent($img[0]);
      infoWindow.setPosition(position);
      infoWindow.open(map);
    }
  });

  window.addEventListener('load', function configureExternalLinks() {
    var urlRegExp = /https?:\/\/(.*?)(\/|$)/i;
    $('a[href]').each(function() {
      var match = urlRegExp.exec(this.href);
      if (match) {
        var host = match[1];
        if (host !== window.location.host) {
          $(this).attr('target', '_blank').attr('title', host);
        }
      }
    });
  });

}());
